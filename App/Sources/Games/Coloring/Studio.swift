import SwiftUI
import UIKit
import CoreMotion

enum ColoringTool: String, CaseIterable {
    case fill, marker, crayon, pencil, paint, glitter, rainbow, stamps, eraser, stickers

    var icon: String {
        switch self {
        case .fill: return "drop.fill"
        case .marker: return "highlighter"
        case .crayon: return "pencil.tip"
        case .pencil: return "pencil"
        case .paint: return "paintbrush.pointed.fill"
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
        case .pencil: return .pencil
        case .paint: return .paint
        case .glitter: return .glitter
        case .rainbow: return .rainbow
        case .stamps: return .stamps
        case .eraser: return .eraser
        case .fill, .stickers: return nil
        }
    }
}

/// One touch sample: where, how hard (0...1) and how far the Apple Pencil leans over (0 upright ... 1 flat).
struct StrokeSample {
    var point: CGPoint
    var pressure: CGFloat
    var tilt: CGFloat
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

    private struct Step { var pixels: Data?; var flakes: [GlitterFlake]?; var stickers: [ColorSticker] }
    private var undo: [Step] = [] { didSet { canUndo = !undo.isEmpty } }
    private static let maxUndo = 12
    private(set) var dirty = false
    private var stroking = false

    init(page: String, artwork: ColoringArtwork? = nil, demo: Bool = false) {
        self.page = page
        self.artworkID = artwork?.id ?? UUID().uuidString
        self.lineArt = ColoringCatalog.lineArt(page)
        let line = lineArt
        let saved = artwork.map { ColoringGallery.shared.colorLayer($0.id) } ?? nil
        let savedStickers = artwork.map { ColoringGallery.shared.stickers($0.id) } ?? []
        let savedFlakes = artwork.map { ColoringGallery.shared.glitter($0.id) } ?? []
        DispatchQueue.global(qos: .userInitiated).async {
            let paper = ColoringPaper(lineArt: line)
            if let saved { paper.load(saved) }
            paper.flakes = savedFlakes
            _ = PaperTooth.fine
            _ = PaperTooth.soft
            if demo { ColoringStudio.paintDemo(on: paper) }
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
        undo.append(Step(pixels: pixels ? paper.snapshot() : nil, flakes: pixels ? paper.flakes : nil, stickers: stickers))
        if undo.count > Self.maxUndo { undo.removeFirst() }
        dirty = true
    }

    func undoLast() {
        guard let step = undo.popLast(), let paper else { return }
        if let px = step.pixels { paper.restore(px) }
        if let f = step.flakes { paper.flakes = f }
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

    func touchBegan(_ p: CGPoint, pressure: CGFloat = 0.6, tilt: CGFloat = 0) {
        guard let paper else { return }
        if tool == .fill {
            let before = paper.snapshot(), beforeFlakes = paper.flakes
            if paper.fill(at: p, style: fillStyle, color: color) {
                undo.append(Step(pixels: before, flakes: beforeFlakes, stickers: stickers))
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
            paper.beginStroke(at: p, brush: brush, color: color, size: ColoringPaper.sizes[sizeIndex], stayInLines: stayInLines,
                              pressure: pressure, tilt: tilt)
            redraw()
        }
    }

    func touchMoved(_ points: [StrokeSample]) {
        guard stroking, let paper else { return }
        for s in points { paper.continueStroke(to: s.point, pressure: s.pressure, tilt: s.tilt) }
        redraw()
    }

    func touchEnded() {
        guard stroking else { return }
        stroking = false
        paper?.endStroke()
        redraw()
    }

    /// A sample of every brush, for screenshots.
    static func paintDemo(on paper: ColoringPaper) {
        func wave(_ x0: CGFloat, _ x1: CGFloat, _ y: CGFloat, amp: CGFloat = 26) -> [CGPoint] {
            stride(from: x0, through: x1, by: 6).map { CGPoint(x: $0, y: y + amp * sin($0 / 55)) }
        }
        func draw(_ b: PaintBrush, _ c: UInt32, _ pts: [CGPoint], size: CGFloat = 26, pressure: CGFloat = 0.6, tilt: CGFloat = 0) {
            paper.beginStroke(at: pts[0], brush: b, color: PaintColor.hex(c), size: size, stayInLines: false, pressure: pressure, tilt: tilt)
            for p in pts.dropFirst() { paper.continueStroke(to: p, pressure: pressure, tilt: tilt) }
            paper.endStroke()
            paper.settle()
        }
        // Markers: yellow and blue crossing make green.
        draw(.marker, 0xFFC93D, wave(60, 720, 110), size: 48)
        draw(.marker, 0x3C8DFF, [CGPoint(x: 200, y: 40), CGPoint(x: 420, y: 230)], size: 48)
        draw(.marker, 0xFF6FB5, wave(60, 720, 220), size: 26)
        // Crayon: light, then pressed hard.
        draw(.crayon, 0xFF4D4D, wave(60, 720, 330), size: 48, pressure: 0.15)
        draw(.crayon, 0x4CCB6B, wave(60, 720, 420), size: 48, pressure: 1)
        // Colored pencil: a fine line, then shading with the pencil tilted.
        draw(.pencil, 0x6C63FF, wave(60, 720, 510), size: 26, pressure: 0.5)
        draw(.pencil, 0xFF8A3D, wave(60, 720, 590), size: 26, pressure: 0.5, tilt: 1)
        // Watercolor washes overlapping.
        draw(.paint, 0x5CD3FF, wave(60, 720, 730), size: 48)
        draw(.paint, 0xFF6FB5, wave(60, 720, 800), size: 48)
        draw(.paint, 0xFFC93D, [CGPoint(x: 420, y: 650), CGPoint(x: 520, y: 900)], size: 48)
        // Glitter glue, rainbow, stamps.
        draw(.glitter, 0xA66BFF, wave(880, 1540, 110), size: 48)
        draw(.glitter, 0xFF6FB5, wave(880, 1540, 230), size: 26)
        draw(.rainbow, 0, wave(880, 1540, 360), size: 48)
        draw(.stamps, 0xFF4D4D, wave(900, 1540, 490, amp: 0), size: 26)
        // The eraser rubbing through a block of crayon.
        for y in stride(from: 600, through: 760, by: 30) {
            draw(.crayon, 0x2FB8A6, [CGPoint(x: 880, y: CGFloat(y)), CGPoint(x: 1540, y: CGFloat(y))], size: 48, pressure: 1)
        }
        draw(.eraser, 0, wave(900, 1520, 680, amp: 40), size: 26)
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
    /// Glitter catching the light: a soft halo and a bright four-point glint per twinkling flake.
    let haloLayer = CAShapeLayer()
    let glintLayer = CAShapeLayer()
    private var link: CADisplayLink?
    private var pending = false
    private var activeTouch: UITouch?
    private let motion = CMMotionManager()
    private var hadGlints = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isMultipleTouchEnabled = false
        for l in [colorLayer, lineLayer, haloLayer, glintLayer] {
            l.contentsGravity = .resize
            l.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "path": NSNull(), "shadowPath": NSNull()]
            layer.addSublayer(l)
        }
        colorLayer.magnificationFilter = .linear
        lineLayer.magnificationFilter = .trilinear
        lineLayer.minificationFilter = .trilinear
        haloLayer.fillColor = UIColor(white: 1, alpha: 0.45).cgColor
        glintLayer.fillColor = UIColor.white.cgColor
        glintLayer.shadowColor = UIColor.white.cgColor
        glintLayer.shadowOpacity = 0.9
        glintLayer.shadowRadius = 2
        glintLayer.shadowOffset = .zero
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        for l in [colorLayer, lineLayer, haloLayer, glintLayer] { l.frame = bounds }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, link == nil {
            let l = CADisplayLink(target: self, selector: #selector(tick))
            l.add(to: .main, forMode: .common)
            link = l
            if motion.isDeviceMotionAvailable {
                motion.deviceMotionUpdateInterval = 1.0 / 30
                motion.startDeviceMotionUpdates()
            }
        } else if window == nil {
            link?.invalidate()
            link = nil
            motion.stopDeviceMotionUpdates()
        }
    }

    func setNeedsShow() { pending = true }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        if let paper = studio?.paper, paper.tick(now: now) { pending = true }
        if pending {
            pending = false
            colorLayer.contents = studio?.paper?.makeImage()
        }
        drawGlints(now)
    }

    private func drawGlints(_ now: CFTimeInterval) {
        guard let flakes = studio?.paper?.flakes, !flakes.isEmpty, bounds.width > 0 else {
            if hadGlints { haloLayer.path = nil; glintLayer.path = nil; glintLayer.shadowPath = nil; hadGlints = false }
            return
        }
        let att = motion.deviceMotion?.attitude
        let roll = Float(att?.roll ?? 0), pitch = Float(att?.pitch ?? 0)
        let k = bounds.width / CGFloat(ColoringPaper.width)
        let halo = CGMutablePath(), glint = CGMutablePath()
        for f in flakes {
            let g = f.glint(time: now, roll: roll, pitch: pitch)
            if g <= 0 { continue }
            let c = CGPoint(x: CGFloat(f.x) * k, y: CGFloat(f.y) * k)
            let r = CGFloat((1.5 + 5.5 * f.size) * g)
            halo.addEllipse(in: CGRect(x: c.x - r * 0.6, y: c.y - r * 0.6, width: r * 1.2, height: r * 1.2))
            glint.addPath(PaintShapes.twinkle(center: c, radius: r))
        }
        haloLayer.path = halo
        glintLayer.path = glint
        glintLayer.shadowPath = glint
        hadGlints = true
    }

    private func paperPoint(_ p: CGPoint) -> CGPoint {
        let k = CGFloat(ColoringPaper.width) / max(1, bounds.width)
        return CGPoint(x: p.x * k, y: p.y * k)
    }

    /// Apple Pencil gives real pressure and tilt; a finger draws at a medium, steady pressure.
    private func sample(_ t: UITouch) -> StrokeSample {
        let p = paperPoint(t.location(in: self))
        guard t.type == .pencil else { return StrokeSample(point: p, pressure: 0.6, tilt: 0) }
        let force = t.maximumPossibleForce > 0 ? (t.force / t.maximumPossibleForce).squareRoot() * 1.3 : 0.6
        // Upright (about 63 degrees and up) draws a fine line; leaning it right over shades.
        let tilt = max(0, min(1, (1.1 - t.altitudeAngle) / 0.7))
        return StrokeSample(point: p, pressure: max(0.08, min(1, force)), tilt: tilt)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let t = touches.first else { return }
        activeTouch = t
        let s = sample(t)
        studio?.touchBegan(s.point, pressure: s.pressure, tilt: s.tilt)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = activeTouch, touches.contains(t) else { return }
        let all = event?.coalescedTouches(for: t) ?? [t]
        studio?.touchMoved(all.map(sample))
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
