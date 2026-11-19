import SwiftUI
import UIKit

enum ColoringTool: String, CaseIterable {
    case fill, marker, crayon, glitter, rainbow, stamps, eraser, stickers

    var icon: String {
        switch self {
        case .fill: return "drop.fill"
        case .marker: return "paintbrush.pointed.fill"
        case .crayon: return "pencil.tip"
        case .glitter: return "sparkles"
        case .rainbow: return "rainbow"
        case .stamps: return "heart.fill"
        case .eraser: return "eraser.fill"
        case .stickers: return "face.smiling.inverse"
        }
    }

    var brush: PaintBrush? {
        switch self {
        case .marker: return .marker
        case .crayon: return .crayon
        case .glitter: return .glitter
        case .rainbow: return .rainbow
        case .stamps: return .stamps
        case .eraser: return .eraser
        case .fill, .stickers: return nil
        }
    }
}

struct FillBurst: Equatable {
    var point: CGPoint
    var id: Int
    var color: PaintColor
}

/// One page being colored: the paper, its stickers, the chosen tool and the undo history.
final class ColoringStudio: ObservableObject {
    let page: String
    let artworkID: String
    let lineArt: CGImage?
    private(set) var paper: ColoringPaper?

    @Published private(set) var ready = false
    @Published var tool: ColoringTool = .fill { didSet { if tool != .stickers { selected = nil } } }
    @Published var color: PaintColor = ColoringPalette.colors[12]
    @Published var fillStyle: ColoringFill = .solid
    @Published var sizeIndex = 1
    @Published var stayInLines = true
    @Published var stickers: [ColorSticker] = []
    @Published var selected: UUID?
    @Published private(set) var canUndo = false
    @Published var burst: FillBurst?

    /// Set by the canvas view: shows the paper's latest pixels.
    var redraw: () -> Void = {}

    private struct Step { var pixels: Data?; var stickers: [ColorSticker] }
    private var undo: [Step] = [] { didSet { canUndo = !undo.isEmpty } }
    private static let maxUndo = 12
    private(set) var dirty = false
    private var stroking = false

    init(page: String, artwork: ColoringArtwork? = nil) {
        self.page = page
        self.artworkID = artwork?.id ?? UUID().uuidString
        self.lineArt = ColoringCatalog.lineArt(page)
        let line = lineArt
        let saved = artwork.map { ColoringGallery.shared.colorLayer($0.id) } ?? nil
        let savedStickers = artwork.map { ColoringGallery.shared.stickers($0.id) } ?? []
        DispatchQueue.global(qos: .userInitiated).async {
            let paper = ColoringPaper(lineArt: line)
            if let saved { paper.load(saved) }
            _ = ColoringPaper.grain
            DispatchQueue.main.async {
                self.paper = paper
                self.stickers = savedStickers
                self.ready = true
                self.redraw()
            }
        }
    }

    private func pushUndo(pixels: Bool) {
        guard let paper else { return }
        undo.append(Step(pixels: pixels ? paper.snapshot() : nil, stickers: stickers))
        if undo.count > Self.maxUndo { undo.removeFirst() }
        dirty = true
    }

    func undoLast() {
        guard let step = undo.popLast(), let paper else { return }
        if let px = step.pixels { paper.restore(px) }
        stickers = step.stickers
        selected = nil
        Sound.shared.play(.whoosh, volume: 0.5)
        redraw()
    }

    func clearAll() {
        guard let paper else { return }
        pushUndo(pixels: true)
        paper.clear()
        stickers = []
        Sound.shared.play(.whoosh, volume: 0.7)
        redraw()
    }

    // MARK: Painting (paper pixel coordinates)

    func touchBegan(_ p: CGPoint) {
        guard let paper else { return }
        if tool == .fill {
            let before = paper.snapshot()
            if paper.fill(at: p, style: fillStyle, color: color) {
                undo.append(Step(pixels: before, stickers: stickers))
                if undo.count > Self.maxUndo { undo.removeFirst() }
                dirty = true
                switch fillStyle {
                case .glitter, .stars, .hearts: Sound.shared.play(.sparkle, volume: 0.7)
                case .rainbow: Sound.shared.play(.ding, volume: 0.6)
                default: Sound.shared.play(.pop, volume: 0.7)
                }
                burst = FillBurst(point: p, id: (burst?.id ?? 0) + 1, color: color)
                redraw()
            }
        } else if let brush = tool.brush {
            pushUndo(pixels: true)
            stroking = true
            paper.beginStroke(at: p, brush: brush, color: color, size: ColoringPaper.sizes[sizeIndex], stayInLines: stayInLines)
            redraw()
        }
    }

    func touchMoved(_ points: [CGPoint]) {
        guard stroking, let paper else { return }
        for p in points { paper.continueStroke(to: p) }
        redraw()
    }

    func touchEnded() {
        guard stroking else { return }
        stroking = false
        paper?.endStroke()
        redraw()
    }

    // MARK: Stickers

    func addSticker(_ emoji: String) {
        pushUndo(pixels: false)
        // Drop it near the middle, nudged so several don't land on top of each other.
        let n = Double(stickers.count % 5)
        let s = ColorSticker(emoji: emoji, x: Double(ColoringPaper.width) / 2 + (n - 2) * 60, y: Double(ColoringPaper.height) / 2 + (n - 2) * 30)
        stickers.append(s)
        selected = s.id
        Sound.shared.play(.boing, volume: 0.6)
    }

    func beginStickerChange() { pushUndo(pixels: false) }

    func update(_ s: ColorSticker) {
        guard let i = stickers.firstIndex(where: { $0.id == s.id }) else { return }
        stickers[i] = s
    }

    func removeSticker(_ id: UUID) {
        pushUndo(pixels: false)
        stickers.removeAll { $0.id == id }
        selected = nil
        Sound.shared.play(.pop, volume: 0.6)
    }

    // MARK: Saving

    /// Saves to the gallery when anything changed. Returns true when it saved.
    @discardableResult
    func saveIfNeeded(force: Bool = false) -> Bool {
        guard let paper, dirty || force else { return false }
        ColoringGallery.shared.save(id: artworkID, page: page, paper: paper, stickers: stickers)
        dirty = false
        return true
    }
}

// MARK: - The canvas (UIKit, for smooth Apple Pencil and finger drawing)

struct ColoringCanvas: UIViewRepresentable {
    let studio: ColoringStudio

    func makeUIView(context: Context) -> ColoringCanvasView {
        let v = ColoringCanvasView()
        v.studio = studio
        studio.redraw = { [weak v] in v?.setNeedsShow() }
        v.lineLayer.contents = studio.lineArt
        v.setNeedsShow()
        return v
    }

    func updateUIView(_ v: ColoringCanvasView, context: Context) {
        v.isUserInteractionEnabled = studio.tool != .stickers
    }
}

final class ColoringCanvasView: UIView {
    weak var studio: ColoringStudio?
    let colorLayer = CALayer()
    let lineLayer = CALayer()
    private var link: CADisplayLink?
    private var pending = false
    private var activeTouch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isMultipleTouchEnabled = false
        for l in [colorLayer, lineLayer] {
            l.contentsGravity = .resize
            l.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
            layer.addSublayer(l)
        }
        colorLayer.magnificationFilter = .linear
        lineLayer.magnificationFilter = .trilinear
        lineLayer.minificationFilter = .trilinear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        colorLayer.frame = bounds
        lineLayer.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, link == nil {
            let l = CADisplayLink(target: self, selector: #selector(tick))
            l.add(to: .main, forMode: .common)
            link = l
        } else if window == nil {
            link?.invalidate()
            link = nil
        }
    }

    func setNeedsShow() { pending = true }

    @objc private func tick() {
        guard pending else { return }
        pending = false
        colorLayer.contents = studio?.paper?.makeImage()
    }

    private func paperPoint(_ t: UITouch, _ loc: CGPoint? = nil) -> CGPoint {
        let p = loc ?? t.location(in: self)
        let k = CGFloat(ColoringPaper.width) / max(1, bounds.width)
        return CGPoint(x: p.x * k, y: p.y * k)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let t = touches.first else { return }
        activeTouch = t
        studio?.touchBegan(paperPoint(t))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = activeTouch, touches.contains(t) else { return }
        let all = event?.coalescedTouches(for: t) ?? [t]
        studio?.touchMoved(all.map { paperPoint($0, $0.location(in: self)) })
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = activeTouch, touches.contains(t) else { return }
        activeTouch = nil
        studio?.touchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}
