import XCTest
@testable import Glimmie

final class DressUpTests: XCTestCase {
    let art = DressUpArt.shared

    func testArtLoads() {
        XCTAssertGreaterThan(art.items.count, 150)
        XCTAssertEqual(art.skin.count, 8)
        XCTAssertFalse(art.cloth.isEmpty)
        for c in art.categories where c.id != "skin" {
            XCTAssertFalse(c.items.isEmpty, c.id)
            for id in c.items { XCTAssertNotNil(art.items[id], id) }
        }
        XCTAssertNotNil(art.items["body"])
        XCTAssertNotNil(art.items["eyes_closed"])
        XCTAssertNotNil(art.items["eyes_happy"])
    }

    func testEveryPathParses() {
        for (id, item) in art.items {
            for layer in item.layers {
                for s in layer.shapes {
                    XCTAssertFalse(s.path.isEmpty, id)
                }
            }
        }
    }

    func testStarterLookIsComplete() {
        let l = Look.starter.sanitized()
        for c in art.categories where c.required && c.id != "skin" && c.id != "bg" {
            XCTAssertNotNil(l.picks[c.id], c.id)
        }
    }

    func testDressReplacesTopAndBottom() {
        var l = Look.starter
        l.wear("t_tee", in: "top")
        l.wear("b_skirt", in: "bottom")
        XCTAssertNil(l.picks["dress"])
        l.wear("d_party", in: "dress")
        XCTAssertNil(l.picks["top"])
        XCTAssertNil(l.picks["bottom"])
        XCTAssertEqual(l.picks["dress"], "d_party")
    }

    func testRoundTrip() throws {
        var l = Look.random()
        l.patterns["dress"] = "dots"
        let back = try JSONDecoder().decode(Look.self, from: JSONEncoder().encode(l))
        XCTAssertEqual(back, l)
    }

    func testLenientDecodingAndSanitize() throws {
        let json = Data(#"{"skin": 99, "picks": {"hat": "nope", "eyes": "e_star"}, "colors": {"hat": 500}, "bg": "bg_unknown", "future": 1}"#.utf8)
        let l = try JSONDecoder().decode(Look.self, from: json).sanitized()
        XCTAssertEqual(l.skin, art.skin.count - 1)
        XCTAssertNil(l.picks["hat"])
        XCTAssertEqual(l.picks["eyes"], "e_star")
        XCTAssertEqual(l.colors["hat"], art.cloth.count - 1)
        XCTAssertEqual(art.items[l.bg]?.category, "bg")
        XCTAssertNotNil(l.picks["hairFront"])
    }

    func testRandomLooksAreValid() {
        for _ in 0..<50 {
            let l = Look.random()
            XCTAssertEqual(l.sanitized(), l)
            XCTAssertFalse(l.picks["dress"] != nil && l.picks["top"] != nil)
        }
    }
}
