import SwiftUI

/// The coloring screen: tools on the left, the sketchbook page in the middle, colors/stickers on the right.
struct ColoringStudioView: View {
    @ObservedObject var studio: ColoringStudio
    let onBack: () -> Void
    let onDone: () -> Void
    var onHome: (() -> Void)? = nil
    var onStickerBook: (() -> Void)? = nil

    @State private var askClear = false
    @State private var celebrate = 0
    @State private var mixing = false
    @State private var finishing = false

    var body: some View {
        VStack(spacing: 10) {
            topBar
            HStack(alignment: .center, spacing: 14) {
                toolColumn
                VStack(spacing: 10) {
                    canvas
                    optionsRow
                }
                rightColumn
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .overlay { if askClear { clearConfirm } }
        .overlay {
            if mixing {
                ColoringMixer(studio: studio, well: studio.well) {
                    withAnimation(.spring(response: 0.35)) { mixing = false }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .overlay { ColoringConfetti(trigger: celebrate).allowsHitTesting(false) }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 14) {
                if let onHome {
                    HomeButton(size: GameChromeLayout.buttonSize, action: onHome)
                }
                if let onStickerBook {
                    StickerBookButton(game: ColoringGallery.gameID, size: GameChromeLayout.buttonSize, action: onStickerBook)
                }
                ColoringButton(icon: "square.grid.2x2.fill", tint: Theme.lilac, size: GameChromeLayout.buttonSize, action: onBack)
                    .accessibilityLabel("Pages")
            }

            Spacer()

            HStack(spacing: 10) {
                ColoringButton(icon: "arrow.uturn.backward", tint: studio.canUndo ? Theme.sky : Color.gray.opacity(0.4), size: GameChromeLayout.buttonSize) {
                    studio.undoLast()
                }
                .disabled(!studio.canUndo)
                .accessibilityLabel("Undo")

                ColoringButton(icon: "trash.fill", tint: Theme.peach, size: GameChromeLayout.buttonSize) {
                    askClear = true
                }
                .accessibilityLabel("Clear")

                ColoringZoomControls(zoom: studio.zoom)
            }

            Spacer()

            HStack(spacing: 12) {
                CoinCounter(game: ColoringGallery.gameID, height: GameChromeLayout.buttonSize)
                ColoringButton(icon: "checkmark", tint: Theme.mint, size: 70) {
                    guard !finishing else { return }
                    finishing = true
                    let unlocked = studio.completeArtwork()
                    Coins.shared.earn(4, game: ColoringGallery.gameID, from: CGPoint(x: 512, y: 420))
                    if unlocked.isEmpty {
                        Sound.shared.play(.fanfare, volume: 0.8)
                    } else {
                        Sound.shared.play(.cheer, volume: 0.7)
                    }
                    celebrate += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) { onDone() }
                }
                .disabled(finishing)
                .accessibilityLabel("Done")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    // MARK: Tools

    private var toolColumn: some View {
        GameTrayCard(cornerRadius: 26, paddingH: 8, paddingV: 8) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 5) {
                    ForEach(ColoringTool.allCases, id: \.self) { t in
                        ColoringToolButton(
                            tool: t,
                            selected: studio.tool == t,
                            color: studio.color,
                            stampShape: studio.stampShape
                        ) {
                            studio.tool = t
                        }
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 2)
            }
        }
        .frame(width: 82)
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let fit = fitted(CGSize(width: max(40, geo.size.width - 20), height: max(40, geo.size.height - 20)))
            let pageShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            let matShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

            ZStack {
                if studio.ready {
                    ColoringCanvas(studio: studio, tool: studio.tool)
                } else {
                    Color.white
                    ProgressView().scaleEffect(2).tint(Theme.pink)
                }
                ColoringStickerLayer(studio: studio, zoom: studio.zoom, scale: fit.width / CGFloat(ColoringPaper.width))
                ColoringZoomed(zoom: studio.zoom) {
                    if let b = studio.burst {
                        ColoringFillPop(burst: b, scale: fit.width / CGFloat(ColoringPaper.width)).id(b.id)
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(width: fit.width, height: fit.height)
            .clipShape(pageShape)
            .overlay(pageShape.stroke(.white, lineWidth: 3).allowsHitTesting(false))
            .overlay(SketchbookPageCorners().allowsHitTesting(false))
            .background(
                matShape
                    .fill(Color(hex: 0xFAF0E4))
                    .overlay(matShape.stroke(StorybookArt.outline(for: 0xE2C4A0), lineWidth: 3.5))
                    .padding(-10)
                    .shadow(color: Theme.ink.opacity(0.2), radius: 10, y: 6)
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func fitted(_ s: CGSize) -> CGSize {
        let aspect = CGFloat(ColoringPaper.width) / CGFloat(ColoringPaper.height)
        let w = min(s.width, s.height * aspect)
        return CGSize(width: w, height: w / aspect)
    }

    // MARK: Options under the canvas

    @ViewBuilder private var optionsRow: some View {
        GameTrayCard(cornerRadius: 26, paddingH: 14, paddingV: 7) {
            HStack(spacing: 11) {
                switch studio.tool {
                case .fill:
                    ForEach(ColoringFill.allCases, id: \.self) { f in
                        Button {
                            Sound.shared.play(.tap, volume: 0.5)
                            studio.fillStyle = f
                        } label: {
                            ColoringFillSwatch(style: f, color: studio.color, selected: studio.fillStyle == f)
                        }
                        .buttonStyle(Squish())
                    }
                case .stickers:
                    if let id = studio.selected {
                        ColoringButton(icon: "minus.magnifyingglass", tint: Theme.sky, size: 54) { resize(id, 0.8) }
                        ColoringButton(icon: "plus.magnifyingglass", tint: Theme.sky, size: 54) { resize(id, 1.25) }
                        ColoringButton(icon: "rotate.right.fill", tint: Theme.lilac, size: 54) { rotate(id) }
                        ColoringButton(icon: "trash.fill", tint: Theme.peach, size: 54) { studio.removeSticker(id) }
                    } else {
                        HStack(spacing: 10) {
                            ColoringStickerArtView(id: "star", showShadow: false)
                                .frame(width: 44, height: 44)
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Theme.ink.opacity(0.45))
                        }
                        .padding(.horizontal, 10)
                    }
                case .stamps:
                    brushSizeButtons
                    trayDivider
                    ForEach(ColoringStampShape.allCases, id: \.self) { shape in
                        Button {
                            Sound.shared.play(.tap, volume: 0.5)
                            studio.stampShape = shape
                        } label: {
                            GameDockTile(
                                size: 54,
                                selected: studio.stampShape == shape,
                                tint: studio.stampShape == shape ? Theme.blush.opacity(0.45) : .white,
                                cornerRadius: 16
                            ) {
                                StampShapeIcon(shape: shape, color: studio.color)
                                    .padding(6)
                            }
                        }
                        .buttonStyle(Squish())
                    }
                    trayDivider
                    stayInLinesButton
                default:
                    brushSizeButtons
                    trayDivider
                    stayInLinesButton
                }
            }
            .frame(height: 58)
        }
    }

    private var brushSizeButtons: some View {
        HStack(spacing: 10) {
            ForEach(0..<ColoringPaper.sizes.count, id: \.self) { i in
                Button {
                    Sound.shared.play(.tap, volume: 0.5)
                    studio.sizeIndex = i
                } label: {
                    ZStack {
                        Circle().fill(.white).frame(width: 54, height: 54)
                        Circle().fill(Theme.ink).frame(width: dotSize(i), height: dotSize(i))
                    }
                    .overlay(Circle().stroke(studio.sizeIndex == i ? Theme.pink : Theme.blush, lineWidth: studio.sizeIndex == i ? 4.5 : 2.5))
                    .scaleEffect(studio.sizeIndex == i ? 1.07 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: studio.sizeIndex)
                }
                .buttonStyle(Squish())
            }
        }
    }

    private var stayInLinesButton: some View {
        Button {
            Sound.shared.play(.tap, volume: 0.5)
            studio.stayInLines.toggle()
        } label: {
            StayInLinesIcon(active: studio.stayInLines)
                .padding(5)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(studio.stayInLines ? Theme.mint.opacity(0.4) : Theme.peach.opacity(0.35)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(studio.stayInLines ? Theme.mint : Theme.peach, lineWidth: 3.5))
        }
        .buttonStyle(Squish())
        .accessibilityLabel(studio.stayInLines ? "Stay inside lines" : "Color freely")
    }

    private var trayDivider: some View {
        Capsule()
            .fill(Theme.blush)
            .frame(width: 3, height: 34)
            .padding(.horizontal, 2)
    }

    private func dotSize(_ i: Int) -> CGFloat { [11, 22, 36][i] }

    private func resize(_ id: UUID, _ k: Double) {
        guard var s = studio.stickers.first(where: { $0.id == id }) else { return }
        studio.beginStickerChange()
        s.scale = min(4, max(0.35, s.scale * k))
        studio.update(s)
    }

    private func rotate(_ id: UUID) {
        guard var s = studio.stickers.first(where: { $0.id == id }) else { return }
        studio.beginStickerChange()
        s.angle += .pi / 8
        studio.update(s)
    }

    // MARK: Colors / sticker tray

    private var rightColumn: some View {
        GameTrayCard(cornerRadius: 28, paddingH: 10, paddingV: 10) {
            if studio.tool == .stickers {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(58), spacing: 6), count: 3), spacing: 6) {
                        ForEach(ColoringStickers.all, id: \.self) { id in
                            Button { studio.addSticker(id) } label: {
                                ColoringStickerArtView(id: id, showShadow: false)
                                    .padding(4)
                                    .frame(width: 58, height: 58)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.blush, lineWidth: 2))
                            }
                            .buttonStyle(Squish())
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                VStack(spacing: 10) {
                    ColoringHueSlider(studio: studio)
                    mixerRow
                    colorGrid
                }
            }
        }
        .frame(width: 210)
    }

    private var mixerRow: some View {
        HStack(spacing: 8) {
            Button {
                Sound.shared.play(.bubble, volume: 0.6)
                withAnimation(.spring(response: 0.35)) { mixing = true }
            } label: {
                ZStack {
                    Capsule().fill(.white)
                    MixerPaletteIcon()
                        .frame(width: 44, height: 44)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    Capsule().stroke(
                        LinearGradient(
                            colors: [Theme.pink, Theme.lemon, Theme.mint, Theme.sky, Theme.lilac],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3.5
                    )
                )
                .shadow(color: Theme.ink.opacity(0.12), radius: 3, y: 2)
            }
            .buttonStyle(Squish())
            .accessibilityLabel("Mix paint")

            if let custom = studio.customColor {
                Button {
                    Sound.shared.play(.tap, volume: 0.45)
                    studio.pickColor(custom)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        ColoringColorDot(color: custom, selected: studio.color == custom)
                        Image(systemName: "sparkle")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Theme.lemon)
                            .shadow(color: Theme.ink.opacity(0.35), radius: 1)
                            .offset(x: 2, y: -2)
                    }
                }
                .buttonStyle(Squish())
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Custom mixed color")
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: studio.customColor)
    }

    private var colorGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(54), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<ColoringPalette.colors.count, id: \.self) { i in
                    let c = ColoringPalette.colors[i]
                    Button {
                        Sound.shared.play(.tap, volume: 0.4)
                        studio.pickColor(c)
                    } label: {
                        ColoringColorDot(color: c, selected: studio.color == c)
                    }
                    .buttonStyle(Squish())
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Clear confirm

    private var clearConfirm: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { askClear = false }
            VStack(spacing: 24) {
                Image(systemName: "trash.fill").font(.system(size: 60, weight: .bold)).foregroundStyle(Theme.ink)
                HStack(spacing: 40) {
                    ColoringButton(icon: "xmark", tint: Theme.mint, size: 96) { askClear = false }
                    ColoringButton(icon: "checkmark", tint: Theme.peach, size: 96) {
                        studio.clearAll()
                        askClear = false
                    }
                }
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(.white, lineWidth: 5))
        }
    }
}

// MARK: - Pieces

private struct ColoringToolButton: View {
    let tool: ColoringTool
    let selected: Bool
    let color: PaintColor
    let stampShape: ColoringStampShape
    let action: () -> Void

    var body: some View {
        Button {
            Sound.shared.play(.tap, volume: 0.5)
            action()
        } label: {
            GameDockTile(
                size: 62,
                selected: selected,
                tint: selected ? Theme.blush.opacity(0.55) : .white,
                cornerRadius: 18
            ) {
                ZStack {
                    ColoringToolIcon(tool: tool, color: color, stampShape: stampShape)
                        .padding(5)
                    if tool == .glitter {
                        ColoringTwinkles(count: 4).allowsHitTesting(false)
                    }
                }
            }
        }
        .buttonStyle(Squish())
    }
}

/// Decorative pastel sketchbook photo-mount corners overlaid non-interactively around the canvas edges.
private struct SketchbookPageCorners: View {
    var body: some View {
        Canvas { ctx, size in
            let len: CGFloat = 22
            let inset: CGFloat = 1.5
            let corners: [(CGPoint, CGPoint, CGPoint)] = [
                (CGPoint(x: inset, y: inset), CGPoint(x: inset + len, y: inset), CGPoint(x: inset, y: inset + len)),
                (CGPoint(x: size.width - inset, y: inset), CGPoint(x: size.width - inset - len, y: inset), CGPoint(x: size.width - inset, y: inset + len)),
                (CGPoint(x: inset, y: size.height - inset), CGPoint(x: inset + len, y: size.height - inset), CGPoint(x: inset, y: size.height - inset - len)),
                (CGPoint(x: size.width - inset, y: size.height - inset), CGPoint(x: size.width - inset - len, y: size.height - inset), CGPoint(x: size.width - inset, y: size.height - inset - len)),
            ]
            for (a, b, c) in corners {
                var p = Path()
                p.move(to: a)
                p.addLine(to: b)
                p.addLine(to: c)
                p.closeSubpath()
                ctx.fill(p, with: .color(StorybookArt.color(0xFFE5EE, alpha: 0.85)))
                ctx.stroke(p, with: .color(StorybookArt.outline(for: 0xE2C4A0).opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .allowsHitTesting(false)
    }
}

private struct ColoringColorDot: View {
    let color: PaintColor
    let selected: Bool
    var body: some View {
        Circle()
            .fill(Color(.sRGB, red: color.r, green: color.g, blue: color.b))
            .frame(width: 48, height: 48)
            .overlay(Circle().stroke(.white, lineWidth: 3.5))
            .overlay(Circle().stroke(selected ? Theme.pink : Theme.ink.opacity(0.15), lineWidth: selected ? 4 : 1).padding(selected ? -4.5 : 0))
            .scaleEffect(selected ? 1.08 : 1)
            .shadow(color: Theme.ink.opacity(0.18), radius: 3, y: 2)
    }
}

/// A preview of a fill style in the current color.
private struct ColoringFillSwatch: View {
    let style: ColoringFill
    let color: PaintColor
    let selected: Bool

    var body: some View {
        Image(uiImage: ColoringFillSwatch.image(style, color))
            .resizable()
            .frame(width: 54, height: 54)
            .overlay { if style == .glitter { ColoringTwinkles(count: 5) } }
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3.5))
            .overlay(Circle().stroke(selected ? Theme.pink : .clear, lineWidth: 4).padding(-4.5))
            .scaleEffect(selected ? 1.08 : 1)
            .shadow(color: Theme.ink.opacity(0.18), radius: 3, y: 2)
    }

    private static var cache: [String: UIImage] = [:]

    static func image(_ style: ColoringFill, _ c: PaintColor) -> UIImage {
        let key = "\(style.rawValue)-\(c.packed)"
        if let i = cache[key] { return i }
        let n = 112
        let painter = FillPainter(style: style, base: c)
        let box = PixelBox(minX: 0, minY: 0, maxX: n - 1, maxY: n - 1)
        var px = [UInt32](repeating: 0, count: n * n)
        for y in 0..<n { for x in 0..<n { px[y * n + x] = painter.color(x, y, box) } }
        let img: UIImage = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                  let cg = ctx.makeImage() else { return UIImage() }
            return UIImage(cgImage: cg)
        }
        cache[key] = img
        return img
    }
}

/// Little glints that come and go, so anything glittery on the screen sparkles like the page does.
struct ColoringTwinkles: View {
    let count: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                ctx.addFilter(.shadow(color: .black.opacity(0.35), radius: 1.5))
                for i in 0..<count {
                    var r = PaintRandom(seed: UInt64(i * 31 + 5))
                    let x = 0.15 + 0.7 * r.next(), y = 0.15 + 0.7 * r.next()
                    let speed = 1.6 + 2.2 * r.next(), phase = r.next() * 6.3
                    let s = sin(t * speed + phase)
                    guard s > 0.55 else { continue }
                    let k = (s - 0.55) / 0.45
                    let c = CGPoint(x: x * size.width, y: y * size.height)
                    let rad = CGFloat(3 + 6 * k) * min(size.width, size.height) / 64
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - rad * 0.6, y: c.y - rad * 0.6, width: rad * 1.2, height: rad * 1.2)),
                             with: .color(.white.opacity(0.4 * k)))
                    ctx.fill(Path(PaintShapes.twinkle(center: c, radius: rad)), with: .color(.white.opacity(0.95)))
                }
            }
        }
    }
}

/// Stickers sit on top of the page. With the sticker tool she can drag, pinch and twist them.
/// The layer itself is never scaled (so it can't cover the buttons beside the page); each sticker is placed through the zoom.
private struct ColoringStickerLayer: View {
    @ObservedObject var studio: ColoringStudio
    @ObservedObject var zoom: ColoringZoom
    let scale: CGFloat

    var body: some View {
        let z = zoom.zoom
        let editing = studio.tool == .stickers
        let layer = ZStack {
            ForEach(studio.stickers) { s in
                ColoringStickerItem(sticker: s, scale: scale, zoom: z, editable: editing,
                            selected: studio.selected == s.id, studio: studio)
            }
        }
        // Outside the sticker tool the stickers are only pictures: no gestures at all over the page, so
        // nothing can take her brush strokes away from the canvas underneath.
        if editing {
            layer
                .contentShape(Rectangle())
                .onTapGesture { studio.selected = nil }
        } else {
            layer.allowsHitTesting(false)
        }
    }
}

private struct ColoringStickerItem: View {
    let sticker: ColorSticker
    let scale: CGFloat
    let zoom: PageZoom
    let editable: Bool
    let selected: Bool
    let studio: ColoringStudio
    @GestureState private var drag: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var twist: Angle = .zero

    var body: some View {
        let k = scale * zoom.scale   // paper pixels to screen points
        let size = max(24, CGFloat(ColorSticker.baseSize * sticker.scale) * k)
        let x = zoom.offset.x + CGFloat(sticker.x) * k, y = zoom.offset.y + CGFloat(sticker.y) * k
        // Zoomed far out of view: don't catch taps meant for the buttons around the page.
        let inView = x >= 0 && y >= 0 && x <= CGFloat(ColoringPaper.width) * scale && y <= CGFloat(ColoringPaper.height) * scale
        let showFrame = selected && editable

        let picture = ZStack {
            ColoringStickerArtView(id: sticker.emoji)
                .frame(width: size, height: size)
                .padding(showFrame ? 10 : 0)
                .background(
                    RoundedRectangle(cornerRadius: max(14, size * 0.18), style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 3.5, dash: [8, 6]))
                        .foregroundStyle(Theme.pink)
                        .opacity(showFrame ? 1 : 0)
                )
        }
        .overlay(alignment: .topTrailing) {
            if showFrame {
                Button {
                    studio.removeSticker(sticker.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.pink))
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 2)
                }
                .buttonStyle(Squish())
                .offset(x: 10, y: -10)
                .accessibilityLabel("Delete sticker")
            }
        }
        .scaleEffect(pinch)
        .rotationEffect(.radians(sticker.angle + twist.radians))
        .position(x: x + drag.width, y: y + drag.height)

        if editable {
            picture
                .allowsHitTesting(inView)
                .gesture(gestures)
                .onTapGesture { studio.selected = sticker.id }
        } else {
            picture.allowsHitTesting(false)
        }
    }

    private var gestures: some Gesture {
        let move = DragGesture(minimumDistance: 2)
            .updating($drag) { v, s, _ in s = v.translation }
            .onChanged { _ in if studio.selected != sticker.id { studio.selected = sticker.id } }
            .onEnded { v in
                studio.beginStickerChange()
                var s = sticker
                let k = scale * zoom.scale
                s.x = min(Double(ColoringPaper.width), max(0, s.x + Double(v.translation.width / k)))
                s.y = min(Double(ColoringPaper.height), max(0, s.y + Double(v.translation.height / k)))
                studio.update(s)
            }
        let grow = MagnificationGesture()
            .updating($pinch) { v, s, _ in s = v }
            .onEnded { v in
                studio.beginStickerChange()
                var s = sticker
                s.scale = min(4, max(0.35, s.scale * Double(v)))
                studio.update(s)
            }
        let turn = RotationGesture()
            .updating($twist) { v, s, _ in s = v }
            .onEnded { v in
                studio.beginStickerChange()
                var s = sticker
                s.angle += v.radians
                studio.update(s)
            }
        return move.simultaneously(with: grow.simultaneously(with: turn))
    }
}

/// A quick ring of sparkles where a fill landed.
private struct ColoringFillPop: View {
    let burst: FillBurst
    let scale: CGFloat
    @State private var go = false

    var body: some View {
        let c = Color(.sRGB, red: burst.color.r, green: burst.color.g, blue: burst.color.b)
        ZStack {
            Circle().stroke(c.opacity(go ? 0 : 0.9), lineWidth: go ? 2 : 10)
                .frame(width: go ? 160 : 20, height: go ? 160 : 20)
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * 2 * .pi
                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(i % 2 == 0 ? Color.white : c)
                    .shadow(color: .black.opacity(0.25), radius: 1)
                    .offset(x: go ? CGFloat(cos(a) * 80) : 0, y: go ? CGFloat(sin(a) * 80) : 0)
                    .opacity(go ? 0 : 1)
            }
        }
        .position(x: burst.point.x * scale, y: burst.point.y * scale)
        .onAppear { withAnimation(.easeOut(duration: 0.55)) { go = true } }
    }
}

/// Falling confetti, played once each time `trigger` changes.
struct ColoringConfetti: View {
    let trigger: Int
    @State private var start: Date?

    private struct Bit { let x, speed, spin, size: Double; let hue: Double; let shape: Int }
    private static let bits: [Bit] = (0..<70).map { i in
        var r = PaintRandom(seed: UInt64(i + 1))
        return Bit(x: r.next(), speed: 0.5 + r.next() * 0.6, spin: r.next() * 6, size: 10 + r.next() * 14, hue: r.next(), shape: i % 3)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: start == nil)) { tl in
            Canvas { ctx, size in
                guard let start else { return }
                let t = tl.date.timeIntervalSince(start)
                guard t < 2.2 else { return }
                for b in Self.bits {
                    let y = -40 + CGFloat(t * b.speed) * size.height
                    let x = CGFloat(b.x) * size.width + CGFloat(sin(t * 3 + b.spin) * 30)
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(t * b.spin))
                    let rect = CGRect(x: -b.size / 2, y: -b.size / 2, width: b.size, height: b.size * 0.6)
                    let col = Color(hue: b.hue, saturation: 0.6, brightness: 1)
                    switch b.shape {
                    case 0: c.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(col))
                    case 1: c.fill(Path(ellipseIn: rect), with: .color(col))
                    default: c.fill(Path(PaintShapes.star(center: .zero, radius: b.size / 2)), with: .color(col))
                    }
                }
            }
        }
        .onChange(of: trigger) { _ in start = Date() }
    }
}
