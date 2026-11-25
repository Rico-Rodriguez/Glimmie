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

    func testDressUpStickersRegistered() {
        StickerBook.shared.demo = true
        let expected: Set<String> = [
            "runwayStar", "outfitSet", "petBestie", "nailArtist",
            "glamMakeup", "colorAlchemist", "storyDirector", "photoQueen",
        ]
        XCTAssertEqual(DressUpFind.allCases.count, 8)
        XCTAssertEqual(DressUpFind.stickers.count, 8)
        XCTAssertEqual(Set(DressUpFind.stickers.map(\.id)), expected)
        XCTAssertEqual(DressUpGame.entry.stickers.map(\.id), DressUpFind.stickers.map(\.id))
        DressUpFind.outfitSet.unlock()
        XCTAssertTrue(StickerBook.shared.has(game: LookStore.game, id: DressUpFind.outfitSet.rawValue))
    }

    func testFashionBattleCountsMakeupNailsAndAwardsCoins() {
        StickerBook.shared.demo = true
        Coins.shared.resetForTests(balance: 0)
        let theme = BattleTheme.all[0]
        var look = Look.starter.sanitized()
        let base = theme.points(look)

        look.makeup = [BeautyStroke(tool: "blush", color: "#FF8FA8", pts: [220, 360, 236, 364])]
        XCTAssertEqual(theme.points(look), base + 1)

        var nail = NailPaint()
        nail.color = "#F45C9A"
        nail.mask = NailGrid.encode(NailGrid.inside)
        look.nails = [nail]
        XCTAssertEqual(theme.points(look), base + 2)

        let scores = theme.stars(look, luck: [0, 0, 0])
        XCTAssertEqual(scores.count, 3)
        XCTAssertTrue(scores.allSatisfy { (1...5).contains($0) })

        let lowReward = BattleTheme.coinReward(stars: [2, 2, 2], won: false)
        XCTAssertTrue((3...5).contains(lowReward))

        let paid = BattleTheme.awardRunway(stars: [5, 5, 5], won: true)
        XCTAssertTrue((3...5).contains(paid))
        XCTAssertEqual(Coins.shared.balance, paid)
        XCTAssertEqual(Coins.shared.lastPay?.game, LookStore.game)
        XCTAssertTrue(StickerBook.shared.has(game: LookStore.game, id: DressUpFind.runwayStar.rawValue))
    }

    func testColorMixerReceivesCategoryPalettes() {
        XCTAssertEqual(ColorMixer.palette(forCategory: "hairBack", art: art), art.hair)
        XCTAssertEqual(ColorMixer.palette(forCategory: "hairFront", art: art), art.hair)
        XCTAssertEqual(ColorMixer.palette(forCategory: "eyes", art: art), art.eye)
        XCTAssertEqual(ColorMixer.palette(forCategory: "dress", art: art), art.cloth)
        XCTAssertEqual(ColorMixer.palette(forCategory: "hat", art: art), art.cloth)
    }

    func testBeautyWorldRoutesPointsThroughFingerLift() {
        let world = BeautyWorld(look: Look.starter, mode: .makeup)
        world.size = CGSize(width: 600, height: 790)
        XCTAssertEqual(world.lift, FingerLift.tool)
        let finger = CGPoint(x: 360, y: 500)
        world.press(finger)
        let expected = FingerLift.point(finger, lift: world.lift, top: 0, bottom: 790, width: 600)
        XCTAssertEqual(world.tipOnStage?.x ?? -1, expected.x, accuracy: 0.001)
        XCTAssertEqual(world.tipOnStage?.y ?? -1, expected.y, accuracy: 0.001)
        world.tool = .glitter
        XCTAssertEqual(world.lift, FingerLift.pour)
        world.release()
    }

    func testSharedDressUpBundleDecodesOnce() {
        _ = DressUpArt.shared
        _ = PetArt.shared
        XCTAssertEqual(DressUpBundle.decodeCount, 1)
        XCTAssertGreaterThan(DressUpArt.shared.items.count, 150)
        XCTAssertEqual(PetArt.shared.animals.count, 20)
    }

    func testProceduralPatternsBuildAndBoundCleanly() {
        let expected = ["dots", "stripes", "hearts", "stars", "checks", "flowers", "tinydots"]
        XCTAssertEqual(art.patternNames, expected)
        let sampleBounds = CGRect(x: 200, y: 500, width: 200, height: 220)
        for name in expected {
            XCTAssertTrue(DressUpPatterns.isProcedural(name), name)
            XCTAssertNotNil(art.patterns[name], name)
            XCTAssertFalse(art.patterns[name]?.isEmpty ?? true, name)
            XCTAssertFalse(DressUpPatterns.path(for: name, in: sampleBounds).isEmpty, name)
        }
    }

    func testHanbokAndJewelFairyPiecesLoadMixAndRoundTrip() throws {
        let expectedPieces: [(String, String)] = [
            ("t_jeogori", "top"),
            ("b_chima", "bottom"),
            ("n_norigae", "neck"),
            ("h_jokduri", "hat"),
            ("h_daenggi", "hat"),
            ("d_jewelfairy", "dress"),
            ("h_hearttiara", "hat"),
            ("w_jewelwings", "back"),
            ("p_starwand", "hold"),
            ("p_heartcompact", "hold"),
        ]
        for (id, cat) in expectedPieces {
            let item = try XCTUnwrap(art.items[id], id)
            XCTAssertEqual(item.category, cat, id)
            XCTAssertTrue(art.category(cat)?.items.contains(id) ?? false, "\(cat) missing \(id)")
            for layer in item.layers {
                for shape in layer.shapes {
                    XCTAssertFalse(shape.path.isEmpty, id)
                }
            }
        }

        XCTAssertTrue(LiveDollPainter.wings.contains("w_jewelwings"))
        XCTAssertTrue(LiveDollPainter.sparkly.isSuperset(of: DressUpCulturalOutfits.sparklyIDs))

        let hanbok = try XCTUnwrap(OutfitSet.all.first { $0.id == "hanbok" })
        let fairy = try XCTUnwrap(OutfitSet.all.first { $0.id == "jewelFairy" })
        let wearingHanbok = hanbok.apply(to: Look.starter).sanitized()
        XCTAssertEqual(wearingHanbok.picks["top"], "t_jeogori")
        XCTAssertEqual(wearingHanbok.picks["bottom"], "b_chima")
        XCTAssertEqual(wearingHanbok.picks["neck"], "n_norigae")
        XCTAssertEqual(wearingHanbok.picks["hat"], "h_jokduri")

        let wearingFairy = fairy.apply(to: Look.starter).sanitized()
        XCTAssertEqual(wearingFairy.picks["dress"], "d_jewelfairy")
        XCTAssertEqual(wearingFairy.picks["hat"], "h_hearttiara")
        XCTAssertEqual(wearingFairy.picks["back"], "w_jewelwings")
        XCTAssertEqual(wearingFairy.picks["hold"], "p_starwand")

        // Mix-and-match: Hanbok + fairy wings + heart compact + daenggi saves and reloads intact.
        var mix = wearingHanbok
        mix.wear("w_jewelwings", in: "back")
        mix.wear("p_heartcompact", in: "hold")
        mix.wear("h_daenggi", in: "hat")
        let encoded = try JSONEncoder().encode(mix)
        let decoded = try JSONDecoder().decode(Look.self, from: encoded).sanitized()
        XCTAssertEqual(decoded.picks["top"], "t_jeogori")
        XCTAssertEqual(decoded.picks["bottom"], "b_chima")
        XCTAssertEqual(decoded.picks["back"], "w_jewelwings")
        XCTAssertEqual(decoded.picks["hold"], "p_heartcompact")
        XCTAssertEqual(decoded.picks["hat"], "h_daenggi")
    }

    func testDollDefaultsSyncBridgeAndSalonCompatibility() throws {
        let suiteName = "glimmie.dressup.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var look = Look.starter
        look.skin = min(4, art.skin.count - 1)
        look.hair = min(9, art.hair.count - 1)
        look.eye = min(7, art.eye.count - 1)
        look.syncDollDefaults(defaults, art: art)

        XCTAssertEqual(defaults.string(forKey: Look.skinHexKey), art.skin[look.skin].hexString)
        XCTAssertEqual(defaults.string(forKey: Look.hairHexKey), art.hair[look.hair].hexString)
        XCTAssertEqual(defaults.string(forKey: Look.eyeHexKey), art.eye[look.eye].hexString)

        // Verify Hair Salon's exact nearest-index reader recovers every index cleanly.
        XCTAssertEqual(
            SalonDollDefaults.nearestIndex(hex: defaults.string(forKey: Look.skinHexKey), in: art.skin, fallback: 0),
            look.skin
        )
        XCTAssertEqual(
            SalonDollDefaults.nearestIndex(hex: defaults.string(forKey: Look.hairHexKey), in: art.hair, fallback: 0),
            look.hair
        )
        XCTAssertEqual(
            SalonDollDefaults.nearestIndex(hex: defaults.string(forKey: Look.eyeHexKey), in: art.eye, fallback: 0),
            look.eye
        )

        // Custom mixed hair color also propagates cleanly.
        look.mixed["hair"] = "#FF6FA8"
        look.syncDollDefaults(defaults, art: art)
        XCTAssertEqual(defaults.string(forKey: Look.hairHexKey), "#FF6FA8")
    }

    func testPinnedFairySpecsCoverAllTwelveFairies() throws {
        let suiteName = "glimmie.dressup.fairy.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let expectedIDs = [
            "heart", "star", "berry", "cloud", "ribbon", "moon",
            "melody", "peach", "dewdrop", "honey", "blossom", "silk",
        ]
        XCTAssertEqual(PinnedFairySpec.allIDs, expectedIDs)
        XCTAssertNil(PinnedFairySpec.pinned(from: defaults))

        for id in expectedIDs {
            defaults.set(id, forKey: PinnedFairySpec.defaultsKey)
            let spec = PinnedFairySpec.pinned(from: defaults)
            XCTAssertEqual(spec?.id, id, id)
        }
        defaults.set("unknown_fairy", forKey: PinnedFairySpec.defaultsKey)
        XCTAssertNil(PinnedFairySpec.pinned(from: defaults))
    }

    func testStageDollFittingAndGalleryCoinGuard() {
        // 1024x834 landscape leaves 526pt for the stage column beside the 480+18pt wardrobe tray.
        let fitted = DressUpView.fittedDollSize(in: CGSize(width: 526, height: 834))
        XCTAssertLessThanOrEqual(fitted.width, 526)
        XCTAssertLessThanOrEqual(fitted.height, 834)
        let expectedAspect = DressUpView.stageBox.width / DressUpView.stageBox.height
        XCTAssertEqual(fitted.width / fitted.height, expectedAspect, accuracy: 0.001)

        var guarder = DressUpCoinGuard(cooldown: 5.0)
        let t0 = Date(timeIntervalSinceReferenceDate: 1000)
        XCTAssertTrue(guarder.canReward(signature: "look-a", now: t0))
        XCTAssertFalse(guarder.canReward(signature: "look-a", now: t0.addingTimeInterval(20)))
        XCTAssertFalse(guarder.canReward(signature: "look-b", now: t0.addingTimeInterval(2)))
        XCTAssertTrue(guarder.canReward(signature: "look-b", now: t0.addingTimeInterval(6)))

        Coins.shared.resetForTests(balance: 0)
        let store = LookStore()
        var look = Look.starter.sanitized()
        let firstAward = store.awardGallerySaveCoins(for: look, now: t0)
        XCTAssertEqual(firstAward, LookStore.galleryCoinReward)
        XCTAssertEqual(Coins.shared.balance, LookStore.galleryCoinReward)
        XCTAssertEqual(store.awardGallerySaveCoins(for: look, now: t0.addingTimeInterval(10)), 0)
        look.wear("d_jewelfairy", in: "dress")
        XCTAssertEqual(store.awardGallerySaveCoins(for: look, now: t0.addingTimeInterval(10)), LookStore.galleryCoinReward)
    }

    func testPlayhouseKeepyUppyBalloonXylophoneFreezeAndTeaParty() throws {
        let stage = CGSize(width: 1024, height: 616)
        var state = PlayhouseState()
        let doll = PlayhouseActor(look: Look.starter.sanitized(), x: 0.50, y: 0.90)
        let pet = PlayhouseActor(pet: PetLook(kind: "kitty"), x: 0.72, y: 0.92)
        state.actors = [doll, pet]

        // 1. Keepy Uppy Balloon spawns, falls under gravity, and bounces on tap.
        state.spawnOrBoostBalloon(stageSize: stage)
        let spawned = try XCTUnwrap(state.balloon)
        for _ in 0..<25 { state.step(dt: 1.0 / 60.0, stageSize: stage) }
        let afterGravity = try XCTUnwrap(state.balloon)
        XCTAssertGreaterThan(afterGravity.vy, spawned.vy)
        XCTAssertTrue(state.tapBalloon(at: CGPoint(x: afterGravity.x, y: afterGravity.y)))
        XCTAssertLessThan(state.balloon?.vy ?? 0, 0)

        // 2. Dipping balloon near an unfrozen doll auto-bops upward!
        state.balloon = KeepyUppyBalloon(x: stage.width * 0.50, y: stage.height * 0.56, vx: 0, vy: 120, colorIndex: 0)
        let bopEvents = state.step(dt: 1.0 / 60.0, stageSize: stage)
        XCTAssertTrue(bopEvents.actorBoppedIDs.contains(doll.id))
        XCTAssertLessThan(state.balloon?.vy ?? 0, 0)

        // 3. Magic Xylophone toggles freeze poses cleanly, and frozen actors stay frozen!
        XCTAssertFalse(state.isAnyFrozen)
        let didFreeze = state.triggerXylophone(bar: 0, stageSize: stage)
        XCTAssertTrue(didFreeze)
        XCTAssertTrue(state.isAnyFrozen)
        XCTAssertNotNil(state.actors[0].freezePose)
        XCTAssertNotNil(state.actors[1].freezePose)
        XCTAssertNotEqual(state.actors[0].freezePose, state.actors[1].freezePose)

        // Wait out bop cooldown before verifying that freeze state itself blocks auto-bopping.
        state.balloon = nil
        for _ in 0..<40 { state.step(dt: 1.0 / 60.0, stageSize: stage) }

        // While frozen, balloon does not get auto-bopped by frozen doll.
        state.balloon = KeepyUppyBalloon(x: stage.width * 0.50, y: stage.height * 0.56, vx: 0, vy: 120, colorIndex: 1)
        let frozenEvents = state.step(dt: 1.0 / 60.0, stageSize: stage)
        XCTAssertTrue(frozenEvents.actorBoppedIDs.isEmpty)

        // Second xylophone tap unfreezes everyone!
        let didFreezeAgain = state.triggerXylophone(bar: 3, stageSize: stage)
        XCTAssertFalse(didFreezeAgain)
        XCTAssertFalse(state.isAnyFrozen)
        XCTAssertTrue(state.actors.allSatisfy { !$0.isFrozen })

        // 4. Backyard Tea Party serves 4 treats and handles nibbles cleanly.
        state.setOutTeaParty()
        XCTAssertEqual(state.treats.count, 4)
        let cake = try XCTUnwrap(state.treats.first { $0.kind == .strawberryCake })
        let teapot = try XCTUnwrap(state.treats.first { $0.kind == .teapot })
        let eater = state.nibbleTreat(cake.id, nearActor: doll.id, stageSize: stage)
        XCTAssertEqual(eater, doll.id)
        XCTAssertEqual(state.treats.first { $0.id == cake.id }?.bitesLeft, 2)
        state.nibbleTreat(cake.id, nearActor: doll.id, stageSize: stage)
        state.nibbleTreat(cake.id, nearActor: doll.id, stageSize: stage)
        XCTAssertNil(state.treats.first { $0.id == cake.id })
        // Teapot pours sips without disappearing.
        XCTAssertEqual(state.nibbleTreat(teapot.id, nearActor: pet.id, stageSize: stage), pet.id)
        XCTAssertNotNil(state.treats.first { $0.id == teapot.id })
    }

    @MainActor
    func testPlayhouseSnapshotRendersAndSavesToGallery() throws {
        Coins.shared.resetForTests(balance: 0)
        var frozenDoll = PlayhouseActor(look: Look.starter.sanitized(), x: 0.34, y: 0.90)
        frozenDoll.freezePose = .oneLegTilt
        let pet = PlayhouseActor(pet: PetLook(kind: "bunny"), x: 0.64, y: 0.92, flip: true)
        let balloon = KeepyUppyBalloon(x: 512, y: 180, vx: 10, vy: -40, colorIndex: 2)
        let treats = [PlayhouseTreat(kind: .bungeoppang, x: 0.48, y: 0.90)]

        let image = try XCTUnwrap(
            PlayhouseSnapshotRenderer.render(
                bg: PlayhouseBackdrop.porch,
                actors: [frozenDoll, pet],
                balloon: balloon,
                treats: treats,
                me: Look.starter.sanitized()
            )
        )
        XCTAssertEqual(image.size.width, PlayhouseSnapshotRenderer.snapshotSize.width, accuracy: 1)
        XCTAssertEqual(image.size.height, PlayhouseSnapshotRenderer.snapshotSize.height, accuracy: 1)
        XCTAssertFalse((image.pngData() ?? Data()).isEmpty)

        let store = LookStore()
        let saved = try XCTUnwrap(store.savePlayhouseSnapshot(image))
        defer { store.deletePlayhousePhoto(saved) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.fileURL.path))
        XCTAssertTrue(store.playhousePhotos.contains(where: { $0.id == saved.id }))
        XCTAssertNotNil(saved.loadImage())

        let coins = store.awardPlayhouseSnapCoins(signature: "porch-scene-1")
        XCTAssertEqual(coins, LookStore.playhouseCoinReward)
        XCTAssertEqual(Coins.shared.balance, LookStore.playhouseCoinReward)
    }

    func testBeautySoundResolvesAudioURLs() {
        for s in BeautySFX.allCases {
            XCTAssertNotNil(BeautySound.url(for: s), s.rawValue)
        }
    }

    func testTreasureShopHanbokCrownAndFairyWandGating() throws {
        Coins.shared.resetForTests(balance: 0)
        XCTAssertEqual(ArtCategory.treasureItems["h_hanbokCrown"], "dressup/h_hanbokCrown")
        XCTAssertEqual(ArtCategory.treasureItems["p_fairyWand"], "dressup/p_fairyWand")

        let crown = try XCTUnwrap(art.items["h_hanbokCrown"])
        let wand = try XCTUnwrap(art.items["p_fairyWand"])
        XCTAssertEqual(crown.category, "hat")
        XCTAssertEqual(wand.category, "hold")
        XCTAssertTrue(LiveDollPainter.sparkly.contains("h_hanbokCrown"))
        XCTAssertTrue(LiveDollPainter.sparkly.contains("p_fairyWand"))

        let hatCat = try XCTUnwrap(art.category("hat"))
        let holdCat = try XCTUnwrap(art.category("hold"))
        XCTAssertFalse(hatCat.availableItems.contains("h_hanbokCrown"))
        XCTAssertFalse(holdCat.availableItems.contains("p_fairyWand"))

        Coins.shared.resetForTests(balance: 60)
        XCTAssertTrue(Coins.shared.buy("dressup/h_hanbokCrown", price: 14))
        XCTAssertTrue(hatCat.availableItems.contains("h_hanbokCrown"))
        XCTAssertFalse(holdCat.availableItems.contains("p_fairyWand"))

        XCTAssertTrue(Coins.shared.buy("dressup/p_fairyWand", price: 14))
        XCTAssertTrue(holdCat.availableItems.contains("p_fairyWand"))

        var look = Look.starter
        look.wear("h_hanbokCrown", in: "hat")
        look.wear("p_fairyWand", in: "hold")
        let back = try JSONDecoder().decode(Look.self, from: JSONEncoder().encode(look)).sanitized()
        XCTAssertEqual(back.picks["hat"], "h_hanbokCrown")
        XCTAssertEqual(back.picks["hold"], "p_fairyWand")
    }
}
