import XCTest
@testable import Glimmie

final class GardenTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Coins.shared.resetForTests()
        StickerBook.shared.demo = true
    }

    private func freshSim() -> GardenSim {
        let sim = GardenSim(save: nil)
        sim.demo = true
        sim.weeds = []
        sim.butterflies = []
        return sim
    }

    private func run(_ sim: GardenSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { sim.step(dt: 1.0 / 60) }
    }

    // MARK: Zero-Friction Planting

    func testZeroFrictionPlantingByDragAndTap() {
        let sim = freshSim()
        for i in sim.plots.indices { sim.plots[i].plant = nil }

        // Dragging and shaking a seed packet plants into an empty plot without any shovel hole.
        sim.pickUp(.seeds(.daisy), at: CGPoint(x: GGeo.plotX[1], y: 400))
        run(sim, seconds: 2.2)
        XCTAssertEqual(sim.plots[1].plant?.kind, .daisy)
        XCTAssertGreaterThan(sim.plots[1].plant?.growth ?? 0, 0.05)
        sim.release(home: CGPoint(x: 559, y: GGeo.dockY))

        // Dropping a seed packet directly onto an empty plot plants immediately.
        sim.pickUp(.seeds(.tulip), at: CGPoint(x: GGeo.plotX[3], y: GGeo.soilY - 12))
        sim.release(home: CGPoint(x: 559, y: GGeo.dockY))
        XCTAssertEqual(sim.plots[3].plant?.kind, .tulip)

        // Tapping seeds launches flying seed arcs into distinct nearest empty plots.
        let pA = sim.tossSeed(.sunflower, from: CGPoint(x: GGeo.plotX[0], y: GGeo.trayY))
        let pB = sim.tossSeed(.carrot, from: CGPoint(x: GGeo.plotX[0], y: GGeo.trayY))
        XCTAssertNotNil(pA)
        XCTAssertNotNil(pB)
        XCTAssertNotEqual(pA, pB)
        run(sim, seconds: 0.6)
        XCTAssertEqual(sim.plots[pA!].plant?.kind, .sunflower)
        XCTAssertEqual(sim.plots[pB!].plant?.kind, .carrot)
    }

    func testSowingAcrossBedKeepsExistingCropsAndStartsEmptyPlots() {
        let sim = freshSim()
        let original = sim.plots[0].plant
        sim.sowRow(.lavender, from: CGPoint(x: 80, y: GGeo.soilY), to: CGPoint(x: 800, y: GGeo.soilY))
        XCTAssertEqual(sim.plots[0].plant, original)
        for i in [1, 3, 5] {
            XCTAssertEqual(sim.plots[i].plant?.kind, .lavender)
            XCTAssertGreaterThan(sim.wetAt(GGeo.plotX[i]), 0.1)
        }
    }

    // MARK: Fast Growth, Watering & Thirsty Droop

    func testFourSecondWateredGrowthAndThirstyDroop() {
        let sim = freshSim()
        sim.plots[5].plant = Plant(kind: .tulip, growth: 0.08)
        for i in 0..<GGeo.columns { sim.wet[i] = 0 }

        // Dry soil halts growth and triggers thirsty droop cue.
        run(sim, seconds: 2.5)
        XCTAssertEqual(sim.plots[5].plant?.growth ?? 0, 0.08, accuracy: 0.001)
        XCTAssertGreaterThan(sim.plots[5].dry, 1.5)

        // Watering darkens the soil and grows briskly to full bloom in ~4 seconds.
        for i in 0..<GGeo.columns { sim.wet[i] = 0.9 }
        run(sim, seconds: 4.2)
        XCTAssertEqual(sim.plots[5].plant?.growth ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(sim.plots[5].plant?.left, PlantKind.tulip.crop)
        XCTAssertEqual(sim.plots[5].dry, 0, accuracy: 0.001)
    }

    func testWateringCanSoaksSoilAndRainWetsBed() {
        let sim = freshSim()
        for i in 0..<GGeo.columns { sim.wet[i] = 0 }
        sim.pickUp(.can, at: CGPoint(x: 520, y: 360))
        run(sim, seconds: 2.5)
        XCTAssertGreaterThan(sim.flow, 0.5)
        XCTAssertGreaterThan(sim.wet.max() ?? 0, 0.25)
        sim.release(home: CGPoint(x: 465, y: GGeo.dockY))

        for i in 0..<GGeo.columns { sim.wet[i] = 0 }
        sim.setWeather(.rain)
        run(sim, seconds: 5)
        let avg = sim.wet.reduce(0, +) / CGFloat(GGeo.columns)
        XCTAssertGreaterThan(avg, 0.1)
    }

    // MARK: Fun Shovel Job & Buried Surprises

    func testShovelPopsWeedsUprootsPlantAndUnearthsSurprises() {
        let sim = freshSim()
        // Pop weed in one scoop
        sim.weeds = [GWeed(x: 310, growth: 1, seed: 2)]
        sim.pickUp(.shovel, at: CGPoint(x: 290, y: GGeo.soilY - 8))
        sim.carry(to: CGPoint(x: 325, y: GGeo.soilY + 6))
        run(sim, seconds: 0.35)
        XCTAssertTrue(sim.weeds.isEmpty)
        sim.release(home: CGPoint(x: 371, y: GGeo.dockY))

        // Cleanly uproot an unwanted plant in a single decisive manual scoop
        sim.plots[2].plant = Plant(kind: .daisy, growth: 0.5)
        let px = GGeo.plotX[2]
        sim.pickUp(.shovel, at: CGPoint(x: px - 12, y: GGeo.soilY + 8))
        for k in 0..<25 {
            sim.carry(to: CGPoint(x: px - 12 + CGFloat(k) * 1.4, y: GGeo.soilY + 12))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertNil(sim.plots[2].plant)
        sim.release(home: CGPoint(x: 371, y: GGeo.dockY))

        // Unearth all 4 buried surprises deterministically
        sim.plots[1].state = .empty(surprise: .coins)
        sim.plots[1].surpriseReady = true
        let coinsBefore = Coins.shared.balance
        XCTAssertEqual(sim.unearthSurprise(plot: 1), .coins)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 2)

        sim.plots[3].state = .empty(surprise: .worm)
        sim.plots[3].surpriseReady = true
        XCTAssertEqual(sim.unearthSurprise(plot: 3), .worm)
        XCTAssertGreaterThan(sim.worm.peekUntil, sim.time)

        sim.plots[4].state = .empty(surprise: .ladybug)
        sim.plots[4].surpriseReady = true
        sim.ladybug.flying = false
        XCTAssertEqual(sim.unearthSurprise(plot: 4), .ladybug)
        XCTAssertTrue(sim.ladybug.flying)

        sim.plots[5].state = .empty(surprise: .mysteryBulb)
        sim.plots[5].surpriseReady = true
        XCTAssertEqual(sim.unearthSurprise(plot: 5), .mysteryBulb)
        XCTAssertTrue(sim.plots[5].plant?.isSpecial ?? false)
    }

    func testShovelClearsWeedFirstWithoutUprootingNearbyPlant() {
        let sim = freshSim()
        let px = GGeo.plotX[2]
        sim.plots[2].plant = Plant(kind: .sunflower, growth: 1, left: 1, variant: 0)
        sim.weeds = [GWeed(x: px + 34, growth: 1, seed: 3)]

        sim.pickUp(.shovel, at: CGPoint(x: px + 44, y: GGeo.soilY + 6))
        for k in 0..<18 {
            sim.carry(to: CGPoint(x: px + 44 - CGFloat(k) * 2.5, y: GGeo.soilY + 8))
            sim.step(dt: 1.0 / 60)
        }
        sim.release(home: CGPoint(x: 371, y: GGeo.dockY))

        XCTAssertTrue(sim.weeds.isEmpty, "shovel should clear nearby weed first")
        XCTAssertEqual(sim.plots[2].plant?.kind, .sunflower, "clearing weed must not accidentally uproot neighboring plant")

        // Casual off-center sweep past the stem does not uproot the plant either.
        run(sim, seconds: 0.7)
        sim.pickUp(.shovel, at: CGPoint(x: px + 32, y: GGeo.soilY + 8))
        for k in 0..<20 {
            sim.carry(to: CGPoint(x: px + 32 + CGFloat(k) * 0.8, y: GGeo.soilY + 10))
            sim.step(dt: 1.0 / 60)
        }
        sim.release(home: CGPoint(x: 371, y: GGeo.dockY))
        XCTAssertEqual(sim.plots[2].plant?.kind, .sunflower)
    }

    // MARK: Per-Crop Harvest & Live Bouquet Vase

    func testCarrotPullHarvest() {
        let sim = freshSim()
        sim.plots[1].plant = Plant(kind: .carrot, growth: 1, left: 1, variant: 0)
        let x = GGeo.plotX[1]
        let base = sim.surface(x)
        sim.handBegan(CGPoint(x: x, y: base - 24))
        for k in 1...16 {
            sim.handMoved(CGPoint(x: x, y: base - 24 - CGFloat(k) * 6))
        }
        sim.handEnded(CGPoint(x: x, y: base - 120), tap: false)
        XCTAssertNil(sim.plots[1].plant)
        XCTAssertEqual(sim.basket.last, "carrot:0")
    }

    func testSwipeAndTapPluckBerriesAndTomatoesOncePerStroke() {
        let sim = freshSim()
        sim.decor = []
        sim.plots[1].plant = Plant(kind: .tomato, growth: 1, left: 4)
        sim.plots[2].plant = Plant(kind: .strawberry, growth: 1, left: 3)
        let start = CGPoint(x: GGeo.plotX[1] - 50, y: GGeo.soilY - 38)
        let end = CGPoint(x: GGeo.plotX[2] + 50, y: start.y)
        sim.handBegan(start)
        sim.handMoved(end)
        sim.handMoved(start)
        sim.handEnded(start, tap: false)
        XCTAssertEqual(sim.basket.count, 2)
        XCTAssertEqual(sim.plots[1].plant?.left, 3)
        XCTAssertEqual(sim.plots[2].plant?.left, 2)
    }

    func testGiantPrizePumpkinPuffAndHarvest() {
        let sim = freshSim()
        sim.plots[3].plant = Plant(kind: .pumpkin, growth: 1, left: 1, variant: 0, giant: false)
        let x = GGeo.plotX[3]
        // Watering the ripe pumpkin once more puffs it into a giant prize pumpkin.
        sim.waterPlant(at: CGPoint(x: x, y: sim.surface(x) - 10))
        XCTAssertTrue(sim.plots[3].plant?.giant ?? false)

        // Tapping harvests the giant prize pumpkin into the basket.
        let tap = CGPoint(x: x, y: sim.surface(x) - 26)
        sim.handBegan(tap)
        sim.handEnded(tap, tap: true)
        XCTAssertEqual(sim.basket.last, "pumpkin:0")
        XCTAssertFalse(sim.plots[3].plant?.giant ?? true)
        XCTAssertLessThan(sim.plots[3].plant?.growth ?? 1, 1)
    }

    func testFlowerHarvestFillsBouquetVaseAndCapsAtSix() {
        let sim = freshSim()
        let flowers: [PlantKind] = [.sunflower, .tulip, .daisy, .lavender, .sunflower, .tulip, .daisy, .lavender]
        for (idx, kind) in flowers.enumerated() {
            sim.plots[0].plant = Plant(kind: kind, growth: 1, left: 1, variant: idx)
            sim.harvest(0)
        }
        XCTAssertEqual(sim.basket.count, 8)
        XCTAssertEqual(sim.bouquet.count, GardenSim.maxBouquet)
        XCTAssertEqual(sim.bouquet.first, BouquetFlower(kind: .daisy, variant: 2))
        XCTAssertEqual(sim.bouquet.last, BouquetFlower(kind: .lavender, variant: 7))
    }

    func testPullingAWeedByHand() {
        let sim = freshSim()
        sim.weeds = [GWeed(x: 310, growth: 1, seed: 1)]
        let base = sim.surface(310)
        sim.handBegan(CGPoint(x: 310, y: base - 20))
        for k in 1...18 { sim.handMoved(CGPoint(x: 310, y: base - 20 - CGFloat(k) * 7)) }
        XCTAssertTrue(sim.weeds.isEmpty)
    }

    // MARK: Critter Visitors, Wishes, Stickers & Coins

    func testVisitorWishTapUnlocksStickerAndAwardsThreeCoinsOnce() {
        let sim = freshSim()
        sim.decor = []
        sim.basket = []
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.plots[1].plant = Plant(kind: .carrot, growth: 1, left: 1, variant: 0)
        sim.nextVisit = 0
        run(sim, seconds: 10)
        guard let bunny = sim.visitors.first(where: { $0.kind == .bunny }) else {
            return XCTFail("Expected bunny to visit ripe carrot")
        }
        XCTAssertEqual(bunny.state, .staying)
        XCTAssertEqual(bunny.kind.wish, .plant(.carrot))
        XCTAssertFalse(bunny.fulfilled)

        let coinsBefore = Coins.shared.balance
        let tapPt = CGPoint(x: bunny.pos.x, y: bunny.pos.y - 30)

        // Tapping before harvesting a carrot makes bunny wiggle without free coins or fulfillment.
        XCTAssertTrue(sim.tapVisitor(tapPt))
        XCTAssertFalse(sim.visitors.first(where: { $0.kind == .bunny })?.fulfilled ?? true)
        XCTAssertEqual(Coins.shared.balance, coinsBefore)

        // Having a carrot in the basket does NOT passively auto-fulfill without player action.
        sim.basket.append("carrot:0")
        run(sim, seconds: 2.0)
        XCTAssertFalse(sim.visitors.first(where: { $0.kind == .bunny })?.fulfilled ?? true)
        XCTAssertEqual(Coins.shared.balance, coinsBefore)

        // Now tapping bunny fulfills its wish once, unlocks its sticker, and awards 3 coins.
        XCTAssertTrue(sim.tapVisitor(tapPt))
        XCTAssertTrue(sim.visitors.first(where: { $0.kind == .bunny })?.fulfilled ?? false)
        XCTAssertTrue(StickerBook.shared.has(game: GardenSim.gameID, id: GardenFind.bunny.rawValue))
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)

        // Tapping again plays joyfully without double-awarding coins.
        run(sim, seconds: 0.7)
        XCTAssertTrue(sim.tapVisitor(tapPt))
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)
    }

    func testBasketDragFeedsVisitorToFulfillWish() {
        let sim = freshSim()
        sim.decor = []
        sim.basket = ["carrot:0"]
        var bunny = GVisitor(kind: .bunny, p: CGPoint(x: 320, y: GGeo.yardY + 8), facing: 1)
        bunny.state = .staying
        bunny.stayUntil = 30
        sim.visitors = [bunny]

        let coinsBefore = Coins.shared.balance
        sim.handBegan(GGeo.basket)
        let target = CGPoint(x: bunny.pos.x, y: bunny.pos.y - 30)
        sim.handMoved(target)
        sim.handEnded(target, tap: false)

        XCTAssertTrue(sim.visitors.first?.fulfilled ?? false)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)
    }

    func testHarvestingWishedCropFulfillsVisitorAutomatically() {
        let sim = freshSim()
        sim.decor = []
        sim.plots[2].plant = Plant(kind: .pumpkin, growth: 1, left: 1, variant: 0)
        var hedgehog = GVisitor(kind: .hedgehog, p: CGPoint(x: 320, y: GGeo.yardY + 8), facing: 1)
        hedgehog.state = .staying
        hedgehog.stayUntil = 30
        sim.visitors = [hedgehog]

        let coinsBefore = Coins.shared.balance
        sim.harvest(2)
        XCTAssertTrue(sim.visitors.first?.fulfilled ?? false)
        XCTAssertTrue(StickerBook.shared.has(game: GardenSim.gameID, id: GardenFind.hedgehog.rawValue))
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)
    }

    func testNobodyVisitsWhenThereIsNothingForThem() {
        let sim = freshSim()
        sim.decor = []
        sim.basket = []
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.nextVisit = 0
        run(sim, seconds: 10)
        XCTAssertTrue(sim.visitors.isEmpty)
    }

    func testAnOwlSitsOnTheFenceAtNight() {
        let sim = freshSim()
        sim.decor = []
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.setWeather(.night)
        sim.settleWeather()
        sim.nextVisit = 0
        run(sim, seconds: 1)
        sim.nextVisit = 0
        for _ in 0..<50 {
            if sim.visitors.contains(where: { $0.kind == .owl && $0.state == .staying }) { break }
            run(sim, seconds: 0.1)
        }
        let owl = sim.visitors.first { $0.kind == .owl && $0.state == .staying }
        XCTAssertNotNil(owl)
        XCTAssertEqual(owl?.p.y ?? 0, GGeo.fenceTopY, accuracy: 1)
    }

    // MARK: Safe Decor Placement & Hit-Test Priority

    func testSafeDecorPlacementPriorityAndReturnDropBadge() {
        let sim = freshSim()
        sim.decor = []
        let first = sim.placeDecorOnFreeSpot(.pinwheel)
        let second = sim.placeDecorOnFreeSpot(.mushroom)
        XCTAssertGreaterThan(abs(sim.decor[first].x - sim.decor[second].x), 80)

        // Foreground ripe plant wins hit-test over background decor standing directly behind it.
        let x = GGeo.plotX[2]
        sim.decor = []
        sim.addDecor(.birdhouse, x: x, falling: false)
        sim.plots[2].plant = Plant(kind: .tomato, growth: 1, left: 4)
        let tap = CGPoint(x: x, y: sim.surface(x) - 96)
        sim.handBegan(tap)
        sim.handEnded(tap, tap: true)
        XCTAssertEqual(sim.plots[2].plant?.left, 3, "Foreground plant must win over background birdhouse")
        XCTAssertFalse(sim.decor[0].held)

        // Dragging decor near the bottom edge OUTSIDE ReturnDropBadge keeps it safely (no silent deletion).
        sim.plots[2].plant = nil
        let grabPt = CGPoint(x: sim.decor[0].x, y: sim.decor[0].y - 60)
        sim.handBegan(grabPt)
        XCTAssertTrue(sim.isDraggingDecor)
        sim.handMoved(CGPoint(x: 420, y: 780))
        XCTAssertFalse(sim.overReturnBadge)
        sim.handEnded(CGPoint(x: 420, y: 780), tap: false)
        XCTAssertEqual(sim.decor.count, 1)

        // Dragging decor onto ReturnDropBadge cleanly puts it away.
        let grabPt2 = CGPoint(x: sim.decor[0].x, y: sim.decor[0].y - 60)
        sim.handBegan(grabPt2)
        sim.handMoved(GGeo.returnBadge)
        XCTAssertTrue(sim.overReturnBadge)
        sim.handEnded(GGeo.returnBadge, tap: false)
        XCTAssertTrue(sim.decor.isEmpty)
    }

    func testShortDecorPlacedClearOfTallPlantsAndReachable() {
        let sim = freshSim()
        sim.decor = []
        for i in sim.plots.indices {
            sim.plots[i].plant = Plant(kind: .sunflower, growth: 1, left: 1, variant: i % 6)
        }
        let idx = sim.placeDecorOnFreeSpot(.mushroom)
        let d = sim.decor[idx]
        for px in GGeo.plotX {
            XCTAssertGreaterThanOrEqual(abs(d.x - px), 48, "short decor should avoid hiding behind tall plot stems")
        }
        let grabPt = CGPoint(x: d.x, y: d.y - 24)
        sim.handBegan(grabPt)
        XCTAssertTrue(sim.isDraggingDecor, "short decor placed in open gap should be directly grabbable")
        sim.handEnded(grabPt, tap: false)
    }

    func testBasketClearOfTrayBar() {
        let trayBottom = GGeo.trayY + 46
        let basketTop = GGeo.basket.y - 49
        XCTAssertGreaterThan(basketTop, trayBottom + 16, "harvest basket handle and crops must clear the floating seed tray")
    }

    // MARK: Rare Variants, Stickers, Save Compatibility & Audio

    func testSpecialPlantsLookDifferent() {
        let plain = Plant(kind: .tomato, growth: 1, left: 1, variant: 2)
        let gold = Plant(kind: .tomato, growth: 1, left: 1, variant: Plant.specialVariant + 2)
        XCTAssertFalse(plain.isSpecial)
        XCTAssertTrue(gold.isSpecial)
        XCTAssertNil(plain.specialTint)
        XCTAssertEqual(gold.kind.bloom(gold.variant), PlantKind.tomato.specialColor)
        for k in PlantKind.allCases where k != .pumpkin {
            XCTAssertNotEqual(k.specialColor, k.bloom(0), k.rawValue)
        }
        for _ in 0..<200 {
            let v = GardenSim.rollVariant()
            XCTAssertTrue((0..<6).contains(v % Plant.specialVariant))
        }
    }

    func testEverySurpriseHasASticker() {
        let entry = GameRegistry.all.first { $0.id == GardenSim.gameID }
        XCTAssertEqual(entry?.stickers.map(\.id), GardenFind.allCases.map(\.rawValue))
        XCTAssertEqual(entry?.stickers.count, 15)
        for k in PlantKind.allCases { XCTAssertEqual(GardenFind.special(k).plant, k) }
        for v in GVisitorKind.allCases { XCTAssertEqual(GardenFind(rawValue: v.rawValue)?.visitor, v) }
    }

    func testSaveRoundTripAndLegacyJsonCompatibility() throws {
        let sim = freshSim()
        sim.showcase()
        let saved = sim.makeSave()
        let encoded = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(GardenSave.self, from: encoded)
        XCTAssertEqual(decoded, saved)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.plots.map(\.plant), sim.plots.map(\.plant))
        XCTAssertEqual(restored.bouquet, sim.bouquet)
        XCTAssertEqual(restored.decor.count, sim.decor.count)
        XCTAssertTrue(restored.plots[5].plant?.giant ?? false)

        // Legacy garden.json with 224 soil columns, old stamps/channels keys, and no giant/bouquet fields.
        let legacySoil = Array(repeating: 548.0, count: 224)
        let legacyWet = Array(repeating: 0.4, count: 224)
        let legacyJSON = """
        {
          "plots": [
            {"kind": "sunflower", "growth": 0.9, "left": 0, "variant": 1},
            null,
            {"kind": "pumpkin", "growth": 1.0, "left": 1, "variant": 0},
            null,
            null,
            null
          ],
          "soil": \(legacySoil),
          "wet": \(legacyWet),
          "weeds": [{"x": 350.0, "growth": 0.6, "seed": 4}],
          "decor": [{"kind": "pinwheel", "x": 220.0, "water": 0.0}],
          "basket": ["carrot:0"],
          "weather": "sun",
          "stamps": [{"kind": "tulip", "variant": 0, "x": 0.5, "y": 0.5}],
          "channels": [1, 2, 3]
        }
        """
        let legacySave = try JSONDecoder().decode(GardenSave.self, from: Data(legacyJSON.utf8))
        let migrated = GardenSim(save: legacySave)
        XCTAssertEqual(migrated.plots[0].plant?.kind, .sunflower)
        XCTAssertEqual(migrated.plots[2].plant?.kind, .pumpkin)
        XCTAssertFalse(migrated.plots[2].plant?.giant ?? true)
        XCTAssertEqual(migrated.basket, ["carrot:0"])
        XCTAssertEqual(migrated.decor.count, 1)
        XCTAssertTrue(migrated.bouquet.isEmpty)
        XCTAssertEqual(migrated.h.count, GGeo.columns)
        XCTAssertEqual(migrated.wet.count, GGeo.columns)
    }

    func testEverySoundIsBundled() {
        for s in GardenSFX.allCases {
            let url = GameFiles.url(s.rawValue, "caf", game: "Garden") ?? GameFiles.url(s.rawValue, "wav", game: "Garden")
            XCTAssertNotNil(url, s.rawValue)
        }
    }

    func testLotusLanternTreasureGatingAndSaveRoundTrip() throws {
        XCTAssertEqual(DecorKind.lotus.treasure, "garden/lotus")
        XCTAssertFalse(DecorKind.available.contains(.lotus))

        Coins.shared.resetForTests(balance: 40)
        XCTAssertTrue(Coins.shared.buy("garden/lotus", price: 12))
        XCTAssertTrue(DecorKind.available.contains(.lotus))

        let sim = freshSim()
        sim.decor = []
        let idx = sim.placeDecorOnFreeSpot(.lotus)
        XCTAssertEqual(sim.decor[idx].kind, .lotus)

        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(GardenSave.self, from: data)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.decor.map(\.kind), [.lotus])
    }

    // MARK: Wave 2D — Hybrids, Picnic & 5-Stage Treehouse, Seasons/Fireflies & Flower Crowns

    func testManualPollenCrossBreedingCreatesAllSixHybridsAndSavesDiscovery() throws {
        let sim = freshSim()
        for i in sim.plots.indices { sim.plots[i].plant = nil }

        // Dragging the glowing pollen orb from ripe Tulip (plot 0) onto ripe Daisy (plot 1) breeds Starlight Rose!
        sim.plots[0].plant = Plant(kind: .tulip, growth: 1, left: 1, variant: 0)
        sim.plots[1].plant = Plant(kind: .daisy, growth: 1, left: 2, variant: 0)
        guard let orb = sim.pollenOrbPos(plot: 0), let targetAnchor = sim.pollenAnchor(plot: 1) else {
            return XCTFail("Expected glowing pollen orb and partner anchor")
        }
        let coinsBefore = Coins.shared.balance
        sim.handBegan(orb)
        XCTAssertNotNil(sim.dragPollenPos)
        sim.handMoved(targetAnchor)
        sim.handEnded(targetAnchor, tap: false)

        XCTAssertEqual(sim.plots[1].plant?.hybrid, .starlightRose)
        XCTAssertTrue(sim.discoveredHybrids.contains(.starlightRose))
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 5, "First-time hybrid discovery should award +5 Play Coins")

        // Breeding Starlight Rose a second time does not double-award first-time discovery coins.
        sim.plots[2].plant = Plant(kind: .daisy, growth: 1, left: 2, variant: 0)
        XCTAssertEqual(sim.crossBreed(fromPlot: 0, ontoPlot: 2), .starlightRose)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 5)

        // Verify the remaining 5 distinct HybridKind recipes.
        let pairs: [(PlantKind, PlantKind, HybridKind)] = [
            (.lavender, .sunflower, .cottonSunflower),
            (.tulip, .strawberry, .moonberryTulip),
            (.sunflower, .lavender, .rainbowLavender),
            (.daisy, .pumpkin, .crystalPumpkin),
            (.tomato, .strawberry, .sparkleBerryVine),
        ]
        for (donor, target, expected) in pairs {
            sim.plots[3].plant = Plant(kind: target, growth: 1, left: target.crop, variant: 0)
            let created = sim.crossBreed(from: donor, ontoPlot: 3)
            XCTAssertEqual(created, expected)
            XCTAssertEqual(sim.plots[3].plant?.hybrid, expected)
        }
        XCTAssertEqual(Set(sim.discoveredHybrids), Set(HybridKind.allCases))
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 30)

        // Harvesting a hybrid flower puts it into the bouquet; harvesting a hybrid fruit puts it into the basket.
        sim.harvest(1) // starlightRose
        XCTAssertEqual(sim.bouquet.last?.hybrid, .starlightRose)
        sim.plots[4].plant = Plant(kind: .pumpkin, growth: 1, left: 1, variant: 0, hybrid: .crystalPumpkin)
        sim.harvest(4)
        XCTAssertEqual(sim.basket.last, "hybrid:crystalPumpkin")

        // Verify discoveredHybrids persists across GardenSave round-trip.
        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(GardenSave.self, from: data)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.discoveredHybrids, sim.discoveredHybrids)
    }

    func testLiveBeePollinatesTwoDifferentRipeBloomsIntoHybrid() {
        let sim = freshSim()
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.plots[0].plant = Plant(kind: .tulip, growth: 1, left: 1, variant: 0)
        sim.plots[1].plant = Plant(kind: .daisy, growth: 1, left: 2, variant: 0)
        sim.setWeather(.sun)
        sim.settleWeather()

        var sawCarryingPollen = false
        for _ in 0..<600 {
            sim.step(dt: 1.0 / 60)
            if sim.bee?.carryingPollenFrom != nil { sawCarryingPollen = true }
            if sim.plots[0].plant?.hybrid != nil || sim.plots[1].plant?.hybrid != nil { break }
        }
        XCTAssertTrue(sawCarryingPollen, "Live bee should visibly carry golden pollen between blooms")
        let hybrid = sim.plots[0].plant?.hybrid ?? sim.plots[1].plant?.hybrid
        XCTAssertEqual(hybrid, .starlightRose)
        XCTAssertTrue(sim.discoveredHybrids.contains(.starlightRose))
    }

    func testCritterPicnicFeedingAndFiveStageStorybookTreehouse() throws {
        let sim = freshSim()
        sim.basket = [
            "carrot:0", "strawberry:0", "tomato:0", "pumpkin:0", "hybrid:crystalPumpkin",
            "carrot:0", "strawberry:0", "tomato:0", "pumpkin:0", "hybrid:sparkleBerryVine", "carrot:0"
        ]
        XCTAssertEqual(sim.treehouseStage, 0)

        // Dragging from Harvest Basket onto Critter Picnic Blanket feeds a critter and awards +3 coins.
        let coinsBefore = Coins.shared.balance
        sim.handBegan(GGeo.basket)
        sim.handMoved(GGeo.picnic)
        sim.handEnded(GGeo.picnic, tap: false)

        XCTAssertEqual(sim.picnicFeedCount, 1)
        XCTAssertEqual(sim.treehouseStage, 0)
        XCTAssertEqual(sim.basket.count, 10)
        XCTAssertEqual(sim.picnicCritters.count, 1)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)

        // Tapping the Picnic Blanket serves another snack -> feedCount == 2 -> Treehouse Stage 1!
        sim.handBegan(GGeo.picnic)
        sim.handEnded(GGeo.picnic, tap: true)
        XCTAssertEqual(sim.picnicFeedCount, 2)
        XCTAssertEqual(sim.treehouseStage, 1)

        // Continue feeding up to Stage 5 and ensure stage caps cleanly at 5.
        for expectedStage in 2...5 {
            XCTAssertTrue(sim.servePicnicSnack())
            XCTAssertTrue(sim.servePicnicSnack())
            XCTAssertEqual(sim.treehouseStage, expectedStage)
        }
        XCTAssertTrue(sim.servePicnicSnack())
        XCTAssertEqual(sim.treehouseStage, GardenSim.maxTreehouseStage)

        // Verify treehouseStage & picnicFeedCount round-trip through GardenSave.
        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(GardenSave.self, from: data)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.treehouseStage, 5)
        XCTAssertEqual(restored.picnicFeedCount, sim.picnicFeedCount)

        // Verify layout clearance: Picnic Blanket clears lifted dock (dockY = 740) and bed plots.
        let dockRight: CGFloat = 512 + 196
        let picnicLeft = GGeo.picnic.x - GGeo.picnicSize.width / 2
        XCTAssertGreaterThan(picnicLeft, dockRight + 20, "Picnic blanket must clear the lifted bottom dock")
        XCTAssertGreaterThan(GGeo.picnic.y - GGeo.picnicSize.height / 2, GGeo.bedBottom + 20, "Picnic blanket must clear the raised bed")
    }

    func testSeasonCyclingSpringVortexRainbowShimmerAndFireflyJar() throws {
        let sim = freshSim()
        XCTAssertEqual(sim.season, .spring)
        sim.cycleSeason()
        XCTAssertEqual(sim.season, .summer)
        sim.cycleSeason()
        XCTAssertEqual(sim.season, .autumn)
        sim.cycleSeason()
        XCTAssertEqual(sim.season, .winter)
        sim.cycleSeason()
        XCTAssertEqual(sim.season, .spring)

        // Spring cherry breeze finger swipe activates vortex & swirls cherry petals.
        sim.handBegan(CGPoint(x: 240, y: 260))
        sim.handMoved(CGPoint(x: 340, y: 240))
        sim.handMoved(CGPoint(x: 420, y: 210))
        sim.handEnded(CGPoint(x: 420, y: 210), tap: false)
        XCTAssertNotNil(sim.vortexCenter)
        XCTAssertGreaterThan(sim.vortexUntil, sim.time)

        // Rainbow Sunshower: rain -> sun charges ripe blooms for +2 bonus coins on harvest.
        sim.plots[2].plant = Plant(kind: .tulip, growth: 1, left: 1, variant: 0)
        sim.setWeather(.rain)
        sim.setWeather(.sun)
        XCTAssertTrue(sim.plots[2].plant?.rainbowCharged ?? false)
        let coinsBefore = Coins.shared.balance
        sim.harvest(2)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 2)
        XCTAssertFalse(sim.plots[2].plant?.rainbowCharged ?? true)

        // Night Firefly Lantern Jar: tapping catches firefly, tapping jar releases in starry swirl!
        sim.setWeather(.night)
        sim.settleWeather()
        let flyPos = CGPoint(x: 420, y: 310)
        sim.fireflies = [GFirefly(p: flyPos, v: .zero, phase: 0)]
        sim.handBegan(flyPos)
        sim.handEnded(flyPos, tap: true)
        XCTAssertEqual(sim.caughtFireflies, 1)
        XCTAssertTrue(sim.fireflies.isEmpty)

        // Persist season & caughtFireflies cleanly
        sim.setSeason(.autumn)
        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(GardenSave.self, from: data)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.season, .autumn)
        XCTAssertEqual(restored.caughtFireflies, 1)

        // Tapping bench lantern jar releases all caught fireflies back into the night garden.
        let jarTap = CGPoint(x: GGeo.fireflyJar.x, y: GGeo.fireflyJar.y - 20)
        sim.handBegan(jarTap)
        sim.handEnded(jarTap, tap: true)
        XCTAssertEqual(sim.caughtFireflies, 0)
        XCTAssertEqual(sim.fireflies.count, 1)
    }

    func testWeaveFlowerCrownFromVaseAndPlaceOnVisitingAndPicnicCritters() {
        let sim = freshSim()
        sim.bouquet = [
            BouquetFlower(kind: .tulip, variant: 0),
            BouquetFlower(kind: .daisy, variant: 1),
        ]
        // Fewer than 3 flowers cannot weave a crown yet.
        XCTAssertFalse(sim.weaveFlowerCrown())
        XCTAssertFalse(sim.hasCraftedCrown)

        // Add a 3rd bloom (a hybrid!) and tap the sparkling vase to weave a Flower Crown!
        sim.bouquet.append(BouquetFlower(kind: .sunflower, variant: 0, hybrid: .cottonSunflower))
        let vaseTap = CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 40)
        sim.handBegan(vaseTap)
        sim.handEnded(vaseTap, tap: true)
        XCTAssertTrue(sim.hasCraftedCrown)
        XCTAssertEqual(sim.craftedCrownColors.count, 5)
        XCTAssertTrue(sim.bouquet.isEmpty)

        // Drag the Flower Crown onto a visiting bunny -> bunny wears crown proudly + awards +3 Play Coins!
        var bunny = GVisitor(kind: .bunny, p: CGPoint(x: 420, y: GGeo.yardY + 8), facing: 1)
        bunny.state = .staying
        bunny.stayUntil = 30
        sim.visitors = [bunny]

        let coinsBefore = Coins.shared.balance
        let crownStart = CGPoint(x: GGeo.flowerCrownSpot.x, y: GGeo.flowerCrownSpot.y - 14)
        let bunnyDrop = CGPoint(x: bunny.p.x, y: bunny.p.y - 36)
        sim.handBegan(crownStart)
        sim.handMoved(bunnyDrop)
        sim.handEnded(bunnyDrop, tap: false)

        XCTAssertTrue(sim.visitors[0].wearingCrown)
        XCTAssertEqual(sim.visitors[0].crownColors.count, 5)
        XCTAssertFalse(sim.hasCraftedCrown)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)

        // Weave a 2nd crown and place it onto a picnic critter!
        sim.bouquet = [
            BouquetFlower(kind: .tulip, variant: 0),
            BouquetFlower(kind: .lavender, variant: 0),
            BouquetFlower(kind: .daisy, variant: 0, hybrid: .starlightRose),
        ]
        XCTAssertTrue(sim.weaveFlowerCrown())
        sim.basket = ["strawberry:0"]
        XCTAssertTrue(sim.servePicnicSnack())
        XCTAssertTrue(sim.placeCrownOnNearestCritter())
        XCTAssertTrue(sim.picnicCritters.first?.wearingCrown ?? false)
        XCTAssertFalse(sim.hasCraftedCrown)
    }
}
