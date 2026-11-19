import SwiftUI

/// The coloring screen: tools on the left, the page in the middle, colors on the right.
struct ColoringStudioView: View {
    @ObservedObject var studio: ColoringStudio
    let onBack: () -> Void
    let onDone: () -> Void
    @State private var askClear = false
    @State private var celebrate = 0

    var body: some View {
        VStack(spacing: 10) {
            topBar
            HStack(alignment: .top, spacing: 14) {
                toolColumn
                VStack(spacing: 10) {
                    canvas
                    optionsRow
                }
                rightColumn
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .overlay { if askClear { clearConfirm } }
        .overlay { ColoringConfetti(trigger: celebrate).allowsHitTesting(false) }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            ColoringButton(icon: "square.grid.2x2.fill", tint: Theme.lilac, action: onBack)
            Spacer()
            ColoringButton(icon: "arrow.uturn.backward", tint: studio.canUndo ? Theme.sky : Color.gray.opacity(0.4)) {
                studio.undoLast()
            }
            .disabled(!studio.canUndo)
            ColoringButton(icon: "trash.fill", tint: Theme.peach) { askClear = true }
            ColoringZoomResetButton(zoom: studio.zoom)
            Spacer()
            ColoringButton(icon: "checkmark", tint: Theme.mint, size: 80) {
                studio.saveIfNeeded(force: true)
                Sound.shared.play(.fanfare, volume: 0.8)
                celebrate += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { onDone() }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    // MARK: Tools

    private var toolColumn: some View {
        VStack(spacing: 6) {
            ForEach(ColoringTool.allCases, id: \.self) { t in
                ColoringToolButton(tool: t, selected: studio.tool == t, tint: toolTint(t)) {
                    studio.tool = t
                }
            }
        }
    }

    private func toolTint(_ t: ColoringTool) -> Color {
        switch t {
        case .rainbow: return Color(hex: 0xFF9EC9)
        case .eraser: return Color(hex: 0xB9B3C9)
        case .stickers: return Theme.lemon
        default: return Color(.sRGB, red: studio.color.r, green: studio.color.g, blue: studio.color.b)
        }
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let fit = fitted(geo.size)
            ZStack {
                if studio.ready {
                    ColoringCanvas(studio: studio)
                } else {
                    Color.white
                    ProgressView().scaleEffect(2).tint(Theme.pink)
                }
                ColoringStickerLayer(studio: studio, zoom: studio.zoom, scale: fit.width / CGFloat(ColoringPaper.width))
                ColoringZoomed(zoom: studio.zoom) {
                    if let b = studio.burst {
                        ColoringFillPop(burst: b, scale: fit.width / CGFloat(ColoringPaper.width)).id(b.id).allowsHitTesting(false)
                    }
                }
            }
            .frame(width: fit.width, height: fit.height)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white, lineWidth: 6))
            .shadow(color: Theme.ink.opacity(0.2), radius: 10, y: 6)
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
        HStack(spacing: 14) {
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
                    ColoringButton(icon: "minus.magnifyingglass", tint: Theme.sky, size: 60) { resize(id, 0.8) }
                    ColoringButton(icon: "plus.magnifyingglass", tint: Theme.sky, size: 60) { resize(id, 1.25) }
                    ColoringButton(icon: "rotate.right.fill", tint: Theme.lilac, size: 60) { rotate(id) }
                    ColoringButton(icon: "trash.fill", tint: Theme.peach, size: 60) { studio.removeSticker(id) }
                } else {
                    Image(systemName: "hand.point.up.left.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.ink.opacity(0.5))
                }
            default:
                ForEach(0..<ColoringPaper.sizes.count, id: \.self) { i in
                    Button {
                        Sound.shared.play(.tap, volume: 0.5)
                        studio.sizeIndex = i
                    } label: {
                        ZStack {
                            Circle().fill(.white).frame(width: 62, height: 62)
                            Circle().fill(Theme.ink).frame(width: dotSize(i), height: dotSize(i))
                        }
                        .overlay(Circle().stroke(studio.sizeIndex == i ? Theme.pink : .clear, lineWidth: 5))
                    }
                    .buttonStyle(Squish())
                }
                Spacer().frame(width: 20)
                Button {
                    Sound.shared.play(.tap, volume: 0.5)
                    studio.stayInLines.toggle()
                } label: {
                    // Inside the lines (a shape with a dot in it) or anywhere.
                    Image(systemName: studio.stayInLines ? "circle.inset.filled" : "scribble")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(Circle().fill(studio.stayInLines ? Theme.mint : Theme.peach))
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                }
                .buttonStyle(Squish())
            }
        }
        .frame(height: 70)
    }

    private func dotSize(_ i: Int) -> CGFloat { [12, 24, 40][i] }

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

    @ViewBuilder private var rightColumn: some View {
        if studio.tool == .stickers {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(58), spacing: 6), count: 3), spacing: 6) {
                    ForEach(ColoringStickers.all, id: \.self) { e in
                        Button { studio.addSticker(e) } label: {
                            Text(e).font(.system(size: 40)).frame(width: 58, height: 58)
                                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.8)))
                        }
                        .buttonStyle(Squish())
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(width: 190)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(54), spacing: 8), count: 3), spacing: 8) {
                    ForEach(0..<ColoringPalette.colors.count, id: \.self) { i in
                        let c = ColoringPalette.colors[i]
                        Button {
                            Sound.shared.play(.tap, volume: 0.4)
                            studio.color = c
                            if studio.tool == .eraser { studio.tool = .marker }
                        } label: {
                            ColoringColorDot(color: c, selected: studio.color == c)
                        }
                        .buttonStyle(Squish())
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(width: 190)
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
            .background(RoundedRectangle(cornerRadius: 36).fill(Theme.cream))
        }
    }
}

// MARK: - Pieces

private struct ColoringToolButton: View {
    let tool: ColoringTool
    let selected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            Sound.shared.play(.tap, volume: 0.5)
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(selected ? tint : .white.opacity(0.85))
                if tool == .rainbow {
                    Image(systemName: "rainbow").symbolRenderingMode(.multicolor)
                        .font(.system(size: 28, weight: .bold))
                } else {
                    Image(systemName: tool.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(selected ? Color.white : (tint == Color.white ? Theme.ink : tint))
                        .shadow(color: .black.opacity(selected ? 0.25 : 0), radius: 1)
                }
                if tool == .glitter { ColoringTwinkles(count: 4).allowsHitTesting(false) }
            }
            .frame(width: 64, height: 64)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Theme.ink : .white, lineWidth: selected ? 5 : 3))
            .scaleEffect(selected ? 1.06 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
        }
        .buttonStyle(Squish())
    }
}

private struct ColoringColorDot: View {
    let color: PaintColor
    let selected: Bool
    var body: some View {
        Circle()
            .fill(Color(.sRGB, red: color.r, green: color.g, blue: color.b))
            .frame(width: 50, height: 50)
            .overlay(Circle().stroke(.white, lineWidth: 4))
            .overlay(Circle().stroke(Theme.ink.opacity(selected ? 1 : 0.15), lineWidth: selected ? 4 : 1).padding(selected ? -5 : 0))
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
            .frame(width: 60, height: 60)
            .overlay { if style == .glitter { ColoringTwinkles(count: 5) } }
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 4))
            .overlay(Circle().stroke(selected ? Theme.ink : .clear, lineWidth: 4).padding(-5))
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
        ZStack {
            ForEach(studio.stickers) { s in
                ColoringStickerItem(sticker: s, scale: scale, zoom: z, editable: studio.tool == .stickers,
                            selected: studio.selected == s.id, studio: studio)
            }
        }
        .allowsHitTesting(studio.tool == .stickers)
        .contentShape(Rectangle())
        .onTapGesture { studio.selected = nil }
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
        let size = CGFloat(ColorSticker.baseSize * sticker.scale) * k
        let x = zoom.offset.x + CGFloat(sticker.x) * k, y = zoom.offset.y + CGFloat(sticker.y) * k
        // Zoomed far out of view: don't catch taps meant for the buttons around the page.
        let inView = x >= 0 && y >= 0 && x <= CGFloat(ColoringPaper.width) * scale && y <= CGFloat(ColoringPaper.height) * scale
        Text(sticker.emoji)
            .font(.system(size: size))
            .padding(size * 0.08)
            .background(
                Circle().stroke(style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .foregroundStyle(Theme.pink)
                    .opacity(selected && editable ? 1 : 0)
            )
            .scaleEffect(pinch)
            .rotationEffect(.radians(sticker.angle + twist.radians))
            .position(x: x + drag.width, y: y + drag.height)
            .allowsHitTesting(inView)
            .gesture(gestures, including: editable ? .all : .subviews)
            .onTapGesture { if editable { studio.selected = sticker.id } }
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
