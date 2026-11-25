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

    func testAllEightSpaStickersRegistered() {
        XCTAssertEqual(SpaFind.allCases.count, 8)
        XCTAssertEqual(SpaGame.entry.stickers.count, 8)
        XCTAssertEqual(Set(SpaGame.entry.stickers.map(\.id)), Set(SpaFind.allCases.map(\.rawValue)))
    }

    func testBundledSpaAudioFilesExist() {
        for sfx in SpaSFX.allCases {
            XCTAssertNotNil(GameFiles.url(sfx.rawValue, "wav", game: "Spa"), "missing bundled Spa sound \(sfx.rawValue).wav")
        }
    }
}
