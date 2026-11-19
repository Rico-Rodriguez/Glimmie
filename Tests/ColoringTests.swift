import XCTest
import UIKit
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
        wait(for: [added], timeout: 30)
        let id = try! XCTUnwrap(pageID)
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
}
