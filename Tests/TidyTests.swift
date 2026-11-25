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

    // MARK: - Home Indicator Floor Margin

    func testClassicFloorLiftedAboveHomeIndicator() {
        let w = TidyWorld(level: TidyLevels.toys1)
        w.size = CGSize(width: GameChromeLayout.width, height: GameChromeLayout.height)
        XCTAssertEqual(w.floorY, 772)
        XCTAssertLessThanOrEqual(w.boxRect.maxY, 772)
        w.simulate(seconds: 7)
        for b in w.bodies {
            XCTAssertLessThanOrEqual(b.pos.y, 774, "loose item should remain above iOS Home Indicator zone")
        }
    }

    // MARK: - Unpacking Mode Tests

    func testUnpackingRoomsAndItemQueuesAreValid() {
        XCTAssertEqual(UnpackingRoomID.allCases.count, 6)
        XCTAssertEqual(UnpackingRooms.all.count, 6)
        XCTAssertEqual(Set(UnpackingRooms.all.map(\.id)), Set(UnpackingRoomID.allCases))
        XCTAssertEqual(UnpackingItemKind.newUnpackingItems.count, 18)

        for kind in UnpackingItemKind.allCases {
            XCTAssertGreaterThan(kind.size.width, 14, kind.rawValue)
            XCTAssertGreaterThan(kind.size.height, 14, kind.rawValue)
            XCTAssertFalse(kind.allowedSurfaces.isEmpty, kind.rawValue)
        }

        var usedKinds: Set<UnpackingItemKind> = []
        for room in UnpackingRooms.all {
            XCTAssertGreaterThanOrEqual(room.boxes.count, 2, room.id.rawValue)
            XCTAssertLessThanOrEqual(room.boxes.count, 3, room.id.rawValue)
            XCTAssertLessThanOrEqual(room.floorY, 760, "\(room.id.rawValue) floor must stay clear of Home Indicator")

            let items = room.allItems
            XCTAssertGreaterThanOrEqual(items.count, 10, room.id.rawValue)
            XCTAssertLessThanOrEqual(items.count, 15, room.id.rawValue)
            XCTAssertEqual(Set(items.map(\.id)).count, items.count, "duplicate item IDs in \(room.id.rawValue)")

            for surface in room.surfaces {
                XCTAssertLessThanOrEqual(surface.restY, 760, "\(room.id.rawValue) \(surface.id)")
                XCTAssertLessThanOrEqual(surface.rect.maxY, 760, "\(room.id.rawValue) \(surface.id)")
            }
            for box in room.boxes {
                XCTAssertFalse(box.items.isEmpty, "\(room.id.rawValue) \(box.id)")
                XCTAssertLessThanOrEqual(box.rect.maxY, 760, "\(room.id.rawValue) \(box.id)")
            }

            let surfaceKinds = Set(room.surfaces.map(\.kind))
            for item in items {
                usedKinds.insert(item.kind)
                XCTAssertFalse(
                    item.kind.allowedSurfaces.isDisjoint(with: surfaceKinds),
                    "\(item.kind.rawValue) has no compatible surface in \(room.id.rawValue)"
                )
            }
        }

        for newKind in UnpackingItemKind.newUnpackingItems {
            XCTAssertTrue(usedKinds.contains(newKind), "new Unpacking item \(newKind.rawValue) should appear in at least one room")
        }
    }

    func testUnpackingBoxTapOpensFlapsThenPopsItemsOneByOneAndCollapses() {
        let store = UnpackingStore(loadFromDisk: false)
        let world = UnpackingWorld(roomID: .bedroom, store: store)
        guard let box = world.boxes.first else { return XCTFail("expected at least one box") }

        let initialCount = box.remaining.count
        XCTAssertFalse(box.isOpened)
        XCTAssertEqual(box.openProgress, 0)

        // First tap opens the taped closed box (no item popped yet).
        let firstResult = world.tapBox(box.id)
        XCTAssertNil(firstResult)
        XCTAssertTrue(box.isOpened)
        XCTAssertEqual(box.remaining.count, initialCount)
        world.simulate(seconds: 0.45)
        XCTAssertEqual(box.openProgress, 1, accuracy: 0.02)
        XCTAssertEqual(box.tapePeel, 1, accuracy: 0.02)

        // Subsequent taps pop exactly one item at a time until empty.
        for step in 1...initialCount {
            let popped = world.tapBox(box.id)
            XCTAssertNotNil(popped, "expected item #\(step) from box")
            XCTAssertEqual(box.remaining.count, initialCount - step)
            world.simulate(seconds: 0.45)
            XCTAssertEqual(popped?.phase, .staged)
        }

        // Empty box folds flat and vanishes cleanly.
        XCTAssertTrue(box.isCollapsing)
        world.simulate(seconds: 1.0)
        XCTAssertEqual(box.openProgress, 0, accuracy: 0.02)
        XCTAssertEqual(box.collapseProgress, 1, accuracy: 0.02)
        XCTAssertTrue(box.isGone)
    }

    func testUnpackingFreeFormPlacementAndIncompatibleDropBounce() {
        let store = UnpackingStore(loadFromDisk: false)
        let world = UnpackingWorld(roomID: .koreanKitchen, store: store)
        guard let box = world.boxes.first else { return XCTFail("expected kitchen box") }
        guard let counter = world.room.surfaces.first(where: { $0.kind == .desk }),
              let wall = world.room.surfaces.first(where: { $0.id == "kit-wall" }) else {
            return XCTFail("expected counter and wall surfaces")
        }

        // Open box and pop rice cooker (first item in kit-box-1).
        world.tapBox(box.id)
        guard let riceCooker = world.tapBox(box.id) else { return XCTFail("expected rice cooker") }
        XCTAssertEqual(riceCooker.kind, .riceCooker)
        world.simulate(seconds: 0.4)

        // Dropping heavy rice cooker on the wall gently bounces back (zero fail state!).
        let wallAccepted = world.dropItem(riceCooker.id, at: CGPoint(x: wall.rect.midX, y: wall.rect.midY))
        XCTAssertFalse(wallAccepted)
        XCTAssertEqual(riceCooker.phase, .bouncingBack)
        XCTAssertNotNil(world.hintSurfaceID)
        world.simulate(seconds: 0.5)
        XCTAssertEqual(riceCooker.phase, .staged)

        // Free-form horizontal placement anywhere along the counter settles at exact chosen X, grounded on restY!
        let customLeftX = counter.rect.minX + 95
        let placedLeft = world.dropItem(riceCooker.id, at: CGPoint(x: customLeftX, y: counter.rect.midY))
        XCTAssertTrue(placedLeft)
        XCTAssertEqual(riceCooker.phase, .placed)
        XCTAssertEqual(riceCooker.surfaceID, counter.id)
        XCTAssertEqual(riceCooker.pos.x, customLeftX, accuracy: 1.0)
        XCTAssertEqual(riceCooker.pos.y, counter.restY - riceCooker.size.height * 0.5, accuracy: 1.0)

        // Already-placed item can be picked up and moved to another spot on the same horizontal surface!
        let customRightX = counter.rect.maxX - 95
        let movedRight = world.dropItem(riceCooker.id, at: CGPoint(x: customRightX, y: counter.rect.midY))
        XCTAssertTrue(movedRight)
        XCTAssertEqual(riceCooker.pos.x, customRightX, accuracy: 1.0)

        // Slippers belong on floor only — verify in bedroom.
        let bedroom = UnpackingWorld(roomID: .bedroom, store: UnpackingStore(loadFromDisk: false))
        let bedBox = bedroom.boxes[0]
        bedroom.tapBox(bedBox.id)
        var slippers: UnpackingItemState?
        for _ in 0..<bedBox.spec.items.count {
            let item = bedroom.tapBox(bedBox.id)
            if item?.kind == .slippers { slippers = item }
        }
        guard let slip = slippers,
              let shelf = bedroom.room.surfaces.first(where: { $0.kind == .shelf }),
              let floor = bedroom.room.surfaces.first(where: { $0.kind == .floor }) else {
            return XCTFail("expected slippers, shelf, and floor")
        }
        bedroom.simulate(seconds: 0.4)
        XCTAssertFalse(bedroom.dropItem(slip.id, at: CGPoint(x: shelf.rect.midX, y: shelf.rect.midY)))
        bedroom.simulate(seconds: 0.5)
        XCTAssertTrue(bedroom.dropItem(slip.id, at: CGPoint(x: floor.rect.midX + 60, y: floor.rect.midY)))
        XCTAssertEqual(slip.surfaceID, floor.id)
        XCTAssertEqual(slip.pos.y, floor.restY - slip.size.height * 0.5, accuracy: 1.0)
    }

    func testUnpackingInteractivePlacedItemsAndStarBroomHook() {
        Coins.shared.resetForTests(balance: 40)
        defer { Coins.shared.resetForTests() }

        let store = UnpackingStore(loadFromDisk: false)
        let world = UnpackingWorld(roomID: .bedroom, store: store)
        let box2 = world.boxes[1]
        world.tapBox(box2.id)
        guard let lamp = world.tapBox(box2.id),
              let desk = world.room.surfaces.first(where: { $0.kind == .desk }) else {
            return XCTFail("expected desk lamp and desk")
        }
        XCTAssertEqual(lamp.kind, .deskLamp)
        world.simulate(seconds: 0.4)

        XCTAssertTrue(world.dropItem(lamp.id, at: CGPoint(x: desk.rect.midX, y: desk.rect.midY)))
        XCTAssertTrue(lamp.isLit, "desk lamp turns on with cozy glow when placed")
        let baseRings = world.rings.count

        // Quick tap on placed desk lamp toggles light on/off.
        world.touchDown(lamp.pos)
        world.touchUp(lamp.pos)
        XCTAssertFalse(lamp.isLit)
        world.touchDown(lamp.pos)
        world.touchUp(lamp.pos)
        XCTAssertTrue(lamp.isLit)

        // Star Broom treasure adds extra golden starlight ring on placement in Unpacking too.
        XCTAssertTrue(Coins.shared.buy(TidyWorld.starBroomTreasureID, price: 8))
        guard let doll = world.tapBox(box2.id) else { return XCTFail("expected hanbok doll") }
        world.simulate(seconds: 0.4)
        let ringsBefore = world.rings.count
        XCTAssertTrue(world.dropItem(doll.id, at: CGPoint(x: desk.rect.minX + 80, y: desk.rect.midY)))
        XCTAssertEqual(world.rings.count, ringsBefore + 2)
        XCTAssertEqual(baseRings, 1)
    }

    func testUnpackingRoomCompletionAwardsFiveCoinsAndPersistsCustomLayout() throws {
        Coins.shared.resetForTests(balance: 10)
        defer { Coins.shared.resetForTests() }

        let store = UnpackingStore(loadFromDisk: false)
        let world = UnpackingWorld(roomID: .bedroom, store: store)

        var customPositions: [String: CGPoint] = [:]
        var offsetStep: CGFloat = 0

        for box in world.boxes {
            world.tapBox(box.id) // open box
            let count = box.remaining.count
            for _ in 0..<count {
                guard let item = world.tapBox(box.id) else {
                    return XCTFail("expected item from \(box.id)")
                }
                world.simulate(seconds: 0.35)
                guard let surface = world.room.surfaces.first(where: { item.kind.allowedSurfaces.contains($0.kind) }) else {
                    return XCTFail("no compatible surface for \(item.kind.rawValue)")
                }
                let rawX = surface.rect.minX + 60 + offsetStep.truncatingRemainder(dividingBy: max(40, surface.rect.width - 120))
                offsetStep += 47
                let dropPt = CGPoint(x: rawX, y: surface.rect.midY)
                XCTAssertTrue(world.dropItem(item.id, at: dropPt), "failed placing \(item.kind.rawValue)")
                customPositions[item.id] = item.pos
            }
        }

        world.simulate(seconds: 1.2)

        XCTAssertTrue(world.allBoxesEmpty)
        XCTAssertTrue(world.boxes.allSatisfy(\.isGone))
        XCTAssertTrue(world.isDone)
        XCTAssertTrue(world.complete)
        XCTAssertEqual(Coins.shared.balance, 15, "completing an Unpacking room awards +5 Play Coins")
        XCTAssertTrue(StickerBook.shared.has(game: TidyGame.id, id: TidyFind.firstRoom.rawValue))
        XCTAssertTrue(store.isCompleted(.bedroom))

        for light in world.items where light.kind.isLighting {
            XCTAssertTrue(light.isLit, "warm lighting should turn on upon room completion")
        }

        // JSON round-trip of UnpackingSave preserves exact custom item layout!
        let encoded = try JSONEncoder().encode(store.data)
        let decoded = try JSONDecoder().decode(UnpackingSave.self, from: encoded)
        XCTAssertEqual(decoded, store.data)

        // Re-opening the completed room restores every custom position and does not double-award coins.
        let reloadedStore = UnpackingStore(loadFromDisk: false)
        reloadedStore.data = decoded
        let reloaded = UnpackingWorld(roomID: .bedroom, store: reloadedStore)
        XCTAssertTrue(reloaded.isDone)
        XCTAssertTrue(reloaded.boxes.allSatisfy(\.isGone))
        XCTAssertEqual(reloaded.items.count, customPositions.count)
        for item in reloaded.items {
            guard let expected = customPositions[item.id] else {
                return XCTFail("missing custom position for \(item.id)")
            }
            XCTAssertEqual(item.phase, .placed)
            XCTAssertEqual(item.pos.x, expected.x, accuracy: 0.5)
            XCTAssertEqual(item.pos.y, expected.y, accuracy: 0.5)
        }
        reloaded.simulate(seconds: 0.5)
        XCTAssertEqual(Coins.shared.balance, 15, "re-opening a saved completed room must not double-award coins")
    }
}
