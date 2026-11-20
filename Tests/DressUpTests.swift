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

    func testPetSaveDefaultsAndLenientDecoding() throws {
        let s = try JSONDecoder().decode(PetSave.self, from: Data(#"{"names": {"p_kitty": "Luna"}, "love": {"p_teddy": 7}, "current": "p_duck", "odd": true}"#.utf8))
        XCTAssertEqual(s.name("kitty"), "Luna")
        XCTAssertEqual(s.name("puppy"), "Biscuit")
        XCTAssertEqual(s.love["bear"], 7)
        XCTAssertEqual(s.current, "duckling")
        XCTAssertEqual(PetSave().current, "kitty")
        XCTAssertEqual(PetSave.pets.count, 20)
        for p in PetSave.pets {
            XCTAssertNotNil(PetArt.shared.animals[p], p)
            XCTAssertNotNil(PetSave.defaultNames[p], p)
            XCTAssertNotNil(PetSave.favorites[p].flatMap { PetArt.shared.props[$0] }, p)
        }
    }

    func testPetArtLoads() {
        let pets = PetArt.shared
        XCTAssertEqual(pets.slots, ["hat", "glasses", "neck", "body", "back"])
        for s in pets.slots {
            XCTAssertFalse(pets.bySlot[s]?.isEmpty ?? true, s)
            XCTAssertNotNil(pets.thumbs[s], s)
        }
        for (id, a) in pets.animals {
            XCTAssertFalse(a.torso.isEmpty, id)
            XCTAssertFalse(a.head.isEmpty, id)
            for e in ["open", "blink", "happy", "sparkle", "tired"] { XCTAssertNotNil(a.eyes[e], "\(id) \(e)") }
            for m in ["smile", "grin", "yum", "o", "wide"] { XCTAssertNotNil(a.mouths[m], "\(id) \(m)") }
        }
        for name in ["sponge", "shower", "towel", "brush", "ball", "yarn", "feather", "bed", "blanket", "foam",
                     "fish", "bone", "carrot", "berry", "cookie", "cupcake"] {
            XCTAssertFalse(pets.props[name]?.isEmpty ?? true, name)
        }
    }

    func testOldHeldPetsMoveToThePetCorner() throws {
        let json = Data(#"{"picks": {"hold": "p_kitty", "eyes": "e_star"}}"#.utf8)
        let l = try JSONDecoder().decode(Look.self, from: json).sanitized()
        XCTAssertNil(l.picks["hold"])
        XCTAssertEqual(l.pet?.kind, "kitty")
        let teddy = try JSONDecoder().decode(Look.self, from: Data(#"{"picks": {"hold": "p_teddy"}}"#.utf8)).sanitized()
        XCTAssertEqual(teddy.picks["hold"], "p_teddy")
        XCTAssertNil(teddy.pet)
    }

    func testPetLookSanitizeAndRoundTrip() throws {
        var p = PetLook(kind: "dragon")
        p.wear = ["hat": "ph_crown", "body": "ph_crown", "neck": "nope"]
        p.colors = ["hat": 999, "glasses": 2]
        p.patterns = ["hat": "dots"]
        let s = try XCTUnwrap(p.sanitized())
        XCTAssertEqual(s.wear, ["hat": "ph_crown"])
        XCTAssertEqual(s.colors, ["hat": art.cloth.count - 1])
        XCTAssertNil(PetLook(kind: "dodo").sanitized())
        var l = Look.starter
        l.pet = s
        let back = try JSONDecoder().decode(Look.self, from: JSONEncoder().encode(l))
        XCTAssertEqual(back.pet, s)
        for _ in 0..<30 {
            let r = PetLook.random(kind: "kitty")
            XCTAssertEqual(r.sanitized(), r)
        }
    }

    func testOldLooksGainAFaceAndNose() throws {
        let l = try JSONDecoder().decode(Look.self, from: Data(#"{"picks": {"eyes": "e_star"}}"#.utf8)).sanitized()
        XCTAssertEqual(l.picks["face"], "face_round")
        XCTAssertNotNil(l.picks["nose"])
    }

    func testBattleThemesUseRealItems() {
        for t in BattleTheme.all {
            XCTAssertEqual(art.items[t.scene]?.category, "bg", t.id)
            for id in t.items.union(t.hints) { XCTAssertNotNil(art.items[id], "\(t.id): \(id)") }
            let stars = t.stars(t.rival(), luck: [0, 0, 0])
            XCTAssertEqual(stars.count, 3)
            XCTAssertTrue(stars.allSatisfy { (1...5).contains($0) })
        }
    }
}
