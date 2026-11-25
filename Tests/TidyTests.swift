import XCTest
@testable import Glimmie

final class TidyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Coins.shared.resetForTests()
        StickerBook.shared.demo = true
    }

    func testLevels() {
        let all = TidyLevels.all
        XCTAssertEqual(all.count, 24)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertEqual(Set(all.map(\.scene)), Set(TidyScene.allCases))
        for l in all {
            XCTAssertGreaterThanOrEqual(l.slots.count, 4, l.id)
            XCTAssertLessThanOrEqual(l.slots.count, 16, l.id)
            for s in l.slots {
                let sz = s.kind.size
                let w = abs(cos(s.rot)) * sz.width + abs(sin(s.rot)) * sz.height
                let h = abs(sin(s.rot)) * sz.width + abs(cos(s.rot)) * sz.height
                XCTAssertGreaterThanOrEqual(s.pos.x - w / 2, 0, "\(l.id) \(s.kind)")
                XCTAssertLessThanOrEqual(s.pos.x + w / 2, TidyScene.size.width, "\(l.id) \(s.kind)")
                XCTAssertGreaterThanOrEqual(s.pos.y - h / 2, -4, "\(l.id) \(s.kind)")
                XCTAssertLessThanOrEqual(s.pos.y + h / 2, TidyScene.size.height + 4, "\(l.id) \(s.kind)")
            }
        }
    }

    func testEveryKindHasASize() {
        for k in TidyKind.allCases {
            XCTAssertGreaterThan(k.size.width, 10, k.rawValue)
            XCTAssertGreaterThan(k.size.height, 10, k.rawValue)
        }
    }

    /// Stacks never lock: filling open slots one at a time always fills every slot.
    func testEveryLevelCanBeFinished() {
        for l in TidyLevels.all {
            let w = TidyWorld(level: l)
            for _ in 0..<l.slots.count { w.placeSome(1) }
            XCTAssertTrue(w.filled.allSatisfy { $0 != nil }, l.id)
        }
    }

    func testStrictSlotsOnlyTakeTheirColor() {
        let w = TidyWorld(level: TidyLevels.bookshelf1)
        let red = w.bodies.first { $0.kind == .book && $0.color == 0 }!
        let slots = TidyLevels.bookshelf1.slots
        for (i, s) in slots.enumerated() where s.kind == .book {
            XCTAssertEqual(w.fits(red, i), s.color == 0)
        }
    }

    func testStacksFillFromTheBottom() {
        let w = TidyWorld(level: TidyLevels.cupboard1)
        let plates = TidyLevels.cupboard1.slots.indices.filter { TidyLevels.cupboard1.slots[$0].kind == .plate }
        let open = plates.filter { w.isOpen($0) }
        XCTAssertEqual(open.count, 1)
        XCTAssertEqual(open.first, plates.max { TidyLevels.cupboard1.slots[$0].pos.y < TidyLevels.cupboard1.slots[$1].pos.y })
    }

    /// The pile lands from the box, settles on the floor and stays on screen.
    func testPileSettles() {
        for l in TidyLevels.all {
            let w = TidyWorld(level: l)
            w.size = CGSize(width: 1194, height: 834)
            w.simulate(seconds: 7)
            var speed: CGFloat = 0
            for b in w.bodies {
                XCTAssertEqual(b.state, .loose, l.id)
                XCTAssertTrue(b.pos.x.isFinite && b.pos.y.isFinite, l.id)
                XCTAssertGreaterThan(b.pos.x, -5, "\(l.id) \(b.kind)")
                XCTAssertLessThan(b.pos.x, w.size.width + 5, "\(l.id) \(b.kind)")
                XCTAssertLessThan(b.pos.y, w.floorY + 2, "\(l.id) \(b.kind)")
                XCTAssertGreaterThan(b.pos.y, 200, "\(l.id) \(b.kind) should be on the floor")
                speed += b.vel.len
            }
            XCTAssertLessThan(speed / CGFloat(w.bodies.count), 60, "\(l.id) pile still moving")
        }
    }

    /// Dragging every item to its spot finishes the level.
    func testDraggingEverythingFinishesTheLevel() {
        for l in [TidyLevels.fridge1, TidyLevels.cupboard2, TidyLevels.socks2, TidyLevels.pantry2] {
            let w = TidyWorld(level: l)
            w.simulate(seconds: 5)
            var tries = 0
            while !w.bodies.allSatisfy({ $0.state == .placed }) && tries < 120 {
                tries += 1
                guard let b = w.bodies.first(where: { $0.state == .loose }) else { w.simulate(seconds: 0.3); continue }
                w.touchDown(b.pos.pt)
                guard let h = w.held else { w.simulate(seconds: 0.2); continue }
                let held = w.bodies[h]
                guard let s = w.eligible(for: held).first else { w.touchUp(held.pos.pt); continue }
                // her finger goes below the slot: the item floats above her finger
                let target = w.finger(toHold: held, at: w.slotPos(s).pt)
                w.touchMoved(target)
                w.simulate(seconds: 0.4)
                w.touchUp(target)
                w.simulate(seconds: 0.8)
            }
            XCTAssertTrue(w.bodies.allSatisfy { $0.state == .placed }, l.id)
            w.simulate(seconds: 0.6)
            XCTAssertTrue(w.isDone, l.id)
        }
    }

    func testThrownItemsFallBackToTheFloor() {
        let w = TidyWorld(level: TidyLevels.toys1)
        w.simulate(seconds: 5)
        let b = w.bodies[0]
        w.touchDown(b.pos.pt)
        guard let h = w.held else { return XCTFail("nothing picked up") }
        w.touchMoved(CGPoint(x: 500, y: 60))
        w.simulate(seconds: 0.3)
        w.touchMoved(CGPoint(x: 900, y: 40))
        w.simulate(seconds: 0.05)
        w.touchUp(CGPoint(x: 900, y: 40))
        XCTAssertEqual(w.bodies[h].state, .loose)
        w.simulate(seconds: 4)
        XCTAssertGreaterThan(w.bodies[h].pos.y, 600)
    }

    func testProgressRoundTrip() throws {
        let s = TidyStore.Save(done: ["fridge1", "socks2"], music: false)
        let back = try JSONDecoder().decode(TidyStore.Save.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.done, s.done)
        XCTAssertEqual(back.music, false)
    }

    func testAllSixTidyStickersRegistered() {
        XCTAssertEqual(TidyFind.allCases.count, 6)
        XCTAssertEqual(TidyFind.stickers.count, 6)
        XCTAssertEqual(TidyGame.entry.stickers.count, 6)
        XCTAssertEqual(Set(TidyGame.entry.stickers.map(\.id)), Set(TidyFind.allCases.map(\.rawValue)))
    }

    func testCompletionAwardsFourCoinsAndUnlocksMatchingStickers() {
        let w = TidyWorld(level: TidyLevels.bookshelf1)
        w.simulate(seconds: 4)
        w.placeSome(TidyLevels.bookshelf1.slots.count - 1)
        guard let last = w.bodies.first(where: { $0.state == .loose }),
              let slot = w.eligible(for: last).first else {
            return XCTFail("expected one remaining loose item")
        }
        let coinsBefore = Coins.shared.balance
        let target = w.finger(toHold: last, at: w.slotPos(slot).pt)
        w.touchDown(last.pos.pt)
        XCTAssertEqual(w.held, last.id)
        w.touchMoved(target)
        w.simulate(seconds: 0.5)
        w.touchUp(target)
        w.simulate(seconds: 1.5)

        XCTAssertTrue(w.isDone)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 4)
        XCTAssertTrue(StickerBook.shared.has(game: TidyGame.id, id: TidyFind.firstRoom.rawValue))
        XCTAssertTrue(StickerBook.shared.has(game: TidyGame.id, id: TidyFind.toyMaster.rawValue))
        XCTAssertTrue(StickerBook.shared.has(game: TidyGame.id, id: TidyFind.colorSorter.rawValue))
    }

    func testUnified120ptDropSnap() {
        XCTAssertEqual(TidyWorld.snapRadius, 120)
        let w = TidyWorld(level: TidyLevels.fridge1)
        w.simulate(seconds: 4)
        guard let b = w.bodies.first(where: { $0.kind == .cheese && $0.state == .loose }),
              let slot = w.eligible(for: b).first else {
            return XCTFail("expected cheese and eligible slot")
        }
        // Position body 108pt from its slot (beyond the old 92pt limit, inside unified 120pt) and release immediately.
        w.touchDown(b.pos.pt)
        guard w.held == b.id else { return XCTFail("failed to grab cheese") }
        let sp = w.slotPos(slot)
        b.pos = TVec(sp.x + 108, sp.y)
        w.touchUp(w.finger(toHold: b, at: b.pos.pt))
        XCTAssertEqual(b.state, .snapping)
        XCTAssertEqual(b.slot, slot)
    }

    func testWrongColorAndLockedStackDropSetsHintToOpenSlot() {
        let shelf = TidyWorld(level: TidyLevels.bookshelf1)
        shelf.simulate(seconds: 4)
        guard let redBook = shelf.bodies.first(where: { $0.kind == .book && $0.color == 0 }),
              let blueSlot = TidyLevels.bookshelf1.slots.firstIndex(where: { $0.kind == .book && $0.color == 5 }),
              let redSlot = TidyLevels.bookshelf1.slots.firstIndex(where: { $0.kind == .book && $0.color == 0 }) else {
            return XCTFail("expected red book and blue/red slots")
        }
        // Move far enough from redSlot (>120pt) or test against cupboard locked stack where distance is distinct
        redBook.pos = TVec(140, 260)
        shelf.touchDown(redBook.pos.pt)
        XCTAssertEqual(shelf.held, redBook.id)
        // Place red book near blue slot while outside red slot's snap radius
        redBook.pos = TVec(shelf.slotPos(blueSlot).x + 70, shelf.slotPos(blueSlot).y)
        shelf.touchUp(shelf.finger(toHold: redBook, at: redBook.pos.pt))
        XCTAssertEqual(redBook.state, .loose)
        XCTAssertEqual(shelf.hint?.slot, redSlot)

        let cupboard = TidyWorld(level: TidyLevels.cupboard1)
        cupboard.simulate(seconds: 4)
        let plateSlots = TidyLevels.cupboard1.slots.indices.filter { TidyLevels.cupboard1.slots[$0].kind == .plate }
        let topPlateSlot = plateSlots.min { TidyLevels.cupboard1.slots[$0].pos.y < TidyLevels.cupboard1.slots[$1].pos.y }!
        let bottomPlateSlot = plateSlots.max { TidyLevels.cupboard1.slots[$0].pos.y < TidyLevels.cupboard1.slots[$1].pos.y }!
        let plate = cupboard.bodies.first(where: { $0.kind == .plate })!
        plate.pos = TVec(140, 260)
        cupboard.touchDown(plate.pos.pt)
        XCTAssertEqual(cupboard.held, plate.id)
        // Put plate above the locked top plate slot (>120pt from bottom plate slot, within 120pt of top plate slot).
        plate.pos = TVec(cupboard.slotPos(topPlateSlot).x, cupboard.slotPos(topPlateSlot).y - 95)
        cupboard.touchUp(cupboard.finger(toHold: plate, at: plate.pos.pt))
        XCTAssertEqual(plate.state, .loose)
        XCTAssertEqual(cupboard.hint?.slot, bottomPlateSlot)
    }

    func testShuffledLevelsStayInBoundsAndCompletable() {
        for roomIndex in 0..<TidyLevels.all.count {
            for seed: UInt64 in [1, 42, 999] {
                let level = TidyLevels.shuffled(roomIndex: roomIndex, seed: seed)
                XCTAssertTrue(level.isShuffle)
                XCTAssertEqual(level.scene, TidyLevels.all[roomIndex].scene)
                XCTAssertGreaterThanOrEqual(level.slots.count, 4, level.id)
                XCTAssertLessThanOrEqual(level.slots.count, 16, level.id)

                for s in level.slots {
                    let sz = s.kind.size
                    let w = abs(cos(s.rot)) * sz.width + abs(sin(s.rot)) * sz.height
                    let h = abs(sin(s.rot)) * sz.width + abs(cos(s.rot)) * sz.height
                    XCTAssertGreaterThanOrEqual(s.pos.x - w / 2, 0, "\(level.id) \(s.kind)")
                    XCTAssertLessThanOrEqual(s.pos.x + w / 2, TidyScene.size.width, "\(level.id) \(s.kind)")
                    XCTAssertGreaterThanOrEqual(s.pos.y - h / 2, -4, "\(level.id) \(s.kind)")
                    XCTAssertLessThanOrEqual(s.pos.y + h / 2, TidyScene.size.height + 4, "\(level.id) \(s.kind)")
                }

                // Every shuffled room must be 100% completable without locked stacks or mismatched strict colors.
                let w = TidyWorld(level: level)
                for _ in 0..<level.slots.count { w.placeSome(1) }
                XCTAssertTrue(w.filled.allSatisfy { $0 != nil }, "shuffled room should be completable: \(level.id)")
            }
        }

        // Verify different seeds generate distinct shuffled clutter variations and settle cleanly on screen.
        let a = TidyLevels.shuffled(roomIndex: 0, seed: 11)
        let b = TidyLevels.shuffled(roomIndex: 0, seed: 777)
        let sigA = a.slots.map { "\($0.kind.rawValue)-\($0.color)-\(Int($0.pos.x))-\(Int($0.pos.y))" }
        let sigB = b.slots.map { "\($0.kind.rawValue)-\($0.color)-\(Int($0.pos.x))-\(Int($0.pos.y))" }
        XCTAssertNotEqual(sigA, sigB, "different seeds should vary shuffled clutter")

        let simWorld = TidyWorld(level: a)
        simWorld.size = CGSize(width: 1024, height: 834)
        simWorld.simulate(seconds: 7)
        for body in simWorld.bodies {
            XCTAssertEqual(body.state, .loose)
            XCTAssertGreaterThan(body.pos.x, -5)
            XCTAssertLessThan(body.pos.x, simWorld.size.width + 5)
            XCTAssertLessThan(body.pos.y, simWorld.floorY + 2)
        }
    }

    func testEveryTidySoundResolves() {
        for sfx in TidySFX.allCases {
            XCTAssertNotNil(TidySound.url(for: sfx), "missing audio asset for \(sfx.rawValue)")
        }
    }

    func testTidyTreasureHooksRespondToOwnershipAndEmitExtraStarlight() {
        Coins.shared.resetForTests(balance: 60)
        defer { Coins.shared.resetForTests() }

        XCTAssertEqual(TidyWorld.starBroomTreasureID, "tidy/starBroom")
        XCTAssertEqual(TidyWorld.plushBearTreasureID, "tidy/plushBear")
        XCTAssertFalse(TidyWorld.hasStarBroom)
        XCTAssertFalse(TidyWorld.hasPlushBear)

        func snapOneAndCountSparkles() -> (sparkles: Int, rings: Int, lastPlace: Double) {
            let w = TidyWorld(level: TidyLevels.fridge1)
            w.simulate(seconds: 4)
            guard let pick = w.bodies.first(where: { $0.state == .loose }) else {
                XCTFail("expected loose item")
                return (0, 0, -10)
            }
            w.touchDown(pick.pos.pt)
            guard let h = w.held else {
                XCTFail("expected held item")
                return (0, 0, -10)
            }
            let held = w.bodies[h]
            guard let slot = w.eligible(for: held).first else {
                XCTFail("expected eligible slot")
                return (0, 0, -10)
            }
            let target = w.finger(toHold: held, at: w.slotPos(slot).pt)
            w.touchMoved(target)
            w.simulate(seconds: 0.35)
            w.touchUp(target)
            for _ in 0..<40 where held.state != .placed {
                w.simulate(seconds: 0.03)
            }
            XCTAssertEqual(held.state, .placed)
            let sparkles = w.particles.filter { $0.kind == .sparkle }.count
            return (sparkles, w.rings.count, w.lastPlace)
        }

        let baseline = snapOneAndCountSparkles()
        XCTAssertEqual(baseline.sparkles, 9)
        XCTAssertEqual(baseline.rings, 1)
        XCTAssertGreaterThan(baseline.lastPlace, 0)

        XCTAssertTrue(Coins.shared.buy(TidyWorld.starBroomTreasureID, price: 8))
        XCTAssertTrue(Coins.shared.buy(TidyWorld.plushBearTreasureID, price: 10))
        XCTAssertTrue(TidyWorld.hasStarBroom)
        XCTAssertTrue(TidyWorld.hasPlushBear)

        let upgraded = snapOneAndCountSparkles()
        XCTAssertEqual(upgraded.sparkles, 19)
        XCTAssertEqual(upgraded.rings, 2)
        XCTAssertGreaterThan(upgraded.lastPlace, 0)
    }
}
