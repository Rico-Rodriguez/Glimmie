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

    func testPaintMixesLikePaint() {
        let green = PaintMix.mix([(RGB(hex: "#5C9BEB"), 1), (RGB(hex: "#FFE27A"), 1)])
        XCTAssertGreaterThan(green.g, green.r)
        XCTAssertGreaterThan(green.g, green.b)
        let pink = PaintMix.mix([(RGB(hex: "#E8475A"), 1), (RGB(hex: "#FFFFFF"), 3)])
        XCTAssertGreaterThan(pink.r, pink.g)
        XCTAssertTrue(Look.isHex(PaintMix.hex(pink)))
    }

    func testMixedColorsAndSalonSanitize() throws {
        var l = Look.starter
        l.mixed = ["dress": "#12AB34", "hat": "nope", "zzz": "#FFFFFF"]
        let s = l.sanitized()
        XCTAssertEqual(s.mixed, ["dress": "#12AB34"])
        let dress = try XCTUnwrap(art.items["d_princess"])
        XCTAssertEqual(s.paints(for: dress).main, RGB(hex: "#12AB34"))
        var h = Look.starter
        h.mixed = ["hair": "#3366CC", "eye": "#22AA55"]
        let hs = h.sanitized()
        XCTAssertEqual(hs.mixed.count, 2)
        let hair = try XCTUnwrap(art.items.values.first { $0.colorSource == .hair })
        XCTAssertEqual(hs.paints(for: hair).main, RGB(hex: "#3366CC"))
        var p = PetLook(kind: "kitty")
        p.dye = 99; p.nails = -1; p.cheek = "moon"; p.glitter = true
        let q = try XCTUnwrap(p.sanitized())
        XCTAssertNil(q.dye); XCTAssertNil(q.nails); XCTAssertNil(q.cheek); XCTAssertTrue(q.glitter)
        p.dye = PetPainter.dyes.count
        XCTAssertEqual(p.sanitized()?.dye, PetPainter.dyes.count)
    }

    func testOutfitSetsUseRealItems() throws {
        let pets = PetArt.shared
        for set in OutfitSet.all {
            XCTAssertEqual(art.items[set.bg]?.category, "bg", set.id)
            XCTAssertNotNil(art.items[set.icon], set.id)
            for (cat, id) in set.picks {
                XCTAssertEqual(art.items[id]?.category, cat, "\(set.id): \(id)")
                XCTAssertTrue(OutfitSet.dressing.contains(cat), "\(set.id): \(cat)")
            }
            for (slot, id) in set.pet { XCTAssertEqual(pets.wear[id]?.slot, slot, "\(set.id): \(id)") }
            var l = Look.starter
            l.pet = PetLook(kind: "kitty")
            let on = set.apply(to: l).sanitized()
            for (cat, id) in set.picks { XCTAssertEqual(on.picks[cat], id, "\(set.id): \(cat)") }
            XCTAssertEqual(on.bg, set.bg)
            for (slot, id) in set.pet { XCTAssertEqual(on.pet?.wear[slot], id, "\(set.id) pet: \(slot)") }
        }
    }

    func testPhotoStickersSaveAndSanitize() throws {
        var l = Look.starter
        l.stickers = [PhotoSticker(kind: "heart.fill", x: 2, y: -1, size: 9, turn: 30),
                      PhotoSticker(kind: "item:h_crown", x: 0.5, y: 0.5),
                      PhotoSticker(kind: "pet:kitty", x: 0.4, y: 0.6),
                      PhotoSticker(kind: "mypet", x: 0.4, y: 0.6),
                      PhotoSticker(kind: "nope", x: 0.5, y: 0.5),
                      PhotoSticker(kind: "item:zzz", x: 0.5, y: 0.5)]
        l.frame = "stars"
        let s = l.sanitized()
        XCTAssertEqual(s.stickers.map(\.kind), ["heart.fill", "item:h_crown", "pet:kitty", "mypet"])
        XCTAssertEqual(s.stickers[0].x, 1); XCTAssertEqual(s.stickers[0].y, 0); XCTAssertEqual(s.stickers[0].size, 0.5)
        XCTAssertEqual(s.frame, "stars")
        let back = try JSONDecoder().decode(Look.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.stickers, s.stickers)
        XCTAssertEqual(back.frame, "stars")
        l.frame = "zzz"
        XCTAssertNil(l.sanitized().frame)
        for k in Stickers.items { XCTAssertNotNil(art.items[k], k) }
        for k in Stickers.pets { XCTAssertNotNil(PetArt.shared.animals[k], k) }
        // old saves without stickers still load
        let old = try JSONDecoder().decode(Look.self, from: Data(#"{"skin":2,"bg":"bg_park"}"#.utf8))
        XCTAssertTrue(old.stickers.isEmpty)
        XCTAssertNil(old.frame)
    }

    func testGalleryPhotosStartPlainAndUpdate() {
        let store = LookStore()
        store.current.stickers = [PhotoSticker(kind: "star.fill", x: 0.5, y: 0.5)]
        var photo = store.saveToGallery()
        XCTAssertTrue(photo.stickers.isEmpty)
        photo.frame = "gold"
        store.update(photo)
        XCTAssertEqual(store.gallery.first?.frame, "gold")
        store.open(photo)
        XCTAssertNil(store.current.frame)
        store.delete(photo)
    }

    func testMakeupAndNailsSaveAndSanitize() throws {
        var l = Look.starter
        l.makeup = [BeautyStroke(tool: "blush", color: "#FF8FA8", pts: [200, 360, 210, 362, 5]),
                    BeautyStroke(tool: "glitter", color: "rainbow", pts: [300, 300]),
                    BeautyStroke(tool: "tattoo", color: "#FF8FA8", pts: [1, 2]),
                    BeautyStroke(tool: "lip", color: "red", pts: [300, 388]),
                    BeautyStroke(tool: "shadow", color: "#B48BE8", pts: [])]
        var n = NailPaint()
        n.color = "#F45C9A"
        n.mask = NailGrid.encode(NailGrid.inside)
        n.coats = 9
        n.gems = [NailGem(kind: "g_heart", color: "#FFFFFF", u: 4, v: -2), NailGem(kind: "nope", color: "#FFFFFF", u: 0, v: 0)]
        var bad = NailPaint()
        bad.color = "pink"
        bad.mask = "zz"
        l.nails = [n, bad, NailPaint(), NailPaint(), NailPaint(), NailPaint()]
        let s = l.sanitized()
        XCTAssertEqual(s.makeup.map(\.tool), ["blush", "glitter"])
        XCTAssertEqual(s.makeup[0].pts.count, 4)
        XCTAssertEqual(s.nails.count, 5)
        XCTAssertEqual(s.nails[0].coats, 3)
        XCTAssertEqual(s.nails[0].gems.count, 1)
        XCTAssertEqual(s.nails[0].gems[0].u, 1)
        XCTAssertEqual(s.nails[0].gems[0].v, 0)
        XCTAssertNil(s.nails[1].color)
        XCTAssertTrue(s.nails[0].painted)
        let back = try JSONDecoder().decode(Look.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.makeup, s.makeup)
        XCTAssertEqual(back.nails, s.nails)
        // bare nails are not kept
        var plain = Look.starter
        plain.nails = [NailPaint(), NailPaint()]
        XCTAssertTrue(plain.sanitized().nails.isEmpty)
    }

    func testNailGridRoundTripsAndShape() {
        let bits = (0..<NailGrid.count).map { $0 % 3 == 0 }
        XCTAssertEqual(NailGrid.decode(NailGrid.encode(bits)), bits)
        XCTAssertTrue(NailGrid.isMask(NailGrid.encode(bits)))
        let inside = NailGrid.inside.filter { $0 }.count
        XCTAssertGreaterThan(inside, NailGrid.count / 2)
        XCTAssertLessThan(inside, NailGrid.count)
        // every nail sits on its finger, and points map back and forth
        for i in CloseHand.fingers.indices {
            let p = CloseHand.fromNail(i, u: 0.3, v: 0.6)
            let (u, v) = CloseHand.toNail(i, p)
            XCTAssertEqual(u, 0.3, accuracy: 1e-6)
            XCTAssertEqual(v, 0.6, accuracy: 1e-6)
            XCTAssertEqual(CloseHand.nail(at: p), i)
            XCTAssertTrue(CloseHand.onSkin(CloseHand.fromNail(i, u: 0, v: -0.3)))
        }
    }

    func testPolishPaintsSpreadsAndDries() {
        let world = BeautyWorld(look: Look.starter, mode: .nails)
        world.size = CGSize(width: 600, height: 790)
        world.color = "#7FB8F0"
        world.dip()
        // brush up and down the middle nail, the tool tip at her fingertip
        let k = min(600 / BeautyWorld.handBox.width, 790 / BeautyWorld.handBox.height)
        let ox = (600 - BeautyWorld.handBox.width * k) / 2, oy = (790 - BeautyWorld.handBox.height * k) / 2
        func stage(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x - BeautyWorld.handBox.minX) * k + ox, y: (p.y - BeautyWorld.handBox.minY) * k + oy + world.lift)
        }
        var t = 100.0
        world.step(to: t)
        world.press(stage(CloseHand.fromNail(2, u: 0, v: 0.1)))
        for j in 0..<30 {
            for u in [-0.5, 0.0, 0.5] { world.move(stage(CloseHand.fromNail(2, u: u, v: 0.1 + 0.8 * Double(j % 10) / 10))) }
            t += 0.03; world.step(to: t)
        }
        world.release()
        XCTAssertGreaterThan(world.wet[2], 0)
        XCTAssertLessThan(world.load, 1)
        for _ in 0..<400 { t += 0.05; world.step(to: t) }
        XCTAssertEqual(world.wet[2], 0)
        let done = world.finished()
        XCTAssertTrue(done.nails[2].painted)
        XCTAssertFalse(done.nails[0].painted)
        XCTAssertEqual(done.nails[2].color.map { RGB(hex: $0).b > 0.8 }, true)
    }

    func testMakeupStrokesStayOnTheFace() {
        let world = BeautyWorld(look: Look.starter, mode: .makeup)
        world.size = CGSize(width: 600, height: 790)
        world.tool = .lip
        world.color = "#E8475A"
        let b = BeautyWorld.faceBox
        let k = min(600 / b.width, 790 / b.height)
        let ox = (600 - b.width * k) / 2, oy = (790 - b.height * k) / 2
        func stage(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - b.minX) * k + ox, y: (p.y - b.minY) * k + oy + world.lift) }
        world.press(stage(CGPoint(x: 280, y: 388)))
        world.move(stage(CGPoint(x: 300, y: 390)))
        world.move(stage(CGPoint(x: 320, y: 388)))
        world.move(stage(CGPoint(x: 300, y: 200)))   // far off the lips: ignored
        world.release()
        let lip = world.look.makeup.first { $0.tool == "lip" }
        XCTAssertNotNil(lip)
        XCTAssertTrue(lip?.points.allSatisfy { abs($0.y - 388) < 25 } ?? false)
        world.tool = .wipe
        world.press(stage(CGPoint(x: 300, y: 390)))
        world.move(stage(CGPoint(x: 282, y: 388)))
        world.move(stage(CGPoint(x: 318, y: 388)))
        world.release()
        XCTAssertTrue(world.look.makeup.allSatisfy { $0.points.allSatisfy { abs($0.x - 300) > 15 } })
        world.undo()
        XCTAssertFalse(world.look.makeup.isEmpty)
    }
}
