import XCTest
@testable import Glimmie

final class BakeryTests: XCTestCase {
    let art = BakeryArt.shared

    func testArtLoads() {
        XCTAssertGreaterThan(art.sprites.count, 100)
        XCTAssertEqual(art.tiers.count, 3)
        for name in ["plate", "liner", "cupcake_top", "scoop", "sauce", "bowl_back", "bowl_front", "batter", "oven", "pan", "counter"] {
            XCTAssertNotNil(art.sprites[name], name)
        }
        for c in BakeryPalette.customers { XCTAssertNotNil(art.sprites["cust_\(c)"], c) }
        for c in BakeryPalette.cones { XCTAssertNotNil(art.sprites["cone_\(c)"], c) }
        for s in BakeryPalette.frostStyles { for k in 1...3 { XCTAssertNotNil(art.sprites["frost_\(s)\(k)"], s) } }
        for i in 0..<3 { XCTAssertNotNil(art.sprites["cake_body\(i)"]); XCTAssertNotNil(art.sprites["cake_frost\(i)"]) }
        for f in BakeryPalette.flavors { XCTAssertNotNil(art.sprites[f.icon], f.icon) }
        for e in ["eyes_open", "eyes_blink", "eyes_happy", "eyes_star", "mouth_smile", "mouth_open", "mouth_chew"] {
            XCTAssertNotNil(art.sprites[e], e)
        }
    }

    func testEveryTrayToppingHasArt() {
        var count = 0
        for tray in BakeryPalette.trays {
            XCTAssertNotNil(art.sprites[tray.icon], tray.icon)
            for item in tray.items {
                let name = item.hasPrefix("*") ? "bit_" + item.dropFirst() : "top_" + item
                XCTAssertNotNil(art.sprites[name], name)
                count += 1
            }
        }
        XCTAssertGreaterThanOrEqual(count, 40)
    }

    func testEveryPathParses() {
        for (name, shapes) in art.sprites {
            for s in shapes { XCTAssertFalse(s.path.isEmpty, name) }
        }
    }

    func testFrostSamplesCoverEveryTier() {
        for n in 1...3 { XCTAssertGreaterThan(FrostStepView.makeSamples(tiers: n).count, 40 * n) }
    }

    func testTreatRoundTrip() throws {
        for k in TreatKind.allCases {
            let t = Treat.sample(k, seed: 3)
            let back = try JSONDecoder().decode(Treat.self, from: JSONEncoder().encode(t))
            XCTAssertEqual(back, t)
        }
    }

    func testRandomSpotsLandOnTheTreat() {
        for k in TreatKind.allCases {
            var t = Treat.sample(k, seed: 1)
            for tiers in 1...3 {
                t.tiers = tiers
                for _ in 0..<50 {
                    let p = TreatPainter.randomSpot(on: t)
                    XCTAssert(p.x > 80 && p.x < 520 && p.y > 40 && p.y < 560, "\(k) \(p)")
                }
            }
        }
    }

    func testSoundsAreBundled() {
        for s in BakeSFX.allCases { XCTAssertNotNil(GameFiles.url(s.rawValue, "wav", game: "Bakery"), s.rawValue) }
    }
}
