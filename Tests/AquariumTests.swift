import XCTest
@testable import Glimmie

final class AquariumTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Coins.shared.resetForTests()
    }

    private func freshSim() -> AquariumSim {
        let sim = AquariumSim(save: nil)
        sim.demo = true
        sim.fish = []
        sim.food = []
        sim.bubbles = []
        sim.hoops = []
        sim.decor = []
        sim.visitors = []
        sim.moss = AquaMossPatch.makeDefault()
        sim.pump = false
        return sim
    }

    private func run(_ sim: AquariumSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { sim.step(dt: 1.0 / 60) }
    }

    // MARK: - Feeding, Hungry Crumb Cues & Rewards

    func testFeedTapDropsAtSurfaceEvenWhenTankIsBusy() {
        let sim = freshSim()
        for _ in 0..<20 { sim.feed(at: CGPoint(x: 300, y: 500)) }
        sim.feed(at: CGPoint(x: 700, y: 500))
        XCTAssertEqual(sim.food.count, 48)
        XCTAssertTrue(sim.food.suffix(6).allSatisfy { abs($0.p.x - 700) <= 20 && $0.p.y < AGeo.waterY })
    }

    func testFoodFloatsThenSinksAndHungryFishEarnBabyFishAndCoins() {
        let sim = freshSim()
        sim.addFlake(at: CGPoint(x: 300, y: 80), v: .zero)
        run(sim, seconds: 0.5)
        XCTAssertEqual(sim.food.first?.state, .floating)
        run(sim, seconds: 3)
        XCTAssertEqual(sim.food.first?.state, .sinking)
        run(sim, seconds: 19)
        XCTAssertEqual(sim.food.first?.state, .settled)

        let hungry = freshSim()
        let idx = hungry.spawn(.goldfish, variant: 0, at: CGPoint(x: 500, y: 360))
        hungry.fish[idx].snackReadyAt = 0
        hungry.fish[idx].appetite = 5
        run(hungry, seconds: 0.6)
        XCTAssertGreaterThan(hungry.fish[idx].hungryCue, 0.25, "hungry fish displays playful crumb cue")
        XCTAssertTrue(hungry.anyHungry)

        for k in 0..<5 {
            hungry.addFlake(at: CGPoint(x: 515 + CGFloat(k) * 14, y: 350 + CGFloat(k % 2) * 10), v: .zero)
        }
        run(hungry, seconds: 8)
        XCTAssertLessThanOrEqual(hungry.food.count, 2, "fish swims over and eats at least 3 flakes")
        XCTAssertTrue(hungry.visitors.contains { $0.kind == .babyFish }, "feeding 3+ flakes spawns cheerful baby fish")
        XCTAssertEqual(Coins.shared.balance, 3, "feeding payoff awards 3 Play Coins")
    }

    func testTapDockFoodSprinklesFlakes() {
        let sim = freshSim()
        sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 420, y: 360))
        sim.tapDockFood()
        XCTAssertEqual(sim.food.count, 6)
        XCTAssertNotNil(sim.quickAction)
    }

    // MARK: - Underwater Bubble Hoop Toy

    func testBubbleHoopSpawnAndFishBarrelRollTrickEarnsCoins() {
        let sim = freshSim()
        let fIdx = sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 340, y: 360))
        sim.fish[fIdx].dir = 1
        sim.fish[fIdx].facing = 1

        sim.spawnBubbleHoop(at: CGPoint(x: 460, y: 360))
        XCTAssertEqual(sim.hoops.count, 1)

        run(sim, seconds: 4)
        XCTAssertGreaterThanOrEqual(sim.hoops.first?.tricks ?? 0, 1, "fish excitedly swims through the bubble hoop")
        XCTAssertGreaterThanOrEqual(sim.fish[fIdx].flipStart, 0, "fish performs a barrel-roll flip")
        XCTAssertEqual(Coins.shared.balance, 2, "clean hoop trick awards 2 Play Coins")
    }

    func testDraggingAndReleasingHoopDropsItInTank() {
        let sim = freshSim()
        sim.pickUp(.hoop, at: CGPoint(x: 512, y: 340))
        sim.carry(to: CGPoint(x: 512, y: 340), hand: CGPoint(x: 552, y: 436))
        sim.step(dt: 1.0 / 60)
        sim.release(home: CGPoint(x: 512, y: AGeo.dockY))
        XCTAssertEqual(sim.hoops.count, 1)
    }

    // MARK: - Smooth Moss & Magnetic Glass Wiper

    func testMagneticWiperCleansMossInvitesTurtleAndAwardsCoins() {
        let sim = freshSim()
        sim.moss[0].opacity = 0.65
        sim.moss[1].opacity = 0.65
        sim.moss[6].opacity = 0.65
        run(sim, seconds: 0.1)
        let before = sim.dirtiness
        XCTAssertGreaterThan(before, 0.14)

        sim.pickUp(.wiper, at: sim.moss[0].center)
        for patchIndex in [0, 1, 6] {
            let c = sim.moss[patchIndex].center
            for step in 0..<24 {
                let offset = CGFloat(step % 2 == 0 ? -18 : 18)
                sim.carry(to: CGPoint(x: c.x + offset, y: c.y))
                sim.step(dt: 1.0 / 60)
            }
        }
        sim.release(home: CGPoint(x: 416, y: AGeo.dockY))

        XCTAssertLessThan(sim.dirtiness, 0.03, "magnetic wiper polishes smudges away")
        XCTAssertTrue(sim.visitors.contains { $0.kind == .turtle }, "polishing tank clean invites the Sea Turtle")
        XCTAssertEqual(Coins.shared.balance, 3, "polishing tank clean awards 3 Play Coins")
    }

    func testTapDockWiperPolishesMossyPatch() {
        let sim = freshSim()
        sim.moss[0].opacity = 0.8
        let before = sim.moss[0].opacity
        sim.tapDockWiper()
        run(sim, seconds: 0.5)
        XCTAssertLessThan(sim.moss[0].opacity, before - 0.5)
    }

    func testMossGrowsBackSlowly() {
        let sim = freshSim()
        sim.snail.p = CGPoint(x: -500, y: -500)
        run(sim, seconds: 10)
        XCTAssertGreaterThan(sim.dirtiness, 0)
        XCTAssertLessThan(sim.dirtiness, 0.1)
    }

    // MARK: - Lifted Net & Explicit Return Zone (No Silent Deletion)

    func testToolLiftsUseProperFingerLiftWithoutBrokenFoodClamping() {
        XCTAssertEqual(AquariumView.lift(.net), FingerLift.tool)
        XCTAssertEqual(AquariumView.lift(.wiper), FingerLift.grip)
        XCTAssertEqual(AquariumView.lift(.food), FingerLift.pour)
        XCTAssertEqual(AquariumView.lift(.hoop), FingerLift.tool)

        let lowDrag = CGPoint(x: 500, y: 500)
        let liftedFood = AquariumView.lifted(lowDrag, .food)
        XCTAssertGreaterThan(liftedFood.y, AGeo.waterY + 150, "food shaker follows FingerLift.pour smoothly instead of snapping to waterY - 16")
    }

    func testNetScoopAndExplicitReturnZonePreventSilentDeletion() {
        let sim = freshSim()
        let p = CGPoint(x: 420, y: 400)
        sim.spawn(.goldfish, variant: 0, at: p)
        sim.fish[0].restUntil = 100

        sim.pickUp(.net, at: p)
        XCTAssertEqual(sim.caught, sim.fish[0].id)
        XCTAssertTrue(sim.isCarryingReturnable)

        // Dropping on the cabinet (NOT on ReturnDropBadge) keeps the fish safely in the tank.
        sim.carry(to: CGPoint(x: 420, y: 760), hand: CGPoint(x: 460, y: 800))
        sim.step(dt: 1.0 / 60)
        XCTAssertFalse(sim.isHoveringReturnZone)
        sim.release(home: CGPoint(x: 608, y: AGeo.dockY))
        XCTAssertEqual(sim.fish.count, 1, "cabinet drop must never silently delete a fish")
        XCTAssertFalse(sim.fish[0].caught)

        // Dropping explicitly onto ReturnDropBadge cleanly sends the fish back to the catalog.
        let again = sim.fish[0].p
        sim.pickUp(.net, at: again)
        XCTAssertEqual(sim.caught, sim.fish[0].id)
        sim.carry(to: AGeo.returnBadgeCenter, hand: AGeo.returnBadgeCenter)
        sim.step(dt: 1.0 / 60)
        XCTAssertTrue(sim.isHoveringReturnZone)
        sim.release(home: CGPoint(x: 608, y: AGeo.dockY))
        XCTAssertTrue(sim.fish.isEmpty)
    }

    func testDecorDragRequiresExplicitReturnZoneToRemove() {
        let sim = freshSim()
        let i = sim.addDecor(.castle, x: 340)
        let start = CGPoint(x: sim.decor[i].x, y: sim.decor[i].y - 60)

        sim.handBegan(start)
        sim.handMoved(CGPoint(x: start.x, y: start.y + 30), dt: 1.0 / 60)
        sim.step(dt: 1.0 / 60)
        XCTAssertTrue(sim.decor[0].held)
        XCTAssertTrue(sim.isCarryingReturnable)

        // Dropping over the cabinet keeps the castle safely in the tank.
        sim.handMoved(CGPoint(x: 340, y: 765), dt: 1.0 / 60)
        sim.step(dt: 1.0 / 60)
        sim.handEnded(CGPoint(x: 340, y: 765), tap: false)
        XCTAssertEqual(sim.decor.count, 1, "cabinet drop must never silently delete decor")

        // Dropping onto ReturnDropBadge removes the castle cleanly.
        run(sim, seconds: 4)
        let restart = CGPoint(x: sim.decor[0].x, y: sim.decor[0].y - 60)
        sim.handBegan(restart)
        sim.handMoved(CGPoint(x: restart.x + 25, y: restart.y), dt: 1.0 / 60)
        sim.handMoved(AGeo.returnBadgeCenter, dt: 1.0 / 60)
        sim.step(dt: 1.0 / 60)
        XCTAssertTrue(sim.isHoveringReturnZone)
        sim.handEnded(AGeo.returnBadgeCenter, tap: false)
        XCTAssertTrue(sim.decor.isEmpty)
    }

    func testTapDockNetPlaysWithoutDeletingFish() {
        let sim = freshSim()
        sim.spawn(.clownfish, variant: 0, at: CGPoint(x: 450, y: 380))
        sim.tapDockNet()
        run(sim, seconds: 1)
        XCTAssertEqual(sim.fish.count, 1)
        XCTAssertFalse(sim.fish[0].caught)
    }

    // MARK: - Tap Priority & Interactive Reef Props

    func testForegroundFishAndSnailHaveTapPriorityOverTallDecor() {
        let sim = freshSim()
        let weedIdx = sim.addDecor(.seaweed, x: 400)
        let fishPos = CGPoint(x: 400, y: 520)
        let snailPos = CGPoint(x: 400, y: 450)
        sim.spawn(.goldfish, variant: 0, at: fishPos)
        sim.snail.p = snailPos

        sim.handBegan(fishPos)
        sim.handEnded(fishPos, tap: true)
        XCTAssertGreaterThanOrEqual(sim.fish[0].happy, 0)
        XCTAssertLessThan(sim.decor[weedIdx].poke, 0, "tall seaweed must not swallow a fish tap")

        sim.handBegan(snailPos)
        sim.handEnded(snailPos, tap: true)
        XCTAssertGreaterThan(sim.snail.hideUntil, sim.time)
        XCTAssertLessThan(sim.decor[weedIdx].poke, 0, "tall seaweed must not swallow a snail tap")
    }

    func testInteractiveChestPearlBubblerUpdraftAndRockOctopus() {
        let sim = freshSim()
        let chestIdx = sim.addDecor(.chest, x: 680)
        let chestTap = CGPoint(x: 680, y: sim.decor[chestIdx].y - 26)
        sim.handBegan(chestTap)
        sim.handEnded(chestTap, tap: true)
        XCTAssertGreaterThan(sim.decor[chestIdx].openUntil, sim.time)
        XCTAssertEqual(sim.pearl?.id, sim.decor[chestIdx].id, "tapping chest pops out a gleaming pearl")
        XCTAssertEqual(Coins.shared.balance, 3, "pearl chest awards 3 Play Coins")

        let bubblerIdx = sim.addDecor(.bubbler, x: 300)
        let swimmerIdx = sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 300, y: 520))
        sim.fish[swimmerIdx].target = CGPoint(x: 300, y: 520)
        sim.fish[swimmerIdx].nextThink = 100
        let bubblerTap = CGPoint(x: 300, y: sim.decor[bubblerIdx].y - 16)
        sim.handBegan(bubblerTap)
        sim.handEnded(bubblerTap, tap: true)
        XCTAssertGreaterThan(sim.decor[bubblerIdx].boostUntil, sim.time)
        XCTAssertGreaterThan(sim.bubbles.count, 10)
        run(sim, seconds: 1.5)
        XCTAssertLessThan(sim.fish[swimmerIdx].p.y, 480, "fizzy updraft lifts passing fish upward")

        let rockIdx = sim.addDecor(.rock, x: 500)
        let rockTap = CGPoint(x: 500, y: sim.decor[rockIdx].y - 36)
        sim.handBegan(rockTap)
        sim.handEnded(rockTap, tap: true)
        XCTAssertTrue(sim.visitors.contains { $0.kind == .octopus }, "tapping rock invites the baby octopus to peek out")
    }

    // MARK: - Physics, Kinematics & Catalog

    func testDecorationsSinkThroughWaterAndRestOnTheSand() {
        let sim = freshSim()
        let weedY = 220 + AquaDecorKind.seaweed.size.height * 0.5
        let rock = sim.addDecor(.rock, x: 400, falling: true, y: 220)
        let weed = sim.addDecor(.seaweed, x: 700, falling: true, y: weedY)
        run(sim, seconds: 0.6)
        XCTAssertGreaterThan(sim.decor[rock].y - 220, (sim.decor[weed].y - weedY) * 1.5)
        run(sim, seconds: 8)
        for d in sim.decor {
            XCTAssertFalse(d.falling)
            XCTAssertEqual(d.y, AGeo.sand(d.x), accuracy: 0.5)
        }
    }

    func testBubblesRiseAndPopAtTheSurface() {
        let sim = freshSim()
        sim.addBubble(CGPoint(x: 500, y: 600), r: 5)
        sim.addBubble(CGPoint(x: 300, y: 600), r: 2)
        run(sim, seconds: 1)
        XCTAssertEqual(sim.bubbles.count, 2)
        let big = sim.bubbles.first { abs($0.p.x - 500) < 40 }!
        let small = sim.bubbles.first { abs($0.p.x - 300) < 40 }!
        XCTAssertLessThan(big.p.y, small.p.y)
        run(sim, seconds: 10)
        XCTAssertTrue(sim.bubbles.isEmpty)
    }

    func testFishStayInTheWater() {
        let sim = freshSim()
        for k in FishKind.allCases { sim.addFish(k, x: 500, y: 60) }
        for s in 0..<24 {
            if s % 5 == 0 {
                let p = CGPoint(x: 200 + CGFloat(s) * 20, y: 400)
                sim.handBegan(p)
                sim.handEnded(p, tap: true)
            }
            run(sim, seconds: 1)
            for f in sim.fish {
                XCTAssertGreaterThan(f.p.x, AGeo.left)
                XCTAssertLessThan(f.p.x, AGeo.right)
                XCTAssertGreaterThan(f.p.y, AGeo.waterY)
                XCTAssertLessThan(f.p.y, AGeo.sand(f.p.x))
            }
        }
    }

    func testDecorCatalogHasTwelveFreeAndThreeTreasureItems() {
        XCTAssertEqual(AquaDecorKind.available.count, 12)
        XCTAssertEqual(AquaDecorKind.allCases.count, 15)
        let treasures = Set(AquaDecorKind.allCases.compactMap(\.treasure))
        XCTAssertEqual(treasures, ["aquarium/crystal", "aquarium/coral", "aquarium/unicorn"])

        Coins.shared.resetForTests(balance: 40)
        XCTAssertTrue(Coins.shared.buy("aquarium/coral", price: 12))
        XCTAssertEqual(AquaDecorKind.available.count, 13)
        XCTAssertTrue(AquaDecorKind.available.contains(.rainbowCoral))
    }

    // MARK: - Save / Load & Legacy Migration

    func testSaveRoundTripAndLegacyReefMigration() throws {
        let sim = freshSim()
        sim.addFish(.betta, x: 300, y: 300)
        sim.spawn(.goldfish, variant: AquaRare.variant + 2)
        sim.addDecor(.castle, x: 300)
        sim.addDecor(.ship, x: 700)
        sim.moss[0].opacity = 0.45
        sim.lightsOn = false

        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(AquaSave.self, from: data)
        let back = AquariumSim(save: decoded)
        XCTAssertEqual(back.fish.map(\.kind), [.betta, .goldfish])
        XCTAssertEqual(back.fish.last?.variant, AquaRare.variant + 2)
        XCTAssertEqual(back.decor.map(\.kind), [.castle, .ship])
        XCTAssertEqual(back.moss.count, AGeo.mossPresets.count)
        XCTAssertEqual(back.moss[0].opacity, 0.45, accuracy: 0.01)
        XCTAssertFalse(back.lightsOn)

        // Legacy aquarium.json containing retired pillar/slate entries and algae grid migrates cleanly.
        let legacyJSON = """
        {
            "fish": [{"kind": "clownfish", "variant": 0}],
            "decor": [
                {"kind": "castle", "x": 280, "flip": false},
                {"kind": "pillar", "x": 412, "flip": false},
                {"kind": "slate", "x": 465, "flip": true, "supported": true}
            ],
            "algae": [0.4, 0.4, 0.4],
            "night": true,
            "pump": false,
            "reefStarted": true
        }
        """
        let legacySave = try JSONDecoder().decode(AquaSave.self, from: Data(legacyJSON.utf8))
        let migrated = AquariumSim(save: legacySave)
        XCTAssertEqual(migrated.fish.map(\.kind), [.clownfish])
        XCTAssertEqual(migrated.decor.map(\.kind), [.castle])
        XCTAssertFalse(migrated.lightsOn)
        XCTAssertFalse(migrated.pump)
        XCTAssertEqual(migrated.moss.count, AGeo.mossPresets.count)
        XCTAssertGreaterThan(migrated.dirtiness, 0.2)
    }

    // MARK: - Day/Night, Visitors, Stickers & Audio

    func testDayNightModeAttractsNocturnalVisitors() {
        let sim = freshSim()
        sim.setLights(false)
        run(sim, seconds: 3)
        XCTAssertGreaterThan(sim.night, 0.9)
        sim.nextVisit = 0
        run(sim, seconds: 1)
        sim.nextVisit = 0
        run(sim, seconds: 15)
        XCTAssertFalse(sim.visitors.isEmpty)
        XCTAssertTrue(sim.visitors.allSatisfy { $0.kind == .crab || $0.kind == .jellyfish })

        sim.setLights(true)
        run(sim, seconds: 3)
        XCTAssertLessThan(sim.night, 0.1)
    }

    func testEveryAquariumSurpriseHasAStickerAndTapCelebratesVisitor() {
        let entry = GameRegistry.all.first { $0.id == AquariumSim.gameID }
        XCTAssertEqual(entry?.stickers.count, 14)
        XCTAssertEqual(entry?.stickers.map(\.id), AquaFind.allCases.map(\.rawValue))
        for k in FishKind.allCases { XCTAssertEqual(AquaFind.rare(k).fish, k) }
        for v in AVisitorKind.allCases { XCTAssertEqual(AquaFind(rawValue: v.rawValue)?.visitor, v) }

        let sim = freshSim()
        sim.visitors.append(AVisitor(kind: .turtle, p: CGPoint(x: 420, y: 340), facing: 1))
        XCTAssertTrue(sim.tapVisitor(CGPoint(x: 420, y: 340)))
        XCTAssertTrue(sim.visitors[0].found)
    }

    func testBundledAudioFilesShip() {
        for sfx in AquaSFX.allCases {
            XCTAssertNotNil(GameFiles.url(sfx.rawValue, "wav", game: "Aquarium"), "missing bundled Aquarium sound \(sfx.rawValue).wav")
        }
    }
}
