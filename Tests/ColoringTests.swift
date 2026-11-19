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
            if brush != .stamps && brush != .crayon {
                XCTAssertNotEqual(paper.pixel(900, 600), PaintColor.white.packed, "\(brush) painted nothing")
            }
        }
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
        let paper = ColoringPaper(lineArt: ColoringCatalog.lineArt("kitty"))
        paper.fill(at: CGPoint(x: 800, y: 560), style: .solid, color: PaintColor.hex(0xFF8A3D))
        let id = "test-\(UUID().uuidString)"
        let gallery = ColoringGallery.shared
        gallery.save(id: id, page: "kitty", paper: paper, stickers: [ColorSticker(emoji: "🦄", x: 300, y: 300)])
        defer { if let a = gallery.items.first(where: { $0.id == id }) { gallery.delete(a) } }
        XCTAssertEqual(gallery.items.first?.id, id)
        XCTAssertNotNil(gallery.thumbnail(id))
        XCTAssertEqual(gallery.stickers(id).first?.emoji, "🦄")
        let reloaded = ColoringPaper(lineArt: ColoringCatalog.lineArt("kitty"))
        reloaded.load(gallery.colorLayer(id)!)
        XCTAssertEqual(reloaded.pixel(800, 560), paper.pixel(800, 560))
        XCTAssertNotNil(gallery.fullPicture(gallery.items.first!))
    }
}
