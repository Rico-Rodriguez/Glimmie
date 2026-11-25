import XCTest
@testable import Glimmie

final class SpaTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Coins.shared.resetForTests()
        StickerBook.shared.demo = true
    }

    private func fresh() -> SpaSim {
        let sim = SpaSim(look: .starter)
        sim.quiet = true
        return sim
    }

    private func run(_ sim: SpaSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) {
            sim.step(dt: 1.0 / 60)
        }
    }

    func testFaucetFillsTheTubAndPlugDrainsIt() {
        let sim = fresh()
        XCTAssertEqual(sim.vol, 0)
        sim.toggleTap()
        run(sim, seconds: 5)
        XCTAssertGreaterThan(sim.vol, 50)
        run(sim, seconds: 16)
        XCTAssertEqual(sim.vol, SGeo.maxDepth, accuracy: 0.5)
        sim.togglePlug()
        XCTAssertFalse(sim.tapOn)
        run(sim, seconds: 25)
        XCTAssertEqual(sim.vol, 0)
    }

    func testWavesConserveWaterLevelAndSettle() {
        let sim = fresh()
        sim.vol = 120
        sim.disturb(520, 2600, width: 20)
        run(sim, seconds: 0.5)
        XCTAssertGreaterThan(sim.h.map(abs).max() ?? 0, 0.5)
        let mean = sim.h.reduce(0, +) / CGFloat(sim.h.count)
        XCTAssertEqual(mean, 0, accuracy: 0.01)
        run(sim, seconds: 18)
        XCTAssertLessThan(sim.h.map(abs).max() ?? 0, 2)
    }

    func testBubbleBathFoamsWhenChurnedAndSwished() {
        let sim = fresh()
        sim.vol = 130
        sim.soap = 50
        run(sim, seconds: 2)
        XCTAssertLessThan(sim.totalFoam, 0.5)
        sim.tapOn = true
        run(sim, seconds: 3.5)
        XCTAssertGreaterThan(sim.totalFoam, 3)

        let boatID = sim.spawnThing(.toy(.boat), at: CGPoint(x: 620, y: sim.level), held: false)
        sim.handBegan(CGPoint(x: 540, y: sim.level + 12))
        sim.handMoved(CGPoint(x: 590, y: sim.level + 12), dt: 1.0 / 60)
        sim.handEnded(CGPoint(x: 590, y: sim.level + 12), tap: false)
        let idx = sim.thingIndex(boatID)!
        XCTAssertGreaterThan(sim.things[idx].v.dx, 0)
    }

    func testBathBombFizzesColorsWaterAndUnlocksRainbowSticker() {
        let sim = fresh()
        sim.vol = 130
        _ = sim.spawnThing(.bomb(.rainbow), at: CGPoint(x: 600, y: 360), held: false)
        run(sim, seconds: 15)
        XCTAssertTrue(sim.things.filter { $0.isBomb }.isEmpty)
        XCTAssertGreaterThan(sim.tintA.max() ?? 0, 0.1)
        XCTAssertTrue(sim.unlockedFinds.contains(.rainbowBath))
        XCTAssertTrue(StickerBook.shared.has(game: SpaSim.gameID, id: SpaFind.rainbowBath.rawValue))
    }

    func testFoamPuffsBuildAwayFromEyesSneezeWobblesAndShowerRinses() throws {
        let sim = fresh()
        // Trying to place foam directly on her eye clamps it safely onto her crown/hairline.
        _ = sim.addFoamPuff(at: SGeo.eyes[0], tint: FoamTint.cloud.color)
        let clamped = try XCTUnwrap(sim.foamPuffs.first)
        XCTAssertGreaterThan(hypot(clamped.anchor.x - SGeo.eyes[0].x, clamped.anchor.y - SGeo.eyes[0].y), 55)

        // 1-tap foam style builds a fluffy bubble crown and unlocks bubbleCrown sticker.
        sim.applyNextFoamStyle(tint: .berry)
        XCTAssertGreaterThanOrEqual(sim.foamPuffs.count, 5)
        XCTAssertTrue(sim.unlockedFinds.contains(.bubbleCrown))

        // Always-active nose tap triggers ACHOO! sneeze, wobbles puffs, and unlocks sneezeGiggle.
        let noseScreen = SGeo.fromDoll(SGeo.nose)
        sim.handBegan(noseScreen)
        sim.handEnded(noseScreen, tap: true)
        XCTAssertEqual(sim.spaExpression(), .sneeze)
        XCTAssertTrue(sim.unlockedFinds.contains(.sneezeGiggle))
        XCTAssertTrue(sim.foamPuffs.contains { hypot($0.vel.dx, $0.vel.dy) > 100 })
        XCTAssertFalse(sim.bubbles.isEmpty)

        // Quick shower rinses foam puffs cleanly away.
        sim.triggerQuickShower()
        run(sim, seconds: 1.5)
        XCTAssertTrue(sim.foamPuffs.isEmpty)
    }

    func testFaceMaskTowelDoesNotEraseButShowerDoesRinse() {
        let sim = fresh()
        sim.applyFullMask(.strawberry)
        let fullMask = sim.maskCoverage
        XCTAssertGreaterThan(fullMask, 0.2)
        XCTAssertTrue(sim.unlockedFinds.contains(.strawberryMask))

        // Add water beads and dry with Fluffy Pink Towel (both 1-tap and drag).
        for k in 0..<6 {
            sim.addBead(CGPoint(x: 250 + CGFloat(k) * 14, y: 310))
        }
        let target = SGeo.fromDoll(CGPoint(x: 300, y: 310))
        sim.pickUp(.towel, finger: target, lifted: target)
        for k in 0..<30 {
            sim.carry(finger: target, lifted: CGPoint(x: target.x + (k.isMultiple(of: 2) ? 28 : -28), y: target.y))
            sim.step(dt: 1.0 / 60)
        }
        sim.release()
        sim.applyCozyTowel()

        XCTAssertTrue(sim.beads.isEmpty)
        XCTAssertTrue(sim.cozyActive)
        XCTAssertTrue(sim.unlockedFinds.contains(.cozyWrap))
        XCTAssertEqual(sim.maskCoverage, fullMask, accuracy: 0.001, "towel must never erase her face mask")

        // Sparkling Hand Shower cleanly rinses her face mask off.
        sim.triggerQuickShower()
        run(sim, seconds: 1.5)
        XCTAssertLessThan(sim.maskCoverage, fullMask * 0.15)
    }

    func testPairedCucumbersToggleCleanlyWithoutFloorLitter() {
        let sim = fresh()
        XCTAssertFalse(sim.cucumbersOn)
        let beforeThings = sim.things.count

        sim.toggleCucumbers()
        XCTAssertTrue(sim.cucumbersOn)
        XCTAssertEqual(sim.spaExpression(), .zen)
        XCTAssertEqual(sim.expression(), .blink)
        XCTAssertTrue(sim.unlockedFinds.contains(.cucumberZen))

        // Tapping either cucumber slice pops BOTH off cleanly with zero loose cucumbers on the floor.
        let leftEye = SGeo.fromDoll(SGeo.eyes[0])
        sim.handBegan(leftEye)
        sim.handEnded(leftEye, tap: true)
        XCTAssertFalse(sim.cucumbersOn)
        XCTAssertEqual(sim.things.count, beforeThings, "removing cucumbers must never drop debris into the scene")
    }

    func testBathToysFloatAndWhaleSpoutsFountain() throws {
        let sim = fresh()
        sim.vol = 130
        let duckID = sim.spawnThing(.toy(.duck), at: CGPoint(x: 560, y: 320), held: false)
        let whaleID = sim.spawnThing(.toy(.whale), at: CGPoint(x: 700, y: 320), held: false)
        run(sim, seconds: 6)

        let duckIdx = try XCTUnwrap(sim.thingIndex(duckID))
        let duck = sim.things[duckIdx]
        let surf = sim.surfaceY(duck.p.x)
        XCTAssertLessThan(duck.p.y - duck.half.height, surf)
        XCTAssertGreaterThan(duck.p.y + duck.half.height, surf)

        let whaleIdx = try XCTUnwrap(sim.thingIndex(whaleID))
        let dropsBefore = sim.drops.count
        sim.tapThing(whaleIdx)
        XCTAssertGreaterThan(sim.drops.count, dropsBefore + 20)
        XCTAssertTrue(sim.unlockedFinds.contains(.whaleFountain))
    }

    func testBubbleWandAlwaysBlowsAndFiveStarBubblesSpawnRainbowBomb() throws {
        let sim = fresh()
        sim.vol = 130
        // Dragging the wand in midair immediately blows bubbles without needing a hidden dip.
        let start = CGPoint(x: 540, y: 320)
        sim.pickUp(.wand, finger: start, lifted: start)
        for step in 1...30 {
            let pt = CGPoint(x: start.x + CGFloat(step) * 8, y: start.y - 10)
            sim.carry(finger: pt, lifted: pt)
            sim.step(dt: 1.0 / 60)
        }
        sim.release()
        XCTAssertFalse(sim.bubbles.isEmpty)

        // Popping 5 star bubbles via touch spawns a bonus rainbow bath bomb and unlocks starPopper.
        sim.bubbles.removeAll()
        for count in 1...SpaSim.starGoal {
            let pt = CGPoint(x: 520 + CGFloat(count) * 30, y: 300)
            sim.spawnBubble(at: pt, v: .zero, r: 34, star: true)
            sim.handBegan(pt)
            sim.handEnded(pt, tap: true)
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertTrue(sim.things.contains {
            if case .bomb(.rainbow) = $0.kind { return true }
            return false
        })
        XCTAssertTrue(sim.unlockedFinds.contains(.starPopper))
    }

    func testMirrorSteamsWithinFourSecondsAndFingerWipesClean() {
        let sim = fresh()
        sim.vol = 130
        sim.warm = 1
        run(sim, seconds: 4)
        let avgFog = sim.fog.reduce(0, +) / CGFloat(sim.fog.count)
        XCTAssertGreaterThan(avgFog, 0.7, "mirror should steam up clearly within 4 seconds of warm water")

        let c = CGPoint(x: SGeo.mirror.midX, y: SGeo.mirror.midY)
        sim.handBegan(c)
        XCTAssertEqual(sim.hand, .wipe)
        sim.handMoved(CGPoint(x: c.x + 48, y: c.y), dt: 1.0 / 60)
        sim.handEnded(CGPoint(x: c.x + 48, y: c.y), tap: false)
        XCTAssertLessThan(sim.fog.min() ?? 1, 0.1)
    }

    func testSpaWishCompletionAwardsThreeCoinsAndCycles() {
        let sim = fresh()
        sim.vol = 130
        sim.activeWish = .bathBomb
        let coinsBefore = Coins.shared.balance

        sim.dropIn(.bomb(.ocean))

        XCTAssertEqual(sim.wishCompletedCount, 1)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)
        XCTAssertNotEqual(sim.activeWish, .bathBomb)
    }

    func testDryTubBathBombDoesNotFizzOrFulfillWishUntilWaterFilled() {
        let sim = fresh()
        sim.vol = 0
        sim.activeWish = .bathBomb
        let coinsBefore = Coins.shared.balance

        sim.dropIn(.bomb(.rainbow))
        run(sim, seconds: 2.5)
        XCTAssertEqual(sim.wishCompletedCount, 0)
        XCTAssertEqual(Coins.shared.balance, coinsBefore)
        XCTAssertFalse(sim.unlockedFinds.contains(.rainbowBath))
        XCTAssertEqual(sim.things.filter { $0.isBomb }.count, 1)

        // Shallow puddle below 25% still keeps bomb dry and waiting.
        sim.vol = SGeo.maxDepth * 0.2
        run(sim, seconds: 1.5)
        XCTAssertEqual(sim.wishCompletedCount, 0)
        XCTAssertEqual(Coins.shared.balance, coinsBefore)

        // Filling tub past 25% wakes the waiting bath bomb to fizz and fulfill the wish.
        sim.vol = SGeo.maxDepth * 0.6
        run(sim, seconds: 2.0)
        XCTAssertEqual(sim.wishCompletedCount, 1)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)
        XCTAssertTrue(sim.unlockedFinds.contains(.rainbowBath))
    }

    func testMirrorFingerDrawingPersistsUntilWipedWithTowel() {
        let sim = fresh()
        sim.vol = 130
        sim.warm = 1
        run(sim, seconds: 4)

        let c = CGPoint(x: SGeo.mirror.midX, y: SGeo.mirror.midY)
        sim.handBegan(c)
        sim.handMoved(CGPoint(x: c.x + 36, y: c.y), dt: 1.0 / 60)
        sim.handEnded(CGPoint(x: c.x + 36, y: c.y), tap: false)

        let centerIdx = (SGeo.fogRows / 2) * SGeo.fogCols + (SGeo.fogCols / 2)
        let cornerIdx = 2 * SGeo.fogCols + 2
        XCTAssertLessThan(sim.fog[centerIdx], 0.05)
        XCTAssertTrue(sim.fogCleared[centerIdx])

        // Warm steam keeps surrounding mirror foggy while finger drawing stays crisp.
        run(sim, seconds: 6)
        XCTAssertLessThan(sim.fog[centerIdx], 0.05, "finger drawing must not auto-refog after a few seconds")

        // Draining the bath preserves both fog and finger drawing.
        sim.vol = 0
        sim.warm = 0
        run(sim, seconds: 4)
        XCTAssertGreaterThan(sim.fog[cornerIdx], 0.6)

        // Wiping across the mirror with the fluffy towel clears fog and resets drawing masks.
        sim.pickUp(.towel, finger: c, lifted: c)
        for k in 0..<12 {
            let pt = CGPoint(x: c.x + CGFloat(k - 6) * 8, y: c.y)
            sim.carry(finger: pt, lifted: pt)
            sim.step(dt: 1.0 / 60)
        }
        sim.release()
        XCTAssertLessThan(sim.fog[centerIdx], 0.05)
        XCTAssertFalse(sim.fogCleared[centerIdx])
    }

    func testSheepHornTowelHatToggleTintCycleAndCozyFulfillment() {
        let sim = fresh()
        sim.vol = 130
        sim.activeWish = .cozyTowel
        let coinsBefore = Coins.shared.balance

        sim.toggleSheepTowel()
        XCTAssertTrue(sim.sheepTowelOn)
        XCTAssertEqual(sim.sheepTowelTint, .cloud)
        XCTAssertTrue(sim.cozyActive)
        XCTAssertTrue(sim.unlockedFinds.contains(.cozyWrap))
        XCTAssertEqual(sim.wishCompletedCount, 1)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)

        // Tapping a rolled sheep-horn bun cycles pastel terry towel tints.
        let leftBun = SGeo.fromDoll(CGPoint(x: 156, y: 214))
        sim.handBegan(leftBun)
        sim.handEnded(leftBun, tap: true)
        XCTAssertEqual(sim.sheepTowelTint, .berry)

        // Toggling again pops it off cleanly.
        sim.toggleSheepTowel()
        XCTAssertFalse(sim.sheepTowelOn)
    }

    func testSpaSaveRoundTripAndRestore() throws {
        let sim = fresh()
        sim.vol = 122
        sim.warm = 0.85
        sim.soap = 44
        sim.cucumbersOn = true
        sim.putSheepTowelOn(tint: .lavender)
        sim.applyFullMask(.honey)
        sim.selectedCategory = .pamper
        sim.activeWish = .whaleToy
        sim.wishCompletedCount = 4
        _ = sim.spawnThing(.toy(.duck), at: CGPoint(x: 540, y: 520), held: false)
        _ = sim.spawnThing(.toy(.whale), at: CGPoint(x: 680, y: 520), held: false)

        let saved = sim.makeSave()
        let encoded = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(SpaSave.self, from: encoded)
        XCTAssertEqual(decoded, saved)

        let restored = SpaSim(look: .starter, save: decoded)
        XCTAssertEqual(restored.vol, 122, accuracy: 0.5)
        XCTAssertEqual(restored.soap, 44, accuracy: 0.5)
        XCTAssertTrue(restored.cucumbersOn)
        XCTAssertTrue(restored.sheepTowelOn)
        XCTAssertEqual(restored.sheepTowelTint, .lavender)
        XCTAssertEqual(restored.selectedCategory, .pamper)
        XCTAssertEqual(restored.activeWish, .whaleToy)
        XCTAssertEqual(restored.wishCompletedCount, 4)
        XCTAssertGreaterThan(restored.maskCoverage, 0.2)
        XCTAssertEqual(restored.things.filter { !$0.isBomb }.count, 2)
    }

    func testAllEightSpaStickersRegistered() {
        XCTAssertEqual(SpaFind.allCases.count, 8)
        XCTAssertEqual(SpaGame.entry.stickers.count, 8)
        XCTAssertEqual(Set(SpaGame.entry.stickers.map(\.id)), Set(SpaFind.allCases.map(\.rawValue)))
    }

    func testBundledSpaAudioFilesExist() {
        for sfx in SpaSFX.allCases {
            let url = GameFiles.url(sfx.rawValue, "caf", game: "Spa")
                ?? GameFiles.url(sfx.rawValue, "wav", game: "Spa")
            XCTAssertNotNil(url, "missing bundled Spa sound \(sfx.rawValue)")
        }
    }

    func testYuzuBombAndGoldenDuckTreasureUnlocks() throws {
        XCTAssertEqual(BombKind.yuzu.treasure, "spa/yuzuBomb")
        XCTAssertEqual(ToyKind.goldenDuck.treasure, "spa/goldenDuck")
        XCTAssertFalse(BombKind.available.contains(.yuzu))
        XCTAssertFalse(ToyKind.available.contains(.goldenDuck))

        Coins.shared.resetForTests(balance: 60)
        XCTAssertTrue(Coins.shared.buy("spa/yuzuBomb", price: 12))
        XCTAssertTrue(Coins.shared.buy("spa/goldenDuck", price: 15))
        XCTAssertTrue(BombKind.available.contains(.yuzu))
        XCTAssertTrue(ToyKind.available.contains(.goldenDuck))

        let sim = fresh()
        sim.vol = 130
        _ = sim.spawnThing(.bomb(.yuzu), at: CGPoint(x: 600, y: 360), held: false)
        run(sim, seconds: 4)
        XCTAssertGreaterThan(sim.yuzuCitrus, 0.5, "yuzu bath bomb blooms golden citrus shimmer and slices")
        XCTAssertFalse(sim.glitter.isEmpty)

        let goldID = sim.spawnThing(.toy(.goldenDuck), at: CGPoint(x: 560, y: 420), held: false)
        let idx = try XCTUnwrap(sim.thingIndex(goldID))
        sim.tapThing(idx)
        XCTAssertLessThan(sim.things[idx].v.dy, 0)

        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(SpaSave.self, from: data)
        XCTAssertTrue(decoded.toys.contains { $0.kind == .goldenDuck })
    }
}
