import XCTest
import UIKit
import SwiftUI
@testable import Glimmie

final class ColoringTests: XCTestCase {
    /// Line art for tests: a black square outline from (400, 300) to (1200, 900) on clear paper.
    private func squareArt() -> CGImage {
        let ctx = ColoringPaper.makeContext(width: 2048, height: 1536)!
        ctx.clear(CGRect(x: 0, y: 0, width: 2048, height: 1536))
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(16)
        let k = 2048.0 / 1600.0
        ctx.stroke(CGRect(x: 400 * k, y: 300 * k, width: 800 * k, height: 600 * k))
        return ctx.makeImage()!
    }

    func testCatalogHasEveryPageFile() {
        let cats = ColoringCatalog.categories
        XCTAssertGreaterThanOrEqual(cats.count, 8)
        let pages = cats.flatMap(\.pages)
        XCTAssertGreaterThanOrEqual(pages.count, 50)
        XCTAssertEqual(pages.count, Set(pages).count, "page ids must be unique")
        for p in pages {
            XCTAssertNotNil(ColoringCatalog.lineArt(p), "missing line art for \(p)")
            XCTAssertNotNil(ColoringCatalog.thumbnail(p), "missing thumbnail for \(p)")
        }
        XCTAssertTrue(GameRegistry.all.contains { $0.id == "coloring" })
    }

    func testRegionsOfASquare() {
        let paper = ColoringPaper(lineArt: squareArt())
        XCTAssertEqual(paper.regions.count, 2)
        let inside = paper.regions.label(800, 600), outside = paper.regions.label(100, 100)
        XCTAssertGreaterThan(inside, 0)
        XCTAssertGreaterThan(outside, 0)
        XCTAssertNotEqual(inside, outside)
        XCTAssertEqual(paper.regions.label(400, 600), -1, "the line itself")
        // Tapping right on the line still finds an area.
        XCTAssertNotNil(paper.regions.region(near: 400, 600))
    }

    func testFillStaysInsideTheLines() {
        let paper = ColoringPaper(lineArt: squareArt())
        let pink = PaintColor.hex(0xFF6FB5)
        XCTAssertTrue(paper.fill(at: CGPoint(x: 800, y: 600), style: .solid, color: pink))
        XCTAssertEqual(paper.pixel(800, 600), pink.packed)
        XCTAssertEqual(paper.pixel(410, 310), pink.packed, "color reaches the edge of the line")
        XCTAssertEqual(paper.pixel(100, 100), PaintColor.white.packed)
        XCTAssertEqual(paper.pixel(1300, 950), PaintColor.white.packed)
        // The same fill again changes nothing, so it doesn't use up an undo step.
        XCTAssertFalse(paper.fill(at: CGPoint(x: 800, y: 600), style: .solid, color: pink))
    }

    func testEveryFillStyleIsOpaque() {
        let paper = ColoringPaper(lineArt: squareArt())
        for style in ColoringFill.allCases {
            paper.clear()
            paper.fill(at: CGPoint(x: 800, y: 600), style: style, color: PaintColor.hex(0x3C8DFF))
            for (x, y) in [(500, 400), (800, 600), (1100, 850)] {
                XCTAssertEqual(paper.pixel(x, y) >> 24, 0xFF, "\(style) at \(x),\(y)")
                XCTAssertNotEqual(paper.pixel(x, y), PaintColor.white.packed, "\(style) at \(x),\(y)")
            }
            XCTAssertEqual(paper.pixel(100, 100), PaintColor.white.packed)
        }
    }

    func testBrushStaysInsideTheLines() {
        let paper = ColoringPaper(lineArt: squareArt())
        for brush in PaintBrush.allCases where brush != .eraser {
            paper.clear()
            paper.beginStroke(at: CGPoint(x: 800, y: 600), brush: brush, color: PaintColor.hex(0x4CCB6B), size: 48, stayInLines: true)
            paper.continueStroke(to: CGPoint(x: 1000, y: 600))
            paper.continueStroke(to: CGPoint(x: 1400, y: 600))
            paper.endStroke()
            XCTAssertEqual(paper.pixel(1350, 600), PaintColor.white.packed, "\(brush) went outside the lines")
            if brush != .stamps {
                XCTAssertGreaterThan(colored(paper, 860...940, 590...610), 0.3, "\(brush) painted nothing")
            }
        }
    }

    /// Share of pixels in the box that aren't white paper.
    private func colored(_ paper: ColoringPaper, _ xs: ClosedRange<Int>, _ ys: ClosedRange<Int>) -> Double {
        var n = 0, total = 0
        for y in ys { for x in xs { total += 1; if paper.pixel(x, y) != PaintColor.white.packed { n += 1 } } }
        return Double(n) / Double(total)
    }

    private func rgb(_ v: UInt32) -> (Int, Int, Int) { (Int(v & 0xFF), Int((v >> 8) & 0xFF), Int((v >> 16) & 0xFF)) }

    private func stroke(_ paper: ColoringPaper, _ brush: PaintBrush, _ color: UInt32, _ pts: [CGPoint], size: CGFloat = 26, pressure: CGFloat = 0.6) {
        paper.beginStroke(at: pts[0], brush: brush, color: PaintColor.hex(color), size: size, stayInLines: false, pressure: pressure)
        for p in pts.dropFirst() { paper.continueStroke(to: p, pressure: pressure) }
        paper.endStroke()
    }

    func testMarkerIsEvenInOneStrokeAndDarkensWhereStrokesCross() {
        let paper = ColoringPaper(lineArt: nil)
        stroke(paper, .marker, 0x3C8DFF, [CGPoint(x: 200, y: 300), CGPoint(x: 600, y: 300)])
        let once = paper.pixel(300, 300)
        paper.clear()
        // Back and forth in one stroke: still one coat.
        stroke(paper, .marker, 0x3C8DFF, [CGPoint(x: 200, y: 300), CGPoint(x: 600, y: 300), CGPoint(x: 200, y: 300)])
        XCTAssertEqual(paper.pixel(300, 300), once)
        // A second stroke over it: two coats, darker.
        stroke(paper, .marker, 0x3C8DFF, [CGPoint(x: 300, y: 100), CGPoint(x: 300, y: 500)])
        let (r1, g1, b1) = rgb(once), (r2, g2, b2) = rgb(paper.pixel(300, 300))
        XCTAssertLessThan(r2 + g2 + b2, r1 + g1 + b1)
    }

    func testMarkerInksMixLikeRealInk() {
        let paper = ColoringPaper(lineArt: nil)
        stroke(paper, .marker, 0xFFC93D, [CGPoint(x: 200, y: 300), CGPoint(x: 600, y: 300)])
        stroke(paper, .marker, 0x3C8DFF, [CGPoint(x: 400, y: 100), CGPoint(x: 400, y: 500)])
        let (r, g, b) = rgb(paper.pixel(400, 300))
        XCTAssertGreaterThan(g, r, "yellow under blue turns green")
        XCTAssertGreaterThan(g, b)
    }

    func testCrayonPressureFillsThePaperGrain() {
        let paper = ColoringPaper(lineArt: nil)
        stroke(paper, .crayon, 0xFF4D4D, [CGPoint(x: 200, y: 300), CGPoint(x: 700, y: 300)], size: 48, pressure: 0.05)
        let light = colored(paper, 300...600, 295...305)
        stroke(paper, .crayon, 0xFF4D4D, [CGPoint(x: 200, y: 700), CGPoint(x: 700, y: 700)], size: 48, pressure: 1)
        let heavy = colored(paper, 300...600, 695...705)
        XCTAssertLessThan(light, 0.97, "a light crayon skips the paper's valleys")
        XCTAssertGreaterThan(heavy, light)
        // Going over it again fills in more.
        stroke(paper, .crayon, 0xFF4D4D, [CGPoint(x: 200, y: 300), CGPoint(x: 700, y: 300)], size: 48, pressure: 0.05)
        XCTAssertGreaterThan(colored(paper, 300...600, 295...305), light)
    }

    func testWatercolorDriesLighterWithDarkerEdges() {
        let paper = ColoringPaper(lineArt: nil)
        stroke(paper, .paint, 0x3C8DFF, [CGPoint(x: 200, y: 400), CGPoint(x: 800, y: 400)], size: 48)
        let wet = paper.pixel(500, 400)
        paper.settle()
        let dry = paper.pixel(500, 400)
        XCTAssertNotEqual(wet, dry)
        func lum(_ v: UInt32) -> Int { let (r, g, b) = rgb(v); return r + g + b }
        XCTAssertGreaterThan(lum(dry), lum(wet), "watercolor dries lighter")
        let darkest = (340...460).map { lum(paper.pixel(500, $0)) }.min()!
        XCTAssertLessThan(darkest, lum(dry), "pigment gathers at the edge")
        XCTAssertNotEqual(paper.pixel(500, 400), PaintColor.white.packed)
    }

    func testGlitterTwinklesAndTheEraserLiftsIt() {
        let paper = ColoringPaper(lineArt: nil)
        stroke(paper, .glitter, 0xA66BFF, [CGPoint(x: 200, y: 400), CGPoint(x: 800, y: 400)], size: 48)
        XCTAssertGreaterThan(paper.flakes.count, 50)
        // Over a few seconds, flakes glint and go dark again.
        var seen = Set<Int>()
        for step in 0..<200 {
            let t = Double(step) * 0.03
            for (i, f) in paper.flakes.enumerated() where f.glint(time: t, roll: 0, pitch: 0) > 0 { seen.insert(i) }
        }
        XCTAssertGreaterThan(seen.count, paper.flakes.count / 2)
        let lit = paper.flakes.filter { $0.glint(time: 1, roll: 0, pitch: 0) > 0 }.count
        XCTAssertLessThan(lit, paper.flakes.count / 4, "only a few glint at any moment")
        XCTAssertEqual(GlitterFlake.decode(GlitterFlake.encode(paper.flakes)), paper.flakes)
        stroke(paper, .eraser, 0, [CGPoint(x: 200, y: 400), CGPoint(x: 800, y: 400)], size: 48)
        XCTAssertEqual(paper.flakes.count, 0)
    }

    func testGlitterFillSparklesUntilPaintedOver() {
        let paper = ColoringPaper(lineArt: squareArt())
        paper.fill(at: CGPoint(x: 800, y: 600), style: .glitter, color: PaintColor.hex(0xFF6FB5))
        XCTAssertGreaterThan(paper.flakes.count, 100)
        XCTAssertTrue(paper.flakes.allSatisfy { $0.x > 390 && $0.x < 1210 && $0.y > 290 && $0.y < 910 })
        paper.fill(at: CGPoint(x: 800, y: 600), style: .solid, color: PaintColor.hex(0xFF6FB5))
        XCTAssertEqual(paper.flakes.count, 0)
        XCTAssertEqual(paper.pixel(800, 600), PaintColor.hex(0xFF6FB5).packed)
    }

    func testBrushAnywhereWhenNotStayingInLines() {
        let paper = ColoringPaper(lineArt: squareArt())
        paper.beginStroke(at: CGPoint(x: 800, y: 600), brush: .marker, color: PaintColor.hex(0x111111), size: 26, stayInLines: false)
        paper.continueStroke(to: CGPoint(x: 1400, y: 600))
        paper.endStroke()
        XCTAssertNotEqual(paper.pixel(1350, 600), PaintColor.white.packed)
    }

    func testSnapshotRestore() {
        let paper = ColoringPaper(lineArt: squareArt())
        let before = paper.snapshot()
        paper.fill(at: CGPoint(x: 800, y: 600), style: .glitter, color: PaintColor.hex(0xA66BFF))
        XCTAssertNotEqual(paper.pixel(800, 600), PaintColor.white.packed)
        paper.restore(before)
        XCTAssertEqual(paper.pixel(800, 600), PaintColor.white.packed)
    }

    func testGallerySaveLoadDelete() {
        let paper = ColoringPaper(lineArt: ColoringCatalog.lineArt("cat_4"))
        paper.fill(at: CGPoint(x: 800, y: 560), style: .solid, color: PaintColor.hex(0xFF8A3D))
        let id = "test-\(UUID().uuidString)"
        let gallery = ColoringGallery.shared
        gallery.save(id: id, page: "cat_4", paper: paper, stickers: [ColorSticker(emoji: "🦄", x: 300, y: 300)])
        defer { if let a = gallery.items.first(where: { $0.id == id }) { gallery.delete(a) } }
        XCTAssertEqual(gallery.items.first?.id, id)
        XCTAssertNotNil(gallery.thumbnail(id))
        XCTAssertEqual(gallery.stickers(id).first?.emoji, "🦄")
        let reloaded = ColoringPaper(lineArt: ColoringCatalog.lineArt("cat_4"))
        reloaded.load(gallery.colorLayer(id)!)
        XCTAssertEqual(reloaded.pixel(800, 560), paper.pixel(800, 560))
        XCTAssertNotNil(gallery.fullPicture(gallery.items.first!))
    }

    // MARK: Grown-up pages

    /// A "printable page" as it comes off the web: opaque white paper, a grey shadow, a black square outline.
    private func printablePage() -> CGImage {
        let w = 1000, h = 800
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(CGColor(gray: 0.85, alpha: 1))
        ctx.fill(CGRect(x: 300, y: 300, width: 200, height: 150))
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(6)
        ctx.stroke(CGRect(x: 200, y: 200, width: 600, height: 400))
        return ctx.makeImage()!
    }

    func testConvertedPageHasAnInsideAndAnOutside() {
        let page = ColoringConvert.page(from: printablePage())
        XCTAssertNotNil(page)
        XCTAssertEqual(page?.art.width, 2048)
        XCTAssertEqual(page?.art.height, 1536)
        let paper = ColoringPaper(lineArt: page!.art)
        XCTAssertGreaterThanOrEqual(paper.regions.count, 2)
        let inside = paper.regions.label(800, 600), outside = paper.regions.label(10, 10)
        XCTAssertGreaterThan(inside, 0, "the light grey shadow is not a line")
        XCTAssertGreaterThan(outside, 0)
        XCTAssertNotEqual(inside, outside)
    }

    func testBlankPictureIsNotAPage() {
        let ctx = CGContext(data: nil, width: 300, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertNil(ColoringConvert.page(from: ctx.makeImage()!))
    }

    func testCustomTabsAndPages() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ColoringCustom(folder: dir)
        XCTAssertTrue(store.tabs.isEmpty)
        let tab = store.addTab(name: "  Princesses ")
        XCTAssertTrue(ColoringCustom.isCustom(tab))
        XCTAssertEqual(store.tabs.first?.name, "Princesses")

        let added = expectation(description: "page added")
        var pageID: String?
        store.addPage(printablePage(), to: tab) { pageID = $0; added.fulfill() }
        wait(for: [added], timeout: 120)
        guard let id = pageID else {
            return XCTFail("page conversion did not add a custom page")
        }
        XCTAssertTrue(ColoringCustom.isCustom(id))
        XCTAssertEqual(store.tabs.first?.pages, [id])
        XCTAssertNotNil(store.lineArt(id))
        XCTAssertNotNil(store.thumbnail(id))
        XCTAssertEqual(store.categories.first?.pages, [id])

        // Tabs and pages survive a relaunch.
        let reopened = ColoringCustom(folder: dir)
        XCTAssertEqual(reopened.tabs, store.tabs)
        XCTAssertNotNil(reopened.lineArt(id))

        store.rename(tab: tab, to: "Bluey")
        XCTAssertEqual(store.tabs.first?.name, "Bluey")
        store.deletePage(id)
        XCTAssertEqual(store.tabs.first?.pages, [])
        XCTAssertNil(store.lineArt(id), "a deleted page opens as a blank page")
        store.deleteTab(tab)
        XCTAssertTrue(store.tabs.isEmpty)
        XCTAssertTrue(ColoringCustom(folder: dir).tabs.isEmpty)
    }

    // MARK: Pinch zoom

    func testPinchKeepsThePageUnderTheFingers() {
        let size = CGSize(width: 800, height: 600)
        let c = CGPoint(x: 300, y: 200)
        // Fingers spread to twice their distance around (300, 200): that spot stays put.
        let z = PageZoom.pinch(from: PageZoom(), startCenter: c, startDistance: 100, center: c, distance: 200, in: size)
        XCTAssertEqual(z.scale, 2, accuracy: 0.0001)
        let under = z.toPage(c)
        XCTAssertEqual(under.x, 300, accuracy: 0.0001)
        XCTAssertEqual(under.y, 200, accuracy: 0.0001)
        // Then both fingers slide 50 points left: the page moves with them.
        let moved = PageZoom.pinch(from: z, startCenter: c, startDistance: 100, center: CGPoint(x: 250, y: 200), distance: 100, in: size)
        XCTAssertEqual(moved.scale, 2, accuracy: 0.0001)
        XCTAssertEqual(moved.toPage(CGPoint(x: 250, y: 200)).x, 300, accuracy: 0.0001)
    }

    func testZoomStaysBetweenTheWholePageAndFourTimes() {
        let size = CGSize(width: 800, height: 600)
        let c = CGPoint(x: 400, y: 300)
        let tooFar = PageZoom.pinch(from: PageZoom(), startCenter: c, startDistance: 10, center: c, distance: 500, in: size)
        XCTAssertEqual(tooFar.scale, PageZoom.maxScale)
        let tooSmall = PageZoom.pinch(from: PageZoom(), startCenter: c, startDistance: 300, center: c, distance: 30, in: size)
        XCTAssertEqual(tooSmall, PageZoom())
        XCTAssertFalse(tooSmall.isZoomed)
        // Dragged past the edge, the page still covers the whole canvas.
        let edge = PageZoom(scale: 2, offset: CGPoint(x: 120, y: -2000)).clamped(to: size)
        XCTAssertEqual(edge.offset.x, 0)
        XCTAssertEqual(edge.offset.y, -600)
    }

    // MARK: Stickers, then coloring

    /// Waits (running the main loop) until `done` is true or the time runs out.
    private func waitUntil(_ seconds: Double = 15, _ done: () -> Bool) {
        let end = Date().addingTimeInterval(seconds)
        while !done(), Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    }

    private func readyStudio() -> ColoringStudio {
        let studio = ColoringStudio(page: ColoringCatalog.blank)
        waitUntil { studio.ready }
        XCTAssertTrue(studio.ready)
        return studio
    }

    func testPlacingAStickerThenColoringStillPaints() {
        let studio = readyStudio()
        studio.tool = .stickers
        studio.addSticker("🦄")
        XCTAssertEqual(studio.stickers.count, 1)
        studio.tool = .marker
        studio.color = PaintColor.hex(0x3C8DFF)
        let white = PaintColor.white.packed
        let p = CGPoint(x: 300, y: 300)
        studio.touchBegan(p)
        studio.touchMoved([StrokeSample(point: CGPoint(x: 420, y: 320), pressure: 0.6, tilt: 0)])
        studio.touchEnded()
        XCTAssertNotEqual(studio.paper?.pixel(360, 310), white, "the marker should paint after a sticker")
        // And the fill bucket still fills.
        studio.tool = .fill
        studio.color = PaintColor.hex(0xFF4D4D)
        studio.touchBegan(CGPoint(x: 1200, y: 900))
        XCTAssertEqual(studio.paper?.pixel(1300, 1000), PaintColor.hex(0xFF4D4D).packed)
    }

    func testOnlyTheCanvasHandlesItsTouchesUnlessStickersAreOn() {
        let studio = readyStudio()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let canvas = ColoringCanvasView(frame: host.bounds)
        canvas.studio = studio
        host.addSubview(canvas)
        // A recognizer on a view above the canvas, like the ones SwiftUI adds for sticker gestures.
        let theirs = UIPanGestureRecognizer()
        host.addGestureRecognizer(theirs)
        studio.tool = .marker
        XCTAssertFalse(canvas.gestureRecognizerShouldBegin(theirs))
        XCTAssertNotNil(canvas.hitTest(CGPoint(x: 400, y: 300), with: nil))
        studio.tool = .stickers
        XCTAssertTrue(canvas.gestureRecognizerShouldBegin(theirs))
        XCTAssertNil(canvas.hitTest(CGPoint(x: 400, y: 300), with: nil))
    }

    func testThePageTakesTouchesAgainAfterTheStickerTool() {
        let studio = readyStudio()
        // A window only draws when it belongs to the app's scene.
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return XCTFail("no window scene in the test host")
        }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: ColoringStudioView(studio: studio, onBack: {}, onDone: {}))
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true }
        func canvas(in v: UIView) -> ColoringCanvasView? {
            if let c = v as? ColoringCanvasView { return c }
            for s in v.subviews { if let c = canvas(in: s) { return c } }
            return nil
        }
        waitUntil { canvas(in: window) != nil }
        studio.tool = .stickers
        waitUntil(1) { false }
        studio.addSticker("🦄")
        waitUntil(1) { false }
        studio.tool = .marker
        waitUntil(1) { false }
        guard let c = canvas(in: window) else { return XCTFail("no canvas on screen") }
        // A spot on the page away from the sticker (which sits in the middle).
        let spot = c.convert(CGPoint(x: c.bounds.width * 0.2, y: c.bounds.height * 0.25), to: window)
        let hit = window.hitTest(spot, with: nil)
        XCTAssertTrue(hit === c || hit?.isDescendant(of: c) == true, "the page should get her touches, got \(String(describing: hit))")
        XCTAssertTrue(c.isUserInteractionEnabled)
        // No recognizer above the canvas may take over a stroke.
        var v: UIView? = c.superview
        while let view = v {
            for g in view.gestureRecognizers ?? [] { XCTAssertFalse(c.gestureRecognizerShouldBegin(g)) }
            v = view.superview
        }
    }

    // MARK: Hue slider and paint palette

    func testHueSliderColorsGoRoundTheRainbow() {
        for h in stride(from: 0.0, to: 1.0, by: 0.1) {
            XCTAssertEqual(PaintColor.slider(h).hue ?? -1, h, accuracy: 0.01)
        }
        XCTAssertNil(PaintColor.white.hue)
        XCTAssertNil(PaintColor.hex(0x7A7A86).hue)
    }

    func testPalettePaintMixesLikeRealPaint() {
        let well = PaintWell()
        XCTAssertTrue(well.isEmpty)
        XCTAssertNil(well.color(at: CGPoint(x: 36, y: 24)))
        well.drop(PaintColor.hex(0x3C8DFF), at: CGPoint(x: 28, y: 24))
        well.drop(PaintColor.hex(0xFFF06B), at: CGPoint(x: 44, y: 24))
        XCTAssertFalse(well.isEmpty)
        let blue = well.color(at: CGPoint(x: 28, y: 24))!
        XCTAssertGreaterThan(blue.b, blue.g)
        // Swirl round and round over both blobs.
        var last = CGPoint(x: 42, y: 24)
        for t in 0..<600 {
            let a = Double(t) * 0.25, r = 6 + 4 * sin(Double(t) * 0.05)
            let p = CGPoint(x: 36 + cos(a) * r, y: 24 + sin(a) * r)
            well.smear(from: last, to: p)
            last = p
        }
        let mixed = well.color(at: CGPoint(x: 36, y: 24))!
        XCTAssertGreaterThan(mixed.g, mixed.r, "blue and yellow paint make green")
        XCTAssertGreaterThan(mixed.g, mixed.b, "blue and yellow paint make green")
        XCTAssertNotNil(well.image())
        well.wipe()
        XCTAssertTrue(well.isEmpty)
    }

    // MARK: Overhaul finds, vector stickers, previous tool & custom swatch

    func testColoringEntryHasSixFindsStickers() {
        let stickers = ColoringFind.stickers
        XCTAssertEqual(stickers.count, 6)
        let ids = Set(stickers.map(\.id))
        XCTAssertEqual(ids, Set(["firstMasterpiece", "glitterArtist", "rainbowPainter", "colorMixer", "stickerStar", "watercolorDream"]))
        XCTAssertEqual(ColoringGame.entry.stickers.map(\.id), stickers.map(\.id))
    }

    func testPickingColorAfterEraserRestoresPreviousColorTool() {
        let studio = readyStudio()
        studio.tool = .crayon
        studio.tool = .eraser
        studio.pickColor(PaintColor.hex(0x3C8DFF))
        XCTAssertEqual(studio.tool, .crayon, "picking a color restores the last drawing tool instead of hardcoding marker")

        // Visiting stickers between drawing and erasing keeps the last drawing tool.
        studio.tool = .paint
        studio.tool = .stickers
        studio.tool = .eraser
        studio.pickColor(PaintColor.hex(0xFF6FB5))
        XCTAssertEqual(studio.tool, .paint)

        // Applying a mixed paint color also leaves the eraser back to the previous drawing tool.
        studio.tool = .fill
        studio.tool = .eraser
        studio.applyMixedColor(PaintColor.hex(0x4CCB6B))
        XCTAssertEqual(studio.tool, .fill)
    }

    func testVectorStickerLookupHandlesModernIDsAndLegacyEmojis() {
        XCTAssertGreaterThanOrEqual(ColoringStickers.all.count, 24)
        for id in ColoringStickers.all {
            XCTAssertNotNil(ColoringVectorStickers.sticker(for: id), "missing vector sticker for \(id)")
        }
        let legacy: [(String, ColoringVectorSticker)] = [
            ("⭐", .star), ("⭐️", .star), ("❤️", .heart), ("💖", .heart),
            ("🌈", .rainbow), ("🦄", .unicorn), ("👑", .crown), ("🌸", .flower),
            ("🦋", .butterfly), ("☀️", .sun), ("🌙", .moon), ("☁️", .cloud),
            ("🐱", .kitty), ("🐰", .bunny), ("🐶", .puppy), ("🎀", .bow),
            ("🧁", .cupcake), ("🍓", .strawberry), ("🍭", .lollipop), ("🍦", .iceCream),
            ("💎", .diamond), ("🪄", .magicWand), ("🐾", .paw), ("🎈", .balloon),
            ("🎵", .musicNote), ("✨", .sparkle),
        ]
        for (emoji, expected) in legacy {
            XCTAssertEqual(ColoringVectorStickers.sticker(for: emoji), expected, "legacy emoji \(emoji) should map to \(expected)")
        }
        XCTAssertNil(ColoringVectorStickers.sticker(for: "custom-unknown-sticker"))

        let paper = ColoringPaper(lineArt: nil)
        let img = paper.makeImage()!
        let rendered = ColoringRender.picture(
            color: img,
            page: ColoringCatalog.blank,
            stickers: [
                ColorSticker(emoji: "unicorn", x: 400, y: 400),
                ColorSticker(emoji: "⭐️", x: 800, y: 500),
                ColorSticker(emoji: "🦖", x: 1100, y: 700),
            ],
            width: 480
        )
        XCTAssertEqual(rendered.size.width, 480)
    }

    func testCustomMixedSwatchPersistsAndTracksEarnedFinds() {
        let studio = readyStudio()
        XCTAssertNil(studio.customColor)
        let mixed = PaintColor.hex(0x66BB77)
        studio.applyMixedColor(mixed)
        XCTAssertEqual(studio.customColor, mixed)
        XCTAssertEqual(studio.color, mixed)

        // Picking a preset color keeps her custom mixed swatch intact.
        let preset = ColoringPalette.colors[0]
        studio.pickColor(preset)
        XCTAssertEqual(studio.color, preset)
        XCTAssertEqual(studio.customColor, mixed)

        // Usage flags drive earned finds cleanly.
        studio.tool = .glitter
        studio.touchBegan(CGPoint(x: 400, y: 400))
        studio.touchEnded()
        studio.tool = .rainbow
        studio.touchBegan(CGPoint(x: 500, y: 400))
        studio.touchEnded()
        studio.tool = .paint
        studio.touchBegan(CGPoint(x: 600, y: 400))
        studio.touchEnded()
        studio.addSticker("star")

        let finds = Set(studio.earnedFinds())
        XCTAssertEqual(finds, Set(ColoringFind.allCases))
    }

    func testStampShapeModesRenderOnPaper() {
        for shape in ColoringStampShape.allCases {
            let paper = ColoringPaper(lineArt: nil)
            paper.stampShape = shape
            paper.beginStroke(at: CGPoint(x: 400, y: 400), brush: .stamps, color: PaintColor.hex(0xFF6FB5), size: 32, stayInLines: false)
            paper.continueStroke(to: CGPoint(x: 600, y: 400))
            paper.endStroke()
            XCTAssertGreaterThan(colored(paper, 360...640, 360...440), 0.05, "\(shape) stamp should mark the paper")
        }
    }

    func testSnapshotLZ4CompressionShrinksAndRestoresLosslessly() {
        let paper = ColoringPaper(lineArt: squareArt())
        let rawBytes = ColoringPaper.width * ColoringPaper.height * 4

        let blankSnap = paper.snapshot()
        XCTAssertTrue(blankSnap.compressed)
        XCTAssertLessThan(blankSnap.byteCount, rawBytes / 20, "blank LZ4 snapshot should shrink dramatically")

        let pink = PaintColor.hex(0xFF6FB5)
        let blue = PaintColor.hex(0x3C8DFF)
        paper.fill(at: CGPoint(x: 800, y: 600), style: .glitter, color: pink)
        stroke(paper, .crayon, 0x3C8DFF, [CGPoint(x: 450, y: 350), CGPoint(x: 1100, y: 820)], size: 48, pressure: 0.85)
        let paintedSnap = paper.snapshot()
        XCTAssertTrue(paintedSnap.compressed)
        XCTAssertLessThan(paintedSnap.byteCount, rawBytes / 4, "painted LZ4 snapshot should be far smaller than 7.68 MB raw RGBA")

        let sampleCoords = [(100, 100), (450, 350), (800, 600), (920, 700), (1100, 820), (1300, 950)]
        let expected = sampleCoords.map { paper.pixel($0.0, $0.1) }

        paper.fill(at: CGPoint(x: 100, y: 100), style: .solid, color: blue)
        XCTAssertEqual(paper.pixel(100, 100), blue.packed)

        paper.restore(paintedSnap)
        for ((x, y), px) in zip(sampleCoords, expected) {
            XCTAssertEqual(paper.pixel(x, y), px, "LZ4 restore must be 100% lossless at (\(x),\(y))")
        }

        paper.restore(blankSnap)
        XCTAssertEqual(paper.pixel(800, 600), PaintColor.white.packed)
        XCTAssertEqual(paper.pixel(100, 100), PaintColor.white.packed)
    }

    func testHasEditsGuardsBlankPageCoinFarm() {
        let prevDemo = StickerBook.shared.demo
        StickerBook.shared.demo = true
        defer { StickerBook.shared.demo = prevDemo }

        let studio = readyStudio()
        defer {
            if let saved = ColoringGallery.shared.items.first(where: { $0.id == studio.artworkID }) {
                ColoringGallery.shared.delete(saved)
            }
        }

        XCTAssertFalse(studio.hasEdits, "new blank page starts unedited")
        XCTAssertTrue(studio.completeArtwork().isEmpty, "blank page must not unlock completion stickers")
        XCTAssertFalse(ColoringGallery.shared.items.contains { $0.id == studio.artworkID })

        // Filling blank white paper with white changes nothing and keeps hasEdits false.
        studio.tool = .fill
        studio.fillStyle = .solid
        studio.color = .white
        studio.touchBegan(CGPoint(x: 800, y: 600))
        XCTAssertFalse(studio.hasEdits)

        // A real color fill marks hasEdits true, and undoing it reverts hasEdits to false.
        studio.color = PaintColor.hex(0xFF6FB5)
        studio.touchBegan(CGPoint(x: 800, y: 600))
        XCTAssertTrue(studio.hasEdits)
        studio.undoLast()
        XCTAssertFalse(studio.hasEdits)

        // A cancelled stroke (pinch zoom) must not leave hasEdits true.
        studio.tool = .marker
        studio.touchBegan(CGPoint(x: 500, y: 500))
        XCTAssertTrue(studio.hasEdits)
        studio.cancelStroke()
        XCTAssertFalse(studio.hasEdits)

        // Adding a sticker marks hasEdits true, and clearAll resets it back to false.
        studio.addSticker("star")
        XCTAssertTrue(studio.hasEdits)
        studio.clearAll()
        XCTAssertFalse(studio.hasEdits)
        XCTAssertTrue(studio.completeArtwork().isEmpty, "cleared blank page must not unlock completion rewards")

        // Painting again enables completion saves and sticker unlocks cleanly.
        studio.tool = .marker
        studio.color = PaintColor.hex(0x3C8DFF)
        studio.touchBegan(CGPoint(x: 500, y: 500))
        studio.touchMoved([StrokeSample(point: CGPoint(x: 700, y: 500), pressure: 0.6, tilt: 0)])
        studio.touchEnded()
        XCTAssertTrue(studio.hasEdits)
        _ = studio.completeArtwork()
        XCTAssertTrue(ColoringGallery.shared.items.contains { $0.id == studio.artworkID })
        XCTAssertTrue(StickerBook.shared.has(game: ColoringGallery.gameID, id: ColoringFind.firstMasterpiece.rawValue))
    }

    func testGlitterSensorsGateOnFlakesPresence() {
        let studio = readyStudio()
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return XCTFail("no window scene in the test host")
        }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let canvas = ColoringCanvasView(frame: window.bounds)
        canvas.studio = studio
        studio.redraw = { [weak canvas] in canvas?.setNeedsShow() }
        window.addSubview(canvas)
        window.makeKeyAndVisible()
        defer {
            canvas.removeFromSuperview()
            window.isHidden = true
        }

        XCTAssertFalse(canvas.isDisplayLinkRunning, "idle canvas with no glitter must not run CADisplayLink")
        XCTAssertFalse(canvas.isMotionRunning, "idle canvas with no glitter must not run CMMotionManager")

        // Solid fill leaves flakes empty, so display link and motion remain stopped.
        studio.tool = .fill
        studio.fillStyle = .solid
        studio.color = PaintColor.hex(0xFF6FB5)
        studio.touchBegan(CGPoint(x: 800, y: 600))
        XCTAssertFalse(canvas.isDisplayLinkRunning)
        XCTAssertFalse(canvas.isMotionRunning)

        // Glitter fill activates the display link for twinkling flakes.
        studio.fillStyle = .glitter
        studio.touchBegan(CGPoint(x: 800, y: 600))
        XCTAssertFalse(studio.paper?.flakes.isEmpty ?? true)
        XCTAssertTrue(canvas.isDisplayLinkRunning, "glitter flakes must activate CADisplayLink")

        // Clearing the page immediately stops the display link and motion updates.
        studio.clearAll()
        XCTAssertTrue(studio.paper?.flakes.isEmpty ?? false)
        XCTAssertFalse(canvas.isDisplayLinkRunning, "clearing glitter must immediately stop CADisplayLink")
        XCTAssertFalse(canvas.isMotionRunning, "clearing glitter must immediately stop CMMotionManager")
    }

    func testColoringTreasureHooksUnlockBonusStickersAndStarlightRainbow() {
        Coins.shared.resetForTests(balance: 60)
        defer { Coins.shared.resetForTests() }

        XCTAssertEqual(ColoringStickers.all.count, 24)
        XCTAssertEqual(ColoringStickers.available, ColoringStickers.all)
        XCTAssertFalse(ColoringPaper.hasRainbowStarlight)

        // Painting rainbow without the treasure adds no glitter flakes.
        let plainPaper = ColoringPaper(lineArt: nil)
        stroke(plainPaper, .rainbow, 0, [CGPoint(x: 200, y: 300), CGPoint(x: 700, y: 300)], size: 48)
        XCTAssertTrue(plainPaper.flakes.isEmpty)

        // Buying starStamp unlocks the two extra bonus vector stickers cleanly.
        XCTAssertTrue(Coins.shared.buy("coloring/starStamp", price: 10))
        XCTAssertEqual(ColoringStickers.all.count, 24, "baseline sticker list stays intact")
        XCTAssertEqual(ColoringStickers.available.count, 26)
        for bonusID in ColoringStickers.bonusStarStamp {
            XCTAssertTrue(ColoringStickers.available.contains(bonusID))
            XCTAssertNotNil(ColoringVectorStickers.sticker(for: bonusID), "bonus sticker \(bonusID) must render as vector art")
        }

        // Buying rainbowBrush enables starlight shimmer flakes on rainbow strokes.
        XCTAssertTrue(Coins.shared.buy("coloring/rainbowBrush", price: 12))
        XCTAssertTrue(ColoringPaper.hasRainbowStarlight)
        let starlightPaper = ColoringPaper(lineArt: nil)
        stroke(starlightPaper, .rainbow, 0, [CGPoint(x: 200, y: 300), CGPoint(x: 700, y: 300)], size: 48)
        XCTAssertFalse(starlightPaper.flakes.isEmpty)
    }
}
