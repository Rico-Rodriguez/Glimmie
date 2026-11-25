import XCTest
@testable import Glimmie

final class GardenTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Coins.shared.resetForTests()
        StickerBook.shared.resetForTests()
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

    // MARK: Soil Conservation & Zero-Friction Planting

    func testSoilMassConservedAcrossDiggingAndLanding() {
        let sim = freshSim()
        let before = sim.totalSoil
        sim.pickUp(.shovel, at: CGPoint(x: 340, y: GGeo.soilY + 12))
        for k in 0..<18 {
            sim.carry(to: CGPoint(x: 340 + CGFloat(k) * 3, y: GGeo.soilY + 16))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertGreaterThan(sim.load, 10)
        sim.release(home: CGPoint(x: 371, y: GGeo.dockY))
        run(sim, seconds: 2.5)
        XCTAssertEqual(sim.totalSoil, before, accuracy: 28)
    }

    func testZeroFrictionPlantingByDragAndTap() {
        let sim = freshSim()
        for i in sim.plots.indices { sim.plots[i].plant = nil }

        sim.pickUp(.seeds(.daisy), at: CGPoint(x: GGeo.plotX[1], y: 400))
        run(sim, seconds: 2.2)
        XCTAssertEqual(sim.plots[1].plant?.kind, .daisy)
        XCTAssertGreaterThan(sim.plots[1].plant?.growth ?? 0, 0.05)
        sim.release(home: CGPoint(x: 559, y: GGeo.dockY))

        sim.pickUp(.seeds(.tulip), at: CGPoint(x: GGeo.plotX[3], y: GGeo.soilY - 12))
        sim.release(home: CGPoint(x: 559, y: GGeo.dockY))
        XCTAssertEqual(sim.plots[3].plant?.kind, .tulip)

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

    // MARK: Species Variety, Distinct Growth Durations & Finite Yields

    func testSpeciesCatalogDistinctDurationsYieldsMechanicsAndPalettes() {
        let durations = Set(PlantKind.allCases.map(\.growthDuration))
        XCTAssertEqual(durations.count, PlantKind.allCases.count, "All 8 species must have distinct growth durations")
        for kind in PlantKind.allCases {
            let spec = kind.spec
            XCTAssertGreaterThanOrEqual(spec.growthDuration, 2.6)
            XCTAssertLessThanOrEqual(spec.growthDuration, 6.0)
            XCTAssertGreaterThanOrEqual(spec.normalPalette.count, 3, "\(kind.rawValue) should have a multi-color normal palette")
            XCTAssertNotEqual(kind.bloom(0), kind.bloom(1), "\(kind.rawValue) normal variants should differ")
        }

        XCTAssertEqual(PlantKind.carrot.crop, 1)
        XCTAssertEqual(PlantKind.pumpkin.crop, 1)
        XCTAssertEqual(PlantKind.sunflower.crop, 1)
        XCTAssertEqual(PlantKind.tulip.crop, 1)
        XCTAssertEqual(PlantKind.daisy.crop, 2)
        XCTAssertEqual(PlantKind.lavender.crop, 2)
        XCTAssertEqual(PlantKind.strawberry.crop, 3)
        XCTAssertEqual(PlantKind.tomato.crop, 3)

        XCTAssertEqual(PlantKind.carrot.harvestMechanic, .pullUp)
        XCTAssertEqual(PlantKind.tulip.harvestMechanic, .snipStem)
        XCTAssertEqual(PlantKind.strawberry.harvestMechanic, .shakeVine)
        XCTAssertEqual(PlantKind.tomato.harvestMechanic, .shakeVine)
        XCTAssertEqual(PlantKind.pumpkin.harvestMechanic, .waterPuff)
        XCTAssertEqual(HybridKind.crystalPumpkin.harvestMechanic, .waterPuff)
        XCTAssertEqual(HybridKind.sparkleBerryVine.harvestMechanic, .shakeVine)

        // Carrot (2.6s) ripens noticeably before Pumpkin (6.0s) in identical wet soil.
        let sim = freshSim()
        sim.setWeather(.wind)
        sim.settleWeather()
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.plots[0].stage = .growing(GrowingPlant(kind: .carrot, growth: 0.08, variant: 0))
        sim.plots[1].stage = .growing(GrowingPlant(kind: .pumpkin, growth: 0.08, variant: 0))
        for i in 0..<GGeo.columns { sim.wet[i] = 1.0 }
        run(sim, seconds: 2.8)
        if case .ripe = sim.plots[0].stage { } else { XCTFail("Carrot should be ripe after 2.8s") }
        if case .growing(let pGrow) = sim.plots[1].stage {
            XCTAssertLessThan(pGrow.growth, 0.85, "Pumpkin should still be growing at 2.8s")
        } else {
            XCTFail("Pumpkin should still be growing at 2.8s")
        }
    }

    func testWateredGrowthAndThirstyDroop() {
        let sim = freshSim()
        sim.plots[5].stage = .growing(GrowingPlant(kind: .tulip, growth: 0.08, variant: 0))
        for i in 0..<GGeo.columns { sim.wet[i] = 0 }

        run(sim, seconds: 2.5)
        XCTAssertEqual(sim.plots[5].plant?.growth ?? 0, 0.08, accuracy: 0.001)
        XCTAssertGreaterThan(sim.plots[5].dry, 1.5)

        for i in 0..<GGeo.columns { sim.wet[i] = 0.9 }
        run(sim, seconds: 4.2)
        if case .ripe(let ripe) = sim.plots[5].stage {
            XCTAssertEqual(ripe.kind, .tulip)
            XCTAssertEqual(ripe.yieldLeft, PlantKind.tulip.crop)
        } else {
            XCTFail("Tulip should be ripe after watering")
        }
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

    // MARK: Finite Plot Lifecycle & All 4 Harvest Mechanics (+ 1-Tap Parity)

    func testFiniteHarvestClearsEverySpeciesAndHybridToEmptyWithoutRegrowth() {
        let sim = freshSim()
        for kind in PlantKind.allCases {
            sim.plots[0].stage = .ripe(RipePlant(kind: kind, variant: 1, yieldLeft: kind.crop))
            for remaining in stride(from: kind.crop, through: 1, by: -1) {
                let harvested = sim.harvest(0)
                XCTAssertNotNil(harvested)
                if remaining > 1 {
                    if case .ripe(let ripe) = sim.plots[0].stage {
                        XCTAssertEqual(ripe.yieldLeft, remaining - 1)
                    } else {
                        XCTFail("\(kind.rawValue) should stay ripe with yieldLeft == \(remaining - 1)")
                    }
                } else {
                    if case .empty(_, let ready) = sim.plots[0].stage {
                        XCTAssertTrue(ready, "\(kind.rawValue) must clear to .empty(surpriseReady: true) after final harvest")
                    } else {
                        XCTFail("\(kind.rawValue) must clear to .empty instead of regrowing!")
                    }
                    XCTAssertNil(sim.plots[0].plant)
                }
            }
        }

        for hybrid in HybridKind.allCases {
            sim.plots[1].stage = .ripe(RipePlant(kind: hybrid.parents.0, variant: 0, yieldLeft: hybrid.crop, hybrid: hybrid))
            for _ in 0..<hybrid.crop {
                let harvested = sim.harvest(1)
                XCTAssertNotNil(harvested)
            }
            XCTAssertTrue(sim.plots[1].isEmpty, "Hybrid \(hybrid.rawValue) must clear to .empty after finite harvest")
        }
    }

    func testCarrotPullUpDragAndOneTapParity() {
        let sim = freshSim()
        sim.plots[1].stage = .ripe(RipePlant(kind: .carrot, variant: 2, yieldLeft: 1))
        let x = GGeo.plotX[1]
        let base = sim.surface(x)
        sim.handBegan(CGPoint(x: x, y: base - 24))
        for k in 1...16 {
            sim.handMoved(CGPoint(x: x, y: base - 24 - CGFloat(k) * 6))
        }
        sim.handEnded(CGPoint(x: x, y: base - 120), tap: false)
        XCTAssertTrue(sim.plots[1].isEmpty)
        XCTAssertEqual(sim.inventory.last?.source, .plant(kind: .carrot, variant: 2, isGiant: false))

        // 1-tap parity harvests a ripe carrot cleanly too.
        sim.plots[2].stage = .ripe(RipePlant(kind: .carrot, variant: 1, yieldLeft: 1))
        let x2 = GGeo.plotX[2]
        let tapPt = CGPoint(x: x2, y: sim.surface(x2) - 24)
        sim.handBegan(tapPt)
        sim.handEnded(tapPt, tap: true)
        XCTAssertTrue(sim.plots[2].isEmpty)
        XCTAssertEqual(sim.inventory.last?.source, .plant(kind: .carrot, variant: 1, isGiant: false))
    }

    func testSwipeAndTapShakeVineBerriesAndTomatoes() {
        let sim = freshSim()
        sim.decor = []
        sim.plots[1].stage = .ripe(RipePlant(kind: .tomato, variant: 0, yieldLeft: 3))
        sim.plots[2].stage = .ripe(RipePlant(kind: .strawberry, variant: 0, yieldLeft: 3))

        let start = CGPoint(x: GGeo.plotX[1] - 50, y: GGeo.soilY - 38)
        let end = CGPoint(x: GGeo.plotX[2] + 50, y: start.y)
        sim.handBegan(start)
        sim.handMoved(end)
        sim.handMoved(start)
        sim.handEnded(start, tap: false)
        XCTAssertEqual(sim.inventory.count, 2)
        XCTAssertEqual(sim.plots[1].plant?.left, 2)
        XCTAssertEqual(sim.plots[2].plant?.left, 2)

        // 1-tap parity shakes the remaining two strawberries off one by one, then clears plot to empty.
        let sx = GGeo.plotX[2]
        let tapPt = CGPoint(x: sx, y: sim.surface(sx) - 34)
        sim.handBegan(tapPt)
        sim.handEnded(tapPt, tap: true)
        XCTAssertEqual(sim.plots[2].plant?.left, 1)
        sim.handBegan(tapPt)
        sim.handEnded(tapPt, tap: true)
        XCTAssertTrue(sim.plots[2].isEmpty)
    }

    func testWaterPuffGiantPumpkinAndCrystalPumpkinPreservesGiantIntoHarvestItem() {
        let sim = freshSim()
        sim.plots[3].stage = .ripe(RipePlant(kind: .pumpkin, variant: 0, yieldLeft: 1, isGiant: false))
        let x = GGeo.plotX[3]
        sim.waterPlant(at: CGPoint(x: x, y: sim.surface(x) - 10))
        sim.drainEffectsForTesting()

        XCTAssertTrue(sim.plots[3].plant?.giant ?? false)
        XCTAssertTrue(StickerBook.shared.has(game: GardenSim.gameID, id: GardenFind.giantPumpkin.rawValue))

        let tap = CGPoint(x: x, y: sim.surface(x) - 26)
        sim.handBegan(tap)
        sim.handEnded(tap, tap: true)
        XCTAssertTrue(sim.plots[3].isEmpty, "Harvesting giant pumpkin must clear plot to .empty")
        XCTAssertEqual(sim.inventory.last?.source, .plant(kind: .pumpkin, variant: 0, isGiant: true))
        XCTAssertTrue(sim.inventory.last?.isGiant ?? false)

        // Crystal pumpkin hybrid also supports water puffing and preserves isGiant.
        sim.plots[4].stage = .ripe(RipePlant(kind: .pumpkin, variant: 0, yieldLeft: 1, isGiant: false, hybrid: .crystalPumpkin))
        let x4 = GGeo.plotX[4]
        sim.waterPlant(at: CGPoint(x: x4, y: sim.surface(x4) - 10))
        XCTAssertTrue(sim.plots[4].plant?.giant ?? false)
        let crystalItem = sim.harvest(4)
        XCTAssertEqual(crystalItem?.source, .hybrid(kind: .crystalPumpkin, isGiant: true))
        XCTAssertTrue(sim.plots[4].isEmpty)
    }

    func testFlowerHarvestFillsVaseDisplayUpToSixWhileKeepingFullInventory() {
        let sim = freshSim()
        let flowers: [PlantKind] = [.sunflower, .tulip, .daisy, .lavender, .sunflower, .tulip, .daisy, .lavender]
        for (idx, kind) in flowers.enumerated() {
            sim.plots[0].stage = .ripe(RipePlant(kind: kind, variant: idx, yieldLeft: 1))
            sim.harvest(0)
        }
        XCTAssertEqual(sim.inventory.count, 8)
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

    // MARK: Shovel Uproot, Surprises & Full-Bed Unblock Protection

    func testShovelPopsWeedsUprootsPlantAndUnearthsSurprises() {
        let sim = freshSim()
        sim.weeds = [GWeed(x: 310, growth: 1, seed: 2)]
        sim.pickUp(.shovel, at: CGPoint(x: 290, y: GGeo.soilY - 8))
        sim.carry(to: CGPoint(x: 325, y: GGeo.soilY + 6))
        run(sim, seconds: 0.35)
        XCTAssertTrue(sim.weeds.isEmpty)
        sim.release(home: CGPoint(x: 371, y: GGeo.dockY))

        sim.plots[2].stage = .growing(GrowingPlant(kind: .daisy, growth: 0.5, variant: 0))
        let px = GGeo.plotX[2]
        sim.pickUp(.shovel, at: CGPoint(x: px - 12, y: GGeo.soilY + 8))
        for k in 0..<25 {
            sim.carry(to: CGPoint(x: px - 12 + CGFloat(k) * 1.4, y: GGeo.soilY + 12))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertTrue(sim.plots[2].isEmpty)
        sim.release(home: CGPoint(x: 371, y: GGeo.dockY))

        sim.plots[1].stage = .empty(surprise: .coins, surpriseReady: true)
        let coinsBefore = Coins.shared.balance
        XCTAssertEqual(sim.unearthSurprise(plot: 1), .coins)
        sim.drainEffectsForTesting()
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 2)

        sim.plots[3].stage = .empty(surprise: .worm, surpriseReady: true)
        XCTAssertEqual(sim.unearthSurprise(plot: 3), .worm)
        XCTAssertGreaterThan(sim.worm.peekUntil, sim.time)

        sim.plots[4].stage = .empty(surprise: .ladybug, surpriseReady: true)
        sim.ladybug.flying = false
        XCTAssertEqual(sim.unearthSurprise(plot: 4), .ladybug)
        XCTAssertTrue(sim.ladybug.flying)

        sim.plots[5].stage = .empty(surprise: .mysteryBulb, surpriseReady: true)
        XCTAssertEqual(sim.unearthSurprise(plot: 5), .mysteryBulb)
        XCTAssertTrue(sim.plots[5].plant?.isSpecial ?? false)
    }

    func testShovelClearsWeedFirstWithoutUprootingNearbyPlant() {
        let sim = freshSim()
        let px = GGeo.plotX[2]
        sim.plots[2].stage = .ripe(RipePlant(kind: .sunflower, variant: 0, yieldLeft: 1))
        sim.weeds = [GWeed(x: px + 34, growth: 1, seed: 3)]

        sim.pickUp(.shovel, at: CGPoint(x: px + 44, y: GGeo.soilY + 6))
        for k in 0..<18 {
            sim.carry(to: CGPoint(x: px + 44 - CGFloat(k) * 2.5, y: GGeo.soilY + 8))
            sim.step(dt: 1.0 / 60)
        }
        sim.release(home: CGPoint(x: 371, y: GGeo.dockY))

        XCTAssertTrue(sim.weeds.isEmpty)
        XCTAssertEqual(sim.plots[2].plant?.kind, .sunflower)
    }

    func testFullBedAutoShovelUnblocksWhileProtectingHybridsAndGiants() {
        let sim = freshSim()
        sim.weeds = []
        sim.plots[0].stage = .ripe(RipePlant(kind: .tulip, variant: 0, yieldLeft: 1, hybrid: .starlightRose))
        sim.plots[1].stage = .ripe(RipePlant(kind: .pumpkin, variant: 0, yieldLeft: 1, isGiant: true))
        sim.plots[2].stage = .ripe(RipePlant(kind: .sunflower, variant: Plant.specialVariant, yieldLeft: 1))
        sim.plots[3].stage = .growing(GrowingPlant(kind: .daisy, growth: 0.4, variant: 0))
        sim.plots[4].stage = .ripe(RipePlant(kind: .lavender, variant: 0, yieldLeft: 2, hybrid: .rainbowLavender))
        sim.plots[5].stage = .ripe(RipePlant(kind: .pumpkin, variant: 0, yieldLeft: 1, isGiant: true))

        // Priority 3: All 6 occupied -> uproots the common non-special, non-giant, non-hybrid daisy at plot 3.
        sim.tapDockShovel()
        XCTAssertTrue(sim.plots[3].isEmpty, "Full-bed autoShovel should uproot common plot 3 first")
        XCTAssertEqual(sim.plots[0].plant?.hybrid, .starlightRose, "Must spare hybrids")
        XCTAssertTrue(sim.plots[1].plant?.giant ?? false, "Must spare giant pumpkins")
        XCTAssertEqual(sim.plots[4].plant?.hybrid, .rainbowLavender, "Must spare hybrids")

        // Now fill plot 3 with a hybrid and make only giants + hybrids occupy the bed; giant is uprooted before hybrids.
        sim.plots[3].stage = .ripe(RipePlant(kind: .tulip, variant: 0, yieldLeft: 1, hybrid: .moonberryTulip))
        sim.plots[2].stage = .ripe(RipePlant(kind: .sunflower, variant: 0, yieldLeft: 1, hybrid: .cottonSunflower))
        sim.tapDockShovel()
        XCTAssertTrue(sim.plots[1].isEmpty, "When only giants and hybrids remain, hybrids stay protected over giant")
        XCTAssertEqual(sim.plots[0].plant?.hybrid, .starlightRose)
        XCTAssertEqual(sim.plots[2].plant?.hybrid, .cottonSunflower)
        XCTAssertEqual(sim.plots[3].plant?.hybrid, .moonberryTulip)
        XCTAssertEqual(sim.plots[4].plant?.hybrid, .rainbowLavender)
    }

    // MARK: Manual Drag + 1-Tap Pollination (Zero Autonomous Bee Cross-Breeding)

    func testAutonomousBeeNeverAutoBreedsHybrids() {
        let sim = freshSim()
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.plots[0].stage = .ripe(RipePlant(kind: .tulip, variant: 0, yieldLeft: 1))
        sim.plots[1].stage = .ripe(RipePlant(kind: .daisy, variant: 0, yieldLeft: 2))
        sim.setWeather(.sun)
        sim.settleWeather()

        run(sim, seconds: 14.0)
        XCTAssertNotNil(sim.bee, "Bee should still buzz cheerfully as a decorative flyer")
        XCTAssertNil(sim.plots[0].plant?.hybrid, "Autonomous bee must NEVER auto-breed hybrids")
        XCTAssertNil(sim.plots[1].plant?.hybrid, "Autonomous bee must NEVER auto-breed hybrids")
        XCTAssertTrue(sim.discoveredHybrids.isEmpty)
    }

    func testManualDragAndOneTapPollinationCreateAllSixHybridsAndPersist() throws {
        let sim = freshSim()
        for i in sim.plots.indices { sim.plots[i].plant = nil }

        // 1) Drag pollen orb from ripe Tulip (plot 0) onto ripe Daisy (plot 1) -> Starlight Rose.
        sim.plots[0].stage = .ripe(RipePlant(kind: .tulip, variant: 0, yieldLeft: 1))
        sim.plots[1].stage = .ripe(RipePlant(kind: .daisy, variant: 0, yieldLeft: 2))
        guard let orb0 = sim.pollenOrbPos(plot: 0), let anchor1 = sim.pollenAnchor(plot: 1) else {
            return XCTFail("Expected pollen orb and partner anchor")
        }
        let coinsBefore = Coins.shared.balance
        sim.handBegan(orb0)
        XCTAssertNotNil(sim.dragPollenPos)
        sim.handMoved(anchor1)
        sim.handEnded(anchor1, tap: false)
        sim.drainEffectsForTesting()

        XCTAssertEqual(sim.plots[1].plant?.hybrid, .starlightRose)
        XCTAssertTrue(sim.discoveredHybrids.contains(.starlightRose))
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 5)

        // 2) 1-tap parity: tap pollen orb on plot 0 -> tapMode active -> tap ripe Strawberry on plot 2 -> Moonberry Tulip!
        sim.plots[2].stage = .ripe(RipePlant(kind: .strawberry, variant: 0, yieldLeft: 3))
        guard let orbTap = sim.pollenOrbPos(plot: 0), let anchor2 = sim.pollenAnchor(plot: 2) else {
            return XCTFail("Expected pollen orb and partner anchor for 1-tap pollination")
        }
        sim.handBegan(orbTap)
        sim.handEnded(orbTap, tap: true)
        XCTAssertTrue(sim.isPollinatingTapMode)

        sim.handBegan(anchor2)
        sim.handEnded(anchor2, tap: true)
        sim.drainEffectsForTesting()
        XCTAssertFalse(sim.isPollinatingTapMode)
        XCTAssertEqual(sim.plots[2].plant?.hybrid, .moonberryTulip)
        XCTAssertNotNil(sim.bee)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 10)

        // Verify the remaining 4 hybrid recipes & no double-discovery coins.
        XCTAssertNil(sim.crossBreed(from: .tulip, ontoPlot: 1), "Already-hybrid plot cannot be re-hybridized")
        let remainingPairs: [(PlantKind, PlantKind, HybridKind)] = [
            (.lavender, .sunflower, .cottonSunflower),
            (.sunflower, .lavender, .rainbowLavender),
            (.daisy, .pumpkin, .crystalPumpkin),
            (.tomato, .strawberry, .sparkleBerryVine),
        ]
        for (donor, target, expected) in remainingPairs {
            sim.plots[3].stage = .ripe(RipePlant(kind: target, variant: 0, yieldLeft: target.crop))
            XCTAssertEqual(sim.crossBreed(from: donor, ontoPlot: 3), expected)
        }
        sim.drainEffectsForTesting()
        XCTAssertEqual(Set(sim.discoveredHybrids), Set(HybridKind.allCases))
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 30)

        // Verify hybrid harvests produce typed HarvestItems.
        let rose = sim.harvest(1)
        XCTAssertEqual(rose?.source, .hybrid(kind: .starlightRose, isGiant: false))
        sim.plots[4].stage = .ripe(RipePlant(kind: .pumpkin, variant: 0, yieldLeft: 1, isGiant: false, hybrid: .crystalPumpkin))
        let crystal = sim.harvest(4)
        XCTAssertEqual(crystal?.source, .hybrid(kind: .crystalPumpkin, isGiant: false))

        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(GardenSave.self, from: data)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.discoveredHybrids, sim.discoveredHybrids)
    }

    // MARK: Critter Farmstand & Bouquet / Jam / Basket Studio

    func testFarmstandOrderGeneratorBiasesInventoryAndNeverRequiresTreasures() {
        let flowerStock = [
            HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .daisy, variant: 1, isGiant: false)),
        ]
        let bouquetOrder = FarmstandOrderGenerator.nextOrder(inventory: flowerStock, servedCount: 0, previousCustomer: nil, seed: 0)
        XCTAssertEqual(bouquetOrder.kind, .bouquet)
        XCTAssertTrue(FarmstandMatcher.canFulfill(order: bouquetOrder, with: flowerStock))

        let produceStock = [
            HarvestItem(source: .plant(kind: .strawberry, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .tomato, variant: 0, isGiant: false)),
        ]
        let produceOrder = FarmstandOrderGenerator.nextOrder(inventory: produceStock, servedCount: 1, previousCustomer: bouquetOrder.customer, seed: 1)
        XCTAssertNotEqual(produceOrder.kind, .bouquet)
        XCTAssertNotEqual(produceOrder.customer, bouquetOrder.customer)
        XCTAssertTrue(FarmstandMatcher.canFulfill(order: produceOrder, with: produceStock))
        XCTAssertTrue((2...3).contains(produceOrder.requirements.count))
    }

    func testFarmstandGreedyOneToOneSlotMatching() {
        let tulip = HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false))
        let daisy = HarvestItem(source: .plant(kind: .daisy, variant: 0, isGiant: false))
        let carrot = HarvestItem(source: .plant(kind: .carrot, variant: 0, isGiant: false))

        // Order puts broad requirement before specific requirement; specificity sorting must match BOTH.
        let reqs: [HarvestRequirement] = [.anyFlower, .species(.tulip)]
        let both = FarmstandMatcher.match(requirements: reqs, items: [tulip, daisy])
        XCTAssertEqual(both.slotMatched, [true, true])
        XCTAssertTrue(both.allMatched)

        // Single tulip must match at most 1 slot (strict 1-to-1).
        let single = FarmstandMatcher.match(requirements: reqs, items: [tulip])
        XCTAssertEqual(single.matchedCount, 1)
        XCTAssertFalse(single.allMatched)

        // Wrong kind matches 0 flower slots.
        let wrong = FarmstandMatcher.match(requirements: reqs, items: [carrot])
        XCTAssertEqual(wrong.matchedCount, 0)
        XCTAssertFalse(wrong.allMatched)
    }

    func testBouquetStudioSingleOwnershipSpritzServingAndCelebration() {
        let sim = freshSim()
        let tulip = HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false))
        let daisy = HarvestItem(source: .plant(kind: .daisy, variant: 1, isGiant: false))
        sim.inventory = [tulip, daisy]
        let order = FarmstandOrder(customer: .bunny, kind: .bouquet, requirements: [.species(.tulip), .anyFlower])
        sim.farmstandPhase = .crafting(order: order, draft: FarmstandDraft())
        sim.setStation(.farmstand)

        // Single ownership: adding to draft removes from inventory; removing returns to inventory.
        XCTAssertTrue(sim.addStockItemToDraft(tulip.id))
        XCTAssertEqual(sim.inventory.count, 1)
        XCTAssertEqual(sim.activeDraft?.items.map(\.id), [tulip.id])

        XCTAssertTrue(sim.removeDraftItem(id: tulip.id))
        XCTAssertEqual(sim.inventory.count, 2)
        XCTAssertTrue(sim.activeDraft?.items.isEmpty ?? false)

        // Re-add both blooms, customize wrap/ribbon, spritz dew -> 3 stars!
        XCTAssertTrue(sim.addStockItemToDraft(tulip.id))
        XCTAssertTrue(sim.addStockItemToDraft(daisy.id))
        XCTAssertTrue(sim.inventory.isEmpty)
        sim.selectWrap(.starryLavender)
        sim.selectRibbon(.butterYellow)
        XCTAssertEqual(sim.activeDraft?.wrap, .starryLavender)
        XCTAssertEqual(sim.activeDraft?.ribbon, .butterYellow)

        // 1-tap spritz bottle parity
        sim.spritzBouquetDew()
        XCTAssertTrue(sim.activeDraft?.dewSpritzed ?? false)

        let coinsBefore = Coins.shared.balance
        let stars = sim.serveFarmstandOrder()
        XCTAssertEqual(stars, 3)
        XCTAssertEqual(sim.farmstandServedCount, 1)
        XCTAssertTrue(sim.inventory.isEmpty, "Served bouquet items must be consumed permanently")
        if case .celebrating(let cel) = sim.farmstandPhase {
            XCTAssertEqual(cel.customer, .bunny)
            XCTAssertEqual(cel.stars, 3)
            XCTAssertEqual(cel.coinsAwarded, Coins.reward(stars: 3))
        } else {
            XCTFail("Expected celebrating phase after serving")
        }

        // Deferred outbox flushes coins + customer sticker cleanly.
        XCTAssertEqual(Coins.shared.balance, coinsBefore, "Coins should flush post-frame via Outbox")
        sim.drainEffectsForTesting()
        XCTAssertEqual(Coins.shared.balance, coinsBefore + Coins.reward(stars: 3))
        XCTAssertTrue(StickerBook.shared.has(game: GardenSim.gameID, id: GardenFind.bunny.rawValue))

        // Celebration finishes after 2.4s and welcomes a new customer order.
        run(sim, seconds: 2.6)
        if case .crafting(let nextOrder, _) = sim.farmstandPhase {
            XCTAssertNotEqual(nextOrder.customer, .bunny)
        } else {
            XCTFail("Expected new order after celebration finishes")
        }
    }

    func testJamPressThreeTapAndDragPlungerGinghamLidAndScoring() {
        let sim = freshSim()
        let berry = HarvestItem(source: .plant(kind: .strawberry, variant: 0, isGiant: false))
        let tomato = HarvestItem(source: .plant(kind: .tomato, variant: 1, isGiant: false))
        sim.inventory = [berry, tomato]
        let order = FarmstandOrder(customer: .hedgehog, kind: .jamJar, requirements: [.species(.strawberry), .anyFruitOrVeggie])
        sim.farmstandPhase = .crafting(order: order, draft: FarmstandDraft())
        sim.setStation(.farmstand)

        XCTAssertTrue(sim.addStockItemToDraft(berry.id))
        XCTAssertTrue(sim.addStockItemToDraft(tomato.id))
        sim.selectLid(.blueberryGingham)
        XCTAssertEqual(sim.activeDraft?.lid, .blueberryGingham)

        // 3 taps reach pressProgress == 1.0
        sim.pressJamPlunger()
        XCTAssertGreaterThan(sim.activeDraft?.pressProgress ?? 0, 0.3)
        sim.pressJamPlunger()
        XCTAssertGreaterThan(sim.activeDraft?.pressProgress ?? 0, 0.65)
        sim.pressJamPlunger()
        XCTAssertEqual(sim.activeDraft?.pressProgress ?? 0, 1.0, accuracy: 0.001)

        let stars = sim.serveFarmstandOrder()
        sim.drainEffectsForTesting()
        XCTAssertEqual(stars, 3)
        XCTAssertEqual(Coins.shared.balance, Coins.reward(stars: 3))
        XCTAssertTrue(StickerBook.shared.has(game: GardenSim.gameID, id: GardenFind.hedgehog.rawValue))
    }

    func testFarmBasketGiantHeroSlotAndGentleStarBonus() {
        let giantPumpkin = HarvestItem(source: .plant(kind: .pumpkin, variant: 0, isGiant: true))
        let carrot = HarvestItem(source: .plant(kind: .carrot, variant: 0, isGiant: false))
        let tomato = HarvestItem(source: .plant(kind: .tomato, variant: 0, isGiant: false))

        let draft = FarmstandDraft(items: [carrot, giantPumpkin, tomato])
        let slots = draft.arrangedBasketSlots()
        XCTAssertEqual(slots[1]?.id, giantPumpkin.id, "Giant pumpkin must sit in the center hero slot")

        let order = FarmstandOrder(customer: .frog, kind: .farmBasket, requirements: [.species(.carrot), .species(.pumpkin)])
        // Mismatched/partial without giant -> gentle minimum 1 star
        XCTAssertEqual(FarmstandScoring.evaluate(order: order, draft: FarmstandDraft(items: [tomato])), 1)
        // Partial + giant -> +1 star bonus = 2 stars
        XCTAssertEqual(FarmstandScoring.evaluate(order: order, draft: FarmstandDraft(items: [giantPumpkin])), 2)
        // All matched without giant/extra -> 2 stars
        let normalPumpkin = HarvestItem(source: .plant(kind: .pumpkin, variant: 0, isGiant: false))
        XCTAssertEqual(FarmstandScoring.evaluate(order: order, draft: FarmstandDraft(items: [carrot, normalPumpkin])), 2)
        // All matched + giant -> 3 stars!
        XCTAssertEqual(FarmstandScoring.evaluate(order: order, draft: FarmstandDraft(items: [carrot, giantPumpkin])), 3)
    }

    func testStockItemDragSingleOwnershipPreservesItemOnCancelAndDropsIntoCraft() {
        let sim = freshSim()
        let tulip = HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false))
        sim.inventory = [tulip]
        let order = FarmstandOrder(customer: .bluebird, kind: .bouquet, requirements: [.species(.tulip), .anyFlower])
        sim.farmstandPhase = .crafting(order: order, draft: FarmstandDraft())
        sim.setStation(.farmstand)

        // Drag and release far outside craft zone -> returns cleanly to inventory without duplication.
        XCTAssertTrue(sim.beginStockItemDrag(tulip.id, finger: CGPoint(x: 400, y: 740)))
        XCTAssertTrue(sim.inventory.isEmpty)
        sim.moveStockItemDrag(finger: CGPoint(x: 120, y: 740))
        sim.endStockItemDrag(finger: CGPoint(x: 120, y: 740))
        XCTAssertEqual(sim.inventory.map(\.id), [tulip.id])
        XCTAssertTrue(sim.activeDraft?.items.isEmpty ?? false)

        // Drag and release onto craft zone -> lands in draft!
        let fingerForCraft = GardenSim.fingerPoint(for: GGeo.Farmstand.craftCenter, lift: FingerLift.item)
        XCTAssertTrue(sim.beginStockItemDrag(tulip.id, finger: CGPoint(x: 400, y: 740)))
        sim.moveStockItemDrag(finger: fingerForCraft)
        sim.endStockItemDrag(finger: fingerForCraft)
        XCTAssertTrue(sim.inventory.isEmpty)
        XCTAssertEqual(sim.activeDraft?.items.map(\.id), [tulip.id])
    }

    func testFarmstandOrdersUpgradeTreehouseAndPersistAllG1Fields() throws {
        let sim = freshSim()
        XCTAssertEqual(sim.treehouseStage, 0)

        for n in 1...10 {
            let tulip = HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false))
            sim.inventory = [tulip]
            let order = FarmstandOrder(customer: .owl, kind: .bouquet, requirements: [.species(.tulip)])
            sim.farmstandPhase = .crafting(order: order, draft: FarmstandDraft())
            XCTAssertTrue(sim.addStockItemToDraft(tulip.id))
            XCTAssertNotNil(sim.serveFarmstandOrder())
            XCTAssertEqual(sim.farmstandServedCount, n)
            XCTAssertEqual(sim.treehouseStage, min(GardenSim.maxTreehouseStage, n / 2))
            sim.advanceToNextOrder(previousCustomer: .owl)
        }
        XCTAssertEqual(sim.treehouseStage, GardenSim.maxTreehouseStage)

        // Save with a giant pumpkin in inventory + active order and verify full round-trip.
        let giant = HarvestItem(source: .plant(kind: .pumpkin, variant: 0, isGiant: true))
        sim.inventory = [giant]
        let saved = sim.makeSave()
        let encoded = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(GardenSave.self, from: encoded)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.farmstandServedCount, 10)
        XCTAssertEqual(restored.treehouseStage, 5)
        XCTAssertEqual(restored.inventory.first?.isGiant, true)
        XCTAssertEqual(restored.activeOrder?.id, sim.activeOrder?.id)
    }

    // MARK: Backyard Visitors, Picnic & Crowns Consume Real Inventory

    func testVisitorWishConsumesRealInventoryItemNoInfiniteCarrotExploit() {
        let sim = freshSim()
        sim.decor = []
        sim.inventory = []
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.plots[1].stage = .ripe(RipePlant(kind: .carrot, variant: 0, yieldLeft: 1))
        sim.nextVisit = 0
        run(sim, seconds: 10)
        guard let bunny = sim.visitors.first(where: { $0.kind == .bunny }) else {
            return XCTFail("Expected bunny to visit ripe carrot")
        }
        let tapPt = CGPoint(x: bunny.pos.x, y: bunny.pos.y - 30)
        let coinsBefore = Coins.shared.balance

        // Without a carrot in inventory, tapping bunny wiggles without fulfillment or coins.
        XCTAssertTrue(sim.tapVisitor(tapPt))
        sim.drainEffectsForTesting()
        XCTAssertFalse(sim.visitors.first(where: { $0.kind == .bunny })?.fulfilled ?? true)
        XCTAssertEqual(Coins.shared.balance, coinsBefore)

        // Put 1 carrot in inventory -> tapping bunny consumes that carrot, unlocks sticker, awards 3 coins.
        sim.inventory = [HarvestItem(source: .plant(kind: .carrot, variant: 0, isGiant: false))]
        XCTAssertTrue(sim.tapVisitor(tapPt))
        sim.drainEffectsForTesting()
        XCTAssertTrue(sim.visitors.first(where: { $0.kind == .bunny })?.fulfilled ?? false)
        XCTAssertTrue(sim.inventory.isEmpty, "Feeding bunny must consume the real carrot from inventory")
        XCTAssertTrue(StickerBook.shared.has(game: GardenSim.gameID, id: GardenFind.bunny.rawValue))
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)

        // A second bunny arriving cannot be fed when inventory is empty (no 1-carrot exploit).
        var bunny2 = GVisitor(kind: .bunny, p: CGPoint(x: 340, y: GGeo.yardY + 8), facing: 1)
        bunny2.state = .staying
        bunny2.stayUntil = sim.time + 30
        sim.visitors = [bunny2]
        let tap2 = CGPoint(x: bunny2.pos.x, y: bunny2.pos.y - 30)
        XCTAssertTrue(sim.tapVisitor(tap2))
        sim.drainEffectsForTesting()
        XCTAssertFalse(sim.visitors[0].fulfilled)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)
    }

    func testBasketDragFeedsVisitorConsumingItem() {
        let sim = freshSim()
        sim.decor = []
        sim.inventory = [HarvestItem(source: .plant(kind: .carrot, variant: 0, isGiant: false))]
        var bunny = GVisitor(kind: .bunny, p: CGPoint(x: 320, y: GGeo.yardY + 8), facing: 1)
        bunny.state = .staying
        bunny.stayUntil = 30
        sim.visitors = [bunny]

        let coinsBefore = Coins.shared.balance
        sim.handBegan(GGeo.basket)
        let target = CGPoint(x: bunny.pos.x, y: bunny.pos.y - 30)
        sim.handMoved(target)
        sim.handEnded(target, tap: false)
        sim.drainEffectsForTesting()

        XCTAssertTrue(sim.visitors.first?.fulfilled ?? false)
        XCTAssertTrue(sim.inventory.isEmpty)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)
    }

    func testNobodyVisitsWhenThereIsNothingForThem() {
        let sim = freshSim()
        sim.decor = []
        sim.inventory = []
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

    func testCritterPicnicConsumesRealProduceAndUpgradesTreehouse() throws {
        let sim = freshSim()
        let produceKinds: [HarvestSource] = [
            .plant(kind: .carrot, variant: 0, isGiant: false),
            .plant(kind: .strawberry, variant: 0, isGiant: false),
            .plant(kind: .tomato, variant: 0, isGiant: false),
            .plant(kind: .pumpkin, variant: 0, isGiant: false),
            .hybrid(kind: .crystalPumpkin, isGiant: false),
            .plant(kind: .carrot, variant: 1, isGiant: false),
            .plant(kind: .strawberry, variant: 1, isGiant: false),
            .plant(kind: .tomato, variant: 1, isGiant: false),
            .plant(kind: .pumpkin, variant: 1, isGiant: false),
            .hybrid(kind: .sparkleBerryVine, isGiant: false),
            .plant(kind: .carrot, variant: 2, isGiant: false),
        ]
        sim.inventory = produceKinds.map { HarvestItem(source: $0) }
        XCTAssertEqual(sim.treehouseStage, 0)

        let coinsBefore = Coins.shared.balance
        sim.handBegan(GGeo.basket)
        sim.handMoved(GGeo.picnic)
        sim.handEnded(GGeo.picnic, tap: false)
        sim.drainEffectsForTesting()

        XCTAssertEqual(sim.picnicFeedCount, 1)
        XCTAssertEqual(sim.inventory.count, 10)
        XCTAssertEqual(sim.picnicCritters.count, 1)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)

        sim.handBegan(GGeo.picnic)
        sim.handEnded(GGeo.picnic, tap: true)
        XCTAssertEqual(sim.picnicFeedCount, 2)
        XCTAssertEqual(sim.treehouseStage, 1)

        for expectedStage in 2...5 {
            XCTAssertTrue(sim.servePicnicSnack())
            XCTAssertTrue(sim.servePicnicSnack())
            XCTAssertEqual(sim.treehouseStage, expectedStage)
        }
        XCTAssertTrue(sim.servePicnicSnack())
        XCTAssertEqual(sim.treehouseStage, GardenSim.maxTreehouseStage)
        XCTAssertFalse(sim.servePicnicSnack(), "Cannot serve picnic when produce inventory is empty")

        let dockRight: CGFloat = 512 + 196
        let picnicLeft = GGeo.picnic.x - GGeo.picnicSize.width / 2
        XCTAssertGreaterThan(picnicLeft, dockRight + 20)
        XCTAssertGreaterThan(GGeo.picnic.y - GGeo.picnicSize.height / 2, GGeo.bedBottom + 20)
    }

    func testWeaveFlowerCrownConsumesThreeFlowersAndPlacesOnCritters() {
        let sim = freshSim()
        sim.inventory = [
            HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .daisy, variant: 1, isGiant: false)),
        ]
        XCTAssertFalse(sim.weaveFlowerCrown())
        XCTAssertFalse(sim.hasCraftedCrown)

        sim.inventory.append(HarvestItem(source: .hybrid(kind: .cottonSunflower, isGiant: false)))
        let vaseTap = CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 40)
        sim.handBegan(vaseTap)
        sim.handEnded(vaseTap, tap: true)
        XCTAssertTrue(sim.hasCraftedCrown)
        XCTAssertEqual(sim.craftedCrownColors.count, 5)
        XCTAssertTrue(sim.inventory.isEmpty, "Weaving a flower crown must consume 3 real flowers")

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
        sim.drainEffectsForTesting()

        XCTAssertTrue(sim.visitors[0].wearingCrown)
        XCTAssertFalse(sim.hasCraftedCrown)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 3)

        sim.inventory = [
            HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .lavender, variant: 0, isGiant: false)),
            HarvestItem(source: .hybrid(kind: .starlightRose, isGiant: false)),
            HarvestItem(source: .plant(kind: .strawberry, variant: 0, isGiant: false)),
        ]
        XCTAssertTrue(sim.weaveFlowerCrown())
        XCTAssertTrue(sim.servePicnicSnack())
        XCTAssertTrue(sim.placeCrownOnNearestCritter())
        XCTAssertTrue(sim.picnicCritters.first?.wearingCrown ?? false)
        XCTAssertFalse(sim.hasCraftedCrown)
    }

    // MARK: Safe Decor, Rare Variants, Stickers, Treasures, Seasons & Legacy Save Migration

    func testSafeDecorPlacementPriorityAndReturnDropBadge() {
        let sim = freshSim()
        sim.decor = []
        let first = sim.placeDecorOnFreeSpot(.pinwheel)
        let second = sim.placeDecorOnFreeSpot(.mushroom)
        XCTAssertGreaterThan(abs(sim.decor[first].x - sim.decor[second].x), 80)

        let x = GGeo.plotX[2]
        sim.decor = []
        sim.addDecor(.birdhouse, x: x, falling: false)
        sim.plots[2].stage = .ripe(RipePlant(kind: .tomato, variant: 0, yieldLeft: 3))
        let tap = CGPoint(x: x, y: sim.surface(x) - 96)
        sim.handBegan(tap)
        sim.handEnded(tap, tap: true)
        XCTAssertEqual(sim.plots[2].plant?.left, 2)
        XCTAssertFalse(sim.decor[0].held)

        sim.plots[2].plant = nil
        let grabPt = CGPoint(x: sim.decor[0].x, y: sim.decor[0].y - 60)
        sim.handBegan(grabPt)
        XCTAssertTrue(sim.isDraggingDecor)
        sim.handMoved(CGPoint(x: 420, y: 780))
        XCTAssertFalse(sim.overReturnBadge)
        sim.handEnded(CGPoint(x: 420, y: 780), tap: false)
        XCTAssertEqual(sim.decor.count, 1)

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
            sim.plots[i].stage = .ripe(RipePlant(kind: .sunflower, variant: i % 6, yieldLeft: 1))
        }
        let idx = sim.placeDecorOnFreeSpot(.mushroom)
        let d = sim.decor[idx]
        for px in GGeo.plotX {
            XCTAssertGreaterThanOrEqual(abs(d.x - px), 48)
        }
        let grabPt = CGPoint(x: d.x, y: d.y - 24)
        sim.handBegan(grabPt)
        XCTAssertTrue(sim.isDraggingDecor)
        sim.handEnded(grabPt, tap: false)
    }

    func testBasketClearOfTrayBar() {
        let trayBottom = GGeo.trayY + 46
        let basketTop = GGeo.basket.y - 49
        XCTAssertGreaterThan(basketTop, trayBottom + 16)
    }

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

    func testAllFourTreasureShopUnlocks() throws {
        let expectedIDs: [(DecorKind, String)] = [
            (.crystal, "garden/crystal"),
            (.rainbow, "garden/rainbow"),
            (.unicorn, "garden/unicorn"),
            (.lotus, "garden/lotus"),
        ]
        XCTAssertEqual(DecorKind.available.count, 8)
        Coins.shared.resetForTests(balance: 100)
        for (kind, id) in expectedIDs {
            XCTAssertEqual(kind.treasure, id)
            XCTAssertFalse(DecorKind.available.contains(kind))
            XCTAssertTrue(Coins.shared.buy(id, price: 10))
            XCTAssertTrue(DecorKind.available.contains(kind))
        }
        XCTAssertEqual(DecorKind.available.count, 12)

        let sim = freshSim()
        sim.decor = []
        _ = sim.placeDecorOnFreeSpot(.lotus)
        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(GardenSave.self, from: data)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.decor.map(\.kind), [.lotus])
    }

    func testSaveRoundTripLegacyMigrationAndBrokenPlotSelfHeal() throws {
        let sim = freshSim()
        sim.showcase()
        let saved = sim.makeSave()
        let encoded = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(GardenSave.self, from: encoded)
        XCTAssertEqual(decoded, saved)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.plots.map(\.plant), sim.plots.map(\.plant))
        XCTAssertEqual(restored.inventory, sim.inventory)
        XCTAssertEqual(restored.decor.count, sim.decor.count)
        XCTAssertTrue(restored.plots[5].plant?.giant ?? false)

        // Legacy garden.json: 224 soil columns, no harvestInventory, overlapping basket+bouquet flower,
        // unique bouquet flower, and a broken ripe plot with growth=1.0 & left=0 that must self-heal to .empty!
        let legacySoil = Array(repeating: 548.0, count: 224)
        let legacyWet = Array(repeating: 0.4, count: 224)
        let legacyJSON = """
        {
          "plots": [
            {"kind": "sunflower", "growth": 0.9, "left": 0, "variant": 1},
            {"kind": "tulip", "growth": 1.0, "left": 0, "variant": 0},
            {"kind": "pumpkin", "growth": 1.0, "left": 1, "variant": 0},
            null,
            null,
            null
          ],
          "soil": \(legacySoil),
          "wet": \(legacyWet),
          "weeds": [{"x": 350.0, "growth": 0.6, "seed": 4}],
          "decor": [{"kind": "pinwheel", "x": 220.0, "water": 0.0}],
          "basket": ["carrot:0", "tulip:2"],
          "bouquet": [
            {"kind": "tulip", "variant": 2},
            {"kind": "daisy", "variant": 1}
          ],
          "weather": "sun",
          "stamps": [{"kind": "tulip", "variant": 0, "x": 0.5, "y": 0.5}],
          "channels": [1, 2, 3]
        }
        """
        let legacySave = try JSONDecoder().decode(GardenSave.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(legacySave.harvestInventory)
        let migrated = GardenSim(save: legacySave)
        XCTAssertEqual(migrated.plots[0].plant?.kind, .sunflower)
        XCTAssertTrue(migrated.plots[1].isEmpty, "Broken legacy plot (growth >= 1 && left <= 0) must self-heal to .empty")
        XCTAssertEqual(migrated.plots[2].plant?.kind, .pumpkin)
        XCTAssertFalse(migrated.plots[2].plant?.giant ?? true)
        // carrot:0 + tulip:2 (deduped against bouquet!) + daisy:1 (preserved from bouquet!) == 3 items total.
        XCTAssertEqual(migrated.inventory.count, 3)
        XCTAssertEqual(migrated.inventory.map(\.source), [
            .plant(kind: .carrot, variant: 0, isGiant: false),
            .plant(kind: .tulip, variant: 2, isGiant: false),
            .plant(kind: .daisy, variant: 1, isGiant: false),
        ])
        XCTAssertEqual(migrated.decor.count, 1)
        XCTAssertEqual(migrated.h.count, GGeo.columns)
        XCTAssertEqual(migrated.wet.count, GGeo.columns)
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

        sim.handBegan(CGPoint(x: 240, y: 260))
        sim.handMoved(CGPoint(x: 340, y: 240))
        sim.handMoved(CGPoint(x: 420, y: 210))
        sim.handEnded(CGPoint(x: 420, y: 210), tap: false)
        XCTAssertNotNil(sim.vortexCenter)
        XCTAssertGreaterThan(sim.vortexUntil, sim.time)

        sim.plots[2].stage = .ripe(RipePlant(kind: .tulip, variant: 0, yieldLeft: 1))
        sim.setWeather(.rain)
        sim.setWeather(.sun)
        XCTAssertTrue(sim.plots[2].plant?.rainbowCharged ?? false)
        let coinsBefore = Coins.shared.balance
        sim.harvest(2)
        sim.drainEffectsForTesting()
        XCTAssertEqual(Coins.shared.balance, coinsBefore + 2)
        XCTAssertTrue(sim.plots[2].isEmpty)

        sim.setWeather(.night)
        sim.settleWeather()
        let flyPos = CGPoint(x: 420, y: 310)
        sim.fireflies = [GFirefly(p: flyPos, v: .zero, phase: 0)]
        sim.handBegan(flyPos)
        sim.handEnded(flyPos, tap: true)
        XCTAssertEqual(sim.caughtFireflies, 1)
        XCTAssertTrue(sim.fireflies.isEmpty)

        sim.setSeason(.autumn)
        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(GardenSave.self, from: data)
        let restored = GardenSim(save: decoded)
        XCTAssertEqual(restored.season, .autumn)
        XCTAssertEqual(restored.caughtFireflies, 1)

        let jarTap = CGPoint(x: GGeo.fireflyJar.x, y: GGeo.fireflyJar.y - 20)
        sim.handBegan(jarTap)
        sim.handEnded(jarTap, tap: true)
        XCTAssertEqual(sim.caughtFireflies, 0)
        XCTAssertEqual(sim.fireflies.count, 1)
    }

    func testEverySoundIsBundled() {
        for s in GardenSFX.allCases {
            let url = GameFiles.url(s.rawValue, "caf", game: "Garden") ?? GameFiles.url(s.rawValue, "wav", game: "Garden")
            XCTAssertNotNil(url, s.rawValue)
        }
    }

    // MARK: Adversarial Review Regressions

    func testStockDragKeepsUIStateExposedAndCancelRestoresOrder() {
        let sim = freshSim()
        let tulip = HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false))
        let daisy = HarvestItem(source: .plant(kind: .daisy, variant: 1, isGiant: false))
        sim.inventory = [tulip, daisy]
        let order = FarmstandOrder(customer: .bunny, kind: .bouquet, requirements: [.species(.tulip), .anyFlower])
        sim.farmstandPhase = .crafting(order: order, draft: FarmstandDraft())
        sim.setStation(.farmstand)

        XCTAssertTrue(sim.beginStockItemDrag(tulip.id, finger: CGPoint(x: 420, y: 740)))
        let midUI = sim.currentUIState()
        XCTAssertEqual(midUI.inventory.map(\.id), [daisy.id])
        XCTAssertEqual(midUI.draggedStockItem?.id, tulip.id)
        XCTAssertTrue(midUI.orderReadyInInventory)

        sim.cancelStockItemDrag()
        let afterCancel = sim.currentUIState()
        XCTAssertNil(afterCancel.draggedStockItem)
        XCTAssertEqual(afterCancel.inventory.map(\.id), [tulip.id, daisy.id])

        // Single-item inventory drag stays exposed in UI state until endStockItemDrag lands in draft.
        sim.inventory = [tulip]
        XCTAssertTrue(sim.beginStockItemDrag(tulip.id, finger: CGPoint(x: 420, y: 740)))
        XCTAssertTrue(sim.currentUIState().inventory.isEmpty)
        XCTAssertEqual(sim.currentUIState().draggedStockItem?.id, tulip.id)
        let fingerForCraft = GardenSim.fingerPoint(for: GGeo.Farmstand.craftCenter, lift: FingerLift.item)
        sim.endStockItemDrag(finger: fingerForCraft)
        XCTAssertNil(sim.currentUIState().draggedStockItem)
        XCTAssertEqual(sim.activeDraft?.items.map(\.id), [tulip.id])
    }

    func testPlacedTallDecorDropsOntoReturnBadgeViaSceneDrag() {
        let sim = freshSim()
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.decor = []
        sim.addDecor(.birdhouse, x: 500, falling: false)

        let grabPt = CGPoint(x: sim.decor[0].x, y: sim.decor[0].y - 60)
        sim.handleSceneDragChanged(grabPt, startLocation: grabPt, dt: 1.0 / 60)
        XCTAssertTrue(sim.isDraggingDecor)

        sim.handleSceneDragChanged(GGeo.returnBadge, startLocation: grabPt, dt: 1.0 / 60)
        XCTAssertTrue(sim.overReturnBadge)

        sim.handleSceneDragEnded(GGeo.returnBadge, startLocation: grabPt, duration: 0.6)
        XCTAssertTrue(sim.decor.isEmpty)
        XCTAssertFalse(sim.overReturnBadge)
    }

    func testAutoShovelStrictSingleActionNeverUprootsHealthyPlantOnWeedOrMysteryBulb() {
        // Case A: Full 6-plot bed + 1 weed -> rubbing mid-autoShovel never pops early or uproots a plant.
        let sim = freshSim()
        for i in sim.plots.indices {
            sim.plots[i].stage = .ripe(RipePlant(kind: .tulip, variant: i % 6, yieldLeft: 1))
        }
        let weedX = GGeo.plotX[2] + 16
        sim.weeds = [GWeed(x: weedX, growth: 1.0, seed: 5)]

        let targetA = sim.bestShovelTarget()
        sim.pickUp(.shovel, at: targetA)
        sim.autoShovelActive = true
        for k in 0..<78 {
            let ang = CGFloat(k) / 78 * 4 * .pi
            sim.carry(to: CGPoint(x: targetA.x + sin(ang) * 20, y: targetA.y + cos(ang) * 12))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertEqual(sim.weeds.count, 1)
        XCTAssertTrue(sim.plots.allSatisfy { !$0.isEmpty })

        sim.autoShovel(at: targetA)
        sim.release(home: CGPoint(x: 371, y: GGeo.dockY))
        XCTAssertTrue(sim.weeds.isEmpty)
        XCTAssertTrue(sim.plots.allSatisfy { !$0.isEmpty })

        // Case B: 5 healthy plants + 1 empty plot with mystery bulb -> unearths once and spares all 5 plants.
        let simB = freshSim()
        simB.weeds = []
        for i in 0..<5 {
            simB.plots[i].stage = .ripe(RipePlant(kind: .daisy, variant: i % 6, yieldLeft: 2))
        }
        simB.plots[5].stage = .empty(surprise: .mysteryBulb, surpriseReady: true)

        let targetB = simB.bestShovelTarget()
        simB.pickUp(.shovel, at: targetB)
        simB.autoShovelActive = true
        for k in 0..<78 {
            let ang = CGFloat(k) / 78 * 4 * .pi
            simB.carry(to: CGPoint(x: targetB.x + sin(ang) * 18, y: targetB.y + cos(ang) * 10))
            simB.step(dt: 1.0 / 60)
        }
        XCTAssertTrue(simB.plots[5].isEmpty)

        simB.autoShovel(at: targetB)
        simB.release(home: CGPoint(x: 371, y: GGeo.dockY))
        XCTAssertTrue(simB.plots[5].plant?.isSpecial ?? false)
        for i in 0..<5 {
            XCTAssertEqual(simB.plots[i].plant?.kind, .daisy)
        }
    }

    func testJamPressMilestonesCarrotPollenOrderBalanceAndRarePumpkinDecoupling() {
        // 1) Smooth plunger drag fires discrete milestones instead of per-pixel particle spam.
        let sim = freshSim()
        let berry = HarvestItem(source: .plant(kind: .strawberry, variant: 0, isGiant: false))
        sim.inventory = [berry]
        let jamOrder = FarmstandOrder(customer: .hedgehog, kind: .jamJar, requirements: [.species(.strawberry)])
        sim.farmstandPhase = .crafting(order: jamOrder, draft: FarmstandDraft())
        sim.setStation(.farmstand)
        XCTAssertTrue(sim.addStockItemToDraft(berry.id))
        sim.farmstandParticles.removeAll()

        for step in 1...50 {
            sim.setJamPressProgress(CGFloat(step) / 50.0)
        }
        XCTAssertEqual(sim.activeDraft?.pressProgress ?? 0, 1.0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(sim.farmstandParticles.count, 50)
        XCTAssertGreaterThanOrEqual(sim.farmstandParticles.count, 28)

        // 2) Ripe carrot pollen orb has priority over carrot pull-up grab.
        let simP = freshSim()
        for i in simP.plots.indices { simP.plots[i].plant = nil }
        simP.plots[1].stage = .ripe(RipePlant(kind: .carrot, variant: 0, yieldLeft: 1))
        simP.plots[4].stage = .ripe(RipePlant(kind: .tulip, variant: 0, yieldLeft: 1))
        guard let carrotOrb = simP.pollenOrbPos(plot: 1), let tulipAnchor = simP.pollenAnchor(plot: 4) else {
            return XCTFail("Expected carrot pollen orb and tulip anchor")
        }
        simP.handBegan(carrotOrb)
        XCTAssertEqual(simP.dragPollenFromPlot, 1)
        XCTAssertFalse(simP.plots[1].held)
        simP.handMoved(tulipAnchor)
        simP.handEnded(tulipAnchor, tap: false)
        XCTAssertEqual(simP.plots[1].plant?.kind, .carrot)
        XCTAssertNotNil(simP.plots[4].plant?.hybrid)

        // 3) Order generator balances surplus flower vs surplus produce vs equal counts.
        let f1 = HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false))
        let f2 = HarvestItem(source: .plant(kind: .daisy, variant: 0, isGiant: false))
        let f3 = HarvestItem(source: .plant(kind: .sunflower, variant: 0, isGiant: false))
        let p1 = HarvestItem(source: .plant(kind: .carrot, variant: 0, isGiant: false))
        let p2 = HarvestItem(source: .plant(kind: .tomato, variant: 0, isGiant: false))
        let p3 = HarvestItem(source: .plant(kind: .strawberry, variant: 0, isGiant: false))
        XCTAssertEqual(FarmstandOrderGenerator.nextOrder(inventory: [f1, f2, f3, p1, p2], servedCount: 1, seed: 1).kind, .bouquet)
        XCTAssertNotEqual(FarmstandOrderGenerator.nextOrder(inventory: [f1, f2, p1, p2, p3], servedCount: 0, seed: 0).kind, .bouquet)
        let equalKinds = Set((0..<3).map { FarmstandOrderGenerator.nextOrder(inventory: [f1, f2, p1, p2], servedCount: 0, seed: $0).kind })
        XCTAssertEqual(equalKinds, Set(FarmstandOrderKind.allCases))

        // 4) Rare-variant unpuffed pumpkin does NOT unlock giantPumpkin sticker until watered/puffed.
        let simG = freshSim()
        for i in simG.plots.indices { simG.plots[i].plant = nil }
        simG.plots[3].stage = .ripe(RipePlant(kind: .pumpkin, variant: Plant.specialVariant, yieldLeft: 1, isGiant: false))
        run(simG, seconds: 1.2)
        simG.drainEffectsForTesting()
        XCTAssertFalse(StickerBook.shared.has(game: GardenSim.gameID, id: GardenFind.giantPumpkin.rawValue))
        simG.waterPlant(at: CGPoint(x: GGeo.plotX[3], y: simG.surface(GGeo.plotX[3]) - 10))
        simG.drainEffectsForTesting()
        XCTAssertTrue(simG.plots[3].plant?.giant ?? false)
        XCTAssertTrue(StickerBook.shared.has(game: GardenSim.gameID, id: GardenFind.giantPumpkin.rawValue))

        // 5) Inventory total cap (inventory + draft) enforced on harvest without dropping draft items on save.
        let simCap = freshSim()
        simCap.inventory = (0..<58).map { HarvestItem(source: .plant(kind: .tulip, variant: $0 % 6, isGiant: false)) }
        let d1 = HarvestItem(source: .plant(kind: .daisy, variant: 0, isGiant: false))
        let d2 = HarvestItem(source: .plant(kind: .daisy, variant: 1, isGiant: false))
        let bOrder = FarmstandOrder(customer: .owl, kind: .bouquet, requirements: [.anyFlower, .anyFlower])
        simCap.farmstandPhase = .crafting(order: bOrder, draft: FarmstandDraft(items: [d1, d2]))
        simCap.plots[0].stage = .ripe(RipePlant(kind: .sunflower, variant: 0, yieldLeft: 1))
        XCTAssertNotNil(simCap.harvest(0))
        XCTAssertEqual(simCap.inventory.count + (simCap.activeDraft?.items.count ?? 0), GardenSim.maxInventory)
        let savedInv = simCap.makeSave().harvestInventory ?? []
        XCTAssertEqual(savedInv.count, GardenSim.maxInventory)
        XCTAssertTrue(savedInv.contains(where: { $0.id == d1.id }))
        XCTAssertTrue(savedInv.contains(where: { $0.id == d2.id }))
    }
}
