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
    @Published var tool: ColoringTool = .fill {
        didSet {
            if oldValue != .eraser && oldValue != .stickers {
                previousColorTool = oldValue
            }
            if tool != .stickers { selected = nil }
        }
    }
    private(set) var previousColorTool: ColoringTool = .fill
    @Published var color: PaintColor = ColoringPalette.colors[12]
    @Published private(set) var customColor: PaintColor?
    @Published var fillStyle: ColoringFill = .solid
    @Published var stampShape: ColoringStampShape = .cycle
    @Published var sizeIndex = 1
    @Published var stayInLines = true
    @Published var stickers: [ColorSticker] = []
    @Published var selected: UUID?
    @Published private(set) var canUndo = false
    @Published private(set) var hasEdits = false
    @Published var burst: FillBurst?

    private(set) var usedGlitter = false
    private(set) var usedRainbow = false
    private(set) var usedWatercolor = false
    private(set) var usedMixer = false
    private(set) var usedStickers = false

    /// Set by the canvas view: shows the paper's latest pixels.
    var redraw: () -> Void = {}

    /// Two-finger pinch zoom of the page.
    let zoom = ColoringZoom()

    /// The paint palette's wet paint, kept while she colors this page.
    let well = PaintWell()

    private struct Step { var pixels: ColoringPaper.Snapshot?; var flakes: [GlitterFlake]?; var stickers: [ColorSticker]; var hadEdits: Bool }
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
        undo.append(Step(pixels: pixels ? paper.snapshot() : nil, flakes: pixels ? paper.flakes : nil, stickers: stickers, hadEdits: hasEdits))
        if undo.count > Self.maxUndo { undo.removeFirst() }
        dirty = true
    }

    func undoLast() {
        guard let step = undo.popLast(), let paper else { return }
        if let px = step.pixels { paper.restore(px) }
        if let f = step.flakes { paper.flakes = f }
        stickers = step.stickers
        hasEdits = step.hadEdits
        selected = nil
        Sound.shared.play(.whoosh, volume: 0.5)
        redraw()
    }

    func clearAll() {
        guard let paper else { return }
        pushUndo(pixels: true)
        paper.clear()
        stickers = []
        hasEdits = false
        Sound.shared.play(.whoosh, volume: 0.7)
        redraw()
    }

    // MARK: Color & tool helpers

    func pickColor(_ newColor: PaintColor) {
        color = newColor
        if tool == .eraser {
            tool = previousColorTool
        }
    }

    func applyMixedColor(_ newColor: PaintColor) {
        customColor = newColor
        usedMixer = true
        pickColor(newColor)
    }

    func earnedFinds() -> [ColoringFind] {
        var finds: [ColoringFind] = [.firstMasterpiece]
        if usedGlitter || !(paper?.flakes.isEmpty ?? true) { finds.append(.glitterArtist) }
        if usedRainbow { finds.append(.rainbowPainter) }
        if usedMixer { finds.append(.colorMixer) }
        if usedStickers || !stickers.isEmpty { finds.append(.stickerStar) }
        if usedWatercolor { finds.append(.watercolorDream) }
        return finds
    }

    @discardableResult
    func completeArtwork() -> [ColoringFind] {
        guard hasEdits else { return [] }
        saveIfNeeded(force: true)
        var unlocked: [ColoringFind] = []
        for find in earnedFinds() {
            if StickerBook.shared.find(game: ColoringGallery.gameID, id: find.rawValue) {
                unlocked.append(find)
            }
        }
        return unlocked
    }

    // MARK: Painting (paper pixel coordinates)

    func touchBegan(_ p: CGPoint, pressure: CGFloat = 0.6, tilt: CGFloat = 0) {
        guard let paper else { return }
        if tool == .fill {
            let before = paper.snapshot(), beforeFlakes = paper.flakes
            if paper.fill(at: p, style: fillStyle, color: color) {
                undo.append(Step(pixels: before, flakes: beforeFlakes, stickers: stickers, hadEdits: hasEdits))
                if undo.count > Self.maxUndo { undo.removeFirst() }
                dirty = true
                hasEdits = true
                if fillStyle == .glitter { usedGlitter = true }
                if fillStyle == .rainbow { usedRainbow = true }
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
            paper.stampShape = stampShape
            if brush == .glitter { usedGlitter = true }
            if brush == .rainbow { usedRainbow = true }
            if brush == .paint { usedWatercolor = true }
            paper.beginStroke(at: p, brush: brush, color: color, size: ColoringPaper.sizes[sizeIndex], stayInLines: stayInLines,
                              pressure: pressure, tilt: tilt)
            if brush != .eraser && (paper.strokeBox != nil || brush == .stamps) { hasEdits = true }
            redraw()
        }
    }

    func touchMoved(_ points: [StrokeSample]) {
        guard stroking, let paper else { return }
        for s in points { paper.continueStroke(to: s.point, pressure: s.pressure, tilt: s.tilt) }
        if !hasEdits, paper.brush != .eraser, paper.strokeBox != nil || paper.brush == .stamps { hasEdits = true }
        redraw()
    }

    func touchEnded() {
        guard stroking else { return }
        stroking = false
        paper?.endStroke()
        redraw()
    }

    /// Takes back the stroke in progress as if it never happened (a second finger came down to pinch).
    func cancelStroke() {
        guard stroking, let paper else { return }
        stroking = false
        paper.endStroke()
        if let step = undo.popLast() {
            if let px = step.pixels { paper.restore(px) }
            if let f = step.flakes { paper.flakes = f }
            hasEdits = step.hadEdits
        }
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
        hasEdits = true
        usedStickers = true
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
    /// Passed in (not only read from `studio`) so SwiftUI sees a change and calls `updateUIView` when the tool
    /// changes. With only the studio here, the canvas stayed switched off after the sticker tool.
    let tool: ColoringTool

    func makeUIView(context: Context) -> ColoringCanvasView {
        let v = ColoringCanvasView()
        v.studio = studio
        studio.redraw = { [weak v] in v?.setNeedsShow() }
        studio.zoom.apply = { [weak v] z, animated in v?.applyZoom(z, animated: animated) }
        v.lineLayer.contents = studio.lineArt
        v.setNeedsShow()
        return v
    }

    func updateUIView(_ v: ColoringCanvasView, context: Context) {
        v.setStickerMode(tool == .stickers)
    }

    static func dismantleUIView(_ uiView: ColoringCanvasView, coordinator: ()) {
        uiView.stopSensors()
    }
}

final class ColoringCanvasView: UIView {
    weak var studio: ColoringStudio?
    /// Holds the page's layers; pinch zoom scales and moves it.
    let content = CALayer()
    let colorLayer = CALayer()
    let lineLayer = CALayer()
    /// Glitter catching the light: a soft halo and a bright four-point glint per twinkling flake.
    let haloLayer = CAShapeLayer()
    let glintLayer = CAShapeLayer()
    /// Joyful pastel sparkle halo following the brush cursor when painting with the starlight rainbow brush.
    private let rainbowHaloLayer = CAShapeLayer()
    private let rainbowSparkleLayer = CAShapeLayer()
    private var link: CADisplayLink?
    private var pending = false
    private var activeTouch: UITouch?
    private var activeStart: CFTimeInterval = 0
    /// A fill waits until the finger lifts, so the first finger of a pinch never fills.
    private var pendingFill: CGPoint?
    /// Fingers (not the Apple Pencil) on the page right now, oldest first.
    private var fingers: [UITouch] = []
    private struct Pinch { var start: PageZoom; var center: CGPoint; var distance: CGFloat; var began: CFTimeInterval; var travel: CGFloat }
    private var pinch: Pinch?
    /// After a pinch nothing draws until every finger is up.
    private var waitForLift = false
    private let motion = CMMotionManager()
    private var hadGlints = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isMultipleTouchEnabled = true
        content.anchorPoint = .zero
        layer.addSublayer(content)
        for l in [colorLayer, lineLayer, haloLayer, glintLayer] {
            l.contentsGravity = .resize
            l.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "path": NSNull(), "shadowPath": NSNull()]
            content.addSublayer(l)
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
        for l in [rainbowHaloLayer, rainbowSparkleLayer] {
            l.actions = ["path": NSNull(), "strokeColor": NSNull(), "fillColor": NSNull(), "hidden": NSNull(), "bounds": NSNull(), "position": NSNull()]
            l.isHidden = true
            layer.addSublayer(l)
        }
        rainbowHaloLayer.fillColor = UIColor.clear.cgColor
        rainbowHaloLayer.lineWidth = 3.5
        rainbowHaloLayer.lineCap = .round
        rainbowHaloLayer.shadowOpacity = 0.85
        rainbowHaloLayer.shadowRadius = 5
        rainbowHaloLayer.shadowOffset = .zero
        rainbowSparkleLayer.fillColor = UIColor(red: 1, green: 0.96, blue: 0.72, alpha: 0.95).cgColor
        rainbowSparkleLayer.shadowColor = UIColor.white.cgColor
        rainbowSparkleLayer.shadowOpacity = 0.9
        rainbowSparkleLayer.shadowRadius = 2
        rainbowSparkleLayer.shadowOffset = .zero
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.bounds = CGRect(origin: .zero, size: bounds.size)
        for l in [colorLayer, lineLayer, haloLayer, glintLayer] { l.frame = content.bounds }
        for l in [rainbowHaloLayer, rainbowSparkleLayer] { l.frame = bounds }
        CATransaction.commit()
        if let zoom = studio?.zoom {
            zoom.canvasSize = bounds.size
            // The canvas changed size: keep the zoomed page covering it.
            let z = zoom.zoom.clamped(to: bounds.size)
            applyZoom(z, animated: false)
            if z != zoom.zoom { DispatchQueue.main.async { zoom.set(z) } }
        }
    }

    func applyZoom(_ z: PageZoom, animated: Bool) {
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(ColoringZoom.glide)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        } else {
            CATransaction.setDisableActions(true)
        }
        content.position = z.offset
        content.setAffineTransform(CGAffineTransform(scaleX: z.scale, y: z.scale))
        CATransaction.commit()
    }

    private var hasFlakes: Bool { !(studio?.paper?.flakes.isEmpty ?? true) }
    private var needsFrameTick: Bool {
        guard let paper = studio?.paper else { return false }
        return !paper.flakes.isEmpty || paper.inStroke || paper.drying
    }
    var isDisplayLinkRunning: Bool { link != nil }
    var isMotionRunning: Bool { motion.isDeviceMotionActive }

    deinit {
        stopSensors()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopSensors()
        } else {
            syncSensors()
            if pending, link == nil {
                flushColorLayer()
            }
        }
    }

    func stopSensors() {
        link?.invalidate()
        link = nil
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
    }

    private func syncSensors() {
        guard window != nil else {
            stopSensors()
            return
        }
        if hasFlakes {
            if motion.isDeviceMotionAvailable && !motion.isDeviceMotionActive {
                motion.deviceMotionUpdateInterval = 1.0 / 30
                motion.startDeviceMotionUpdates()
            }
        } else {
            if motion.isDeviceMotionActive {
                motion.stopDeviceMotionUpdates()
            }
            if hadGlints {
                haloLayer.path = nil
                glintLayer.path = nil
                glintLayer.shadowPath = nil
                hadGlints = false
            }
        }
        if needsFrameTick {
            if link == nil {
                let l = CADisplayLink(target: self, selector: #selector(tick))
                l.add(to: .main, forMode: .common)
                link = l
            }
        } else {
            link?.invalidate()
            link = nil
        }
    }

    private func flushColorLayer() {
        pending = false
        colorLayer.contents = studio?.paper?.makeImage()
    }

    func setNeedsShow() {
        pending = true
        syncSensors()
        if link == nil {
            flushColorLayer()
        }
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        if let paper = studio?.paper, paper.tick(now: now) { pending = true }
        if pending {
            flushColorLayer()
        }
        drawGlints(now)
        if !needsFrameTick {
            syncSensors()
        }
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

    /// A point on the screen in paper pixels, through the zoom.
    private func paperPoint(_ v: CGPoint) -> CGPoint {
        let p = studio?.zoom.zoom.toPage(v) ?? v
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

    // MARK: Touches

    /// With the sticker tool the stickers take the touches, and the page neither draws nor zooms.
    func setStickerMode(_ on: Bool) {
        guard isUserInteractionEnabled == on else { return }
        isUserInteractionEnabled = !on
        if on { resetTouches() }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        studio?.tool == .stickers ? nil : super.hitTest(point, with: event)
    }

    /// "After a sticker nothing colors": once a sticker is on the page, SwiftUI puts drag, pinch and twist
    /// gesture recognizers on the hosting view above this one. UIKit also hands this canvas's touches to its
    /// ancestors' recognizers, and one that recognizes cancels her stroke a moment after it begins (and a
    /// cancelled fill never fills). UIKit asks the touched view before such a recognizer may begin, so
    /// unless the sticker tool is on, only this view's own touch handling runs.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.view !== self, studio?.tool != .stickers { return false }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    /// Forgets every finger, so a gesture cut off by a tool change can't leave the page stuck.
    private func resetTouches() {
        if activeTouch != nil, pendingFill == nil { studio?.touchEnded() }
        activeTouch = nil
        pendingFill = nil
        fingers = []
        pinch = nil
        waitForLift = false
        hideRainbowCursor()
    }

    private func updateRainbowCursor(at viewPoint: CGPoint) {
        guard studio?.tool == .rainbow, ColoringPaper.hasRainbowStarlight else {
            hideRainbowCursor()
            return
        }
        let now = CACurrentMediaTime()
        let hue = CGFloat((now * 0.45).truncatingRemainder(dividingBy: 1))
        let pastel = UIColor(hue: hue, saturation: 0.48, brightness: 1.0, alpha: 0.92).cgColor
        let baseR = CGFloat(ColoringPaper.sizes[studio?.sizeIndex ?? 1]) * 0.42 + 12
        let pulse = CGFloat(1 + 0.08 * sin(now * 8))
        let r = baseR * pulse
        rainbowHaloLayer.strokeColor = pastel
        rainbowHaloLayer.shadowColor = pastel
        rainbowHaloLayer.path = UIBezierPath(ovalIn: CGRect(x: viewPoint.x - r, y: viewPoint.y - r, width: r * 2, height: r * 2)).cgPath

        let sparks = CGMutablePath()
        for k in 0..<4 {
            let ang = now * 2.4 + Double(k) * .pi / 2
            let sr = r + 5
            let sc = CGPoint(x: viewPoint.x + CGFloat(cos(ang)) * sr, y: viewPoint.y + CGFloat(sin(ang)) * sr)
            sparks.addPath(PaintShapes.twinkle(center: sc, radius: k % 2 == 0 ? 6.5 : 4.5))
        }
        rainbowSparkleLayer.path = sparks
        rainbowHaloLayer.isHidden = false
        rainbowSparkleLayer.isHidden = false
    }

    private func hideRainbowCursor() {
        if !rainbowHaloLayer.isHidden { rainbowHaloLayer.isHidden = true }
        if !rainbowSparkleLayer.isHidden { rainbowSparkleLayer.isHidden = true }
    }
    // One finger (or the Apple Pencil) draws. Two fingers pinch to zoom and drag the page around; a stroke the
    // first finger had only just started is taken back, so a pinch leaves no marks. A quick two-finger tap
    // shows the whole page again.

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Touches that ended without telling us (the tool changed mid-gesture) must not block new ones.
        let gone: (UITouch) -> Bool = { $0.phase == .ended || $0.phase == .cancelled }
        fingers.removeAll(where: gone)
        if let t = activeTouch, gone(t) { activeTouch = nil; pendingFill = nil; studio?.touchEnded(); hideRainbowCursor() }
        if pinch != nil, fingers.count < 2 { pinch = nil }
        if fingers.isEmpty, activeTouch == nil { waitForLift = false }
        fingers += touches.filter { $0.type != .pencil }.sorted { $0.timestamp < $1.timestamp }
        if pinch == nil, fingers.count >= 2, activeTouch?.type != .pencil {
            startPinch()
            return
        }
        guard pinch == nil, !waitForLift, activeTouch == nil, let t = touches.first else { return }
        activeTouch = t
        activeStart = t.timestamp
        let s = sample(t)
        if studio?.tool == .fill {
            pendingFill = s.point
        } else {
            studio?.touchBegan(s.point, pressure: s.pressure, tilt: s.tilt)
            updateRainbowCursor(at: t.location(in: self))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if pinch != nil {
            updatePinch()
            return
        }
        guard let t = activeTouch, touches.contains(t), pendingFill == nil else { return }
        let all = event?.coalescedTouches(for: t) ?? [t]
        studio?.touchMoved(all.map(sample))
        updateRainbowCursor(at: t.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lifted(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lifted(touches, cancelled: true)
    }

    private func lifted(_ touches: Set<UITouch>, cancelled: Bool) {
        fingers.removeAll { touches.contains($0) }
        if let p = pinch {
            if fingers.count >= 2 {
                startPinch()   // one of three fingers lifted: carry on with the other two
            } else {
                pinch = nil
                waitForLift = true
                let quickTap = CACurrentMediaTime() - p.began < 0.3 && p.travel < 14
                if let zoom = studio?.zoom, quickTap || zoom.zoom.scale < 1.08 { zoom.reset() }
            }
        }
        if let t = activeTouch, touches.contains(t) {
            activeTouch = nil
            hideRainbowCursor()
            if let p = pendingFill {
                pendingFill = nil
                if !cancelled { studio?.touchBegan(p) }
            } else {
                studio?.touchEnded()
            }
        }
        if fingers.isEmpty && activeTouch == nil { waitForLift = false }
    }

    private func startPinch() {
        hideRainbowCursor()
        if let t = activeTouch, t.type != .pencil {
            // A stroke only just begun was the first finger of the pinch: take it back. A longer one stays.
            if CACurrentMediaTime() - activeStart < 0.5 { studio?.cancelStroke() } else { studio?.touchEnded() }
            activeTouch = nil
            pendingFill = nil
        }
        guard let zoom = studio?.zoom, fingers.count >= 2 else { return }
        let (c, d) = pinchPoints()
        pinch = Pinch(start: zoom.zoom, center: c, distance: d, began: pinch?.began ?? CACurrentMediaTime(), travel: pinch?.travel ?? 0)
    }

    private func updatePinch() {
        guard var p = pinch, let zoom = studio?.zoom, fingers.count >= 2 else { return }
        let (c, d) = pinchPoints()
        p.travel = max(p.travel, hypot(c.x - p.center.x, c.y - p.center.y) + abs(d - p.distance))
        pinch = p
        zoom.set(PageZoom.pinch(from: p.start, startCenter: p.center, startDistance: p.distance,
                                center: c, distance: d, in: bounds.size))
    }

    /// The middle of the first two fingers and how far apart they are, in this view's (unzoomed) points.
    private func pinchPoints() -> (CGPoint, CGFloat) {
        let a = fingers[0].location(in: self), b = fingers[1].location(in: self)
        return (CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), hypot(a.x - b.x, a.y - b.y))
    }
}
