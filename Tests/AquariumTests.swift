import XCTest
@testable import Glimmie

final class AquariumTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Coins.shared.resetForTests()
        StickerBook.shared.resetForTests()
    }

    private func freshSim() -> AquariumSim {
        let sim = AquariumSim(save: nil)
        sim.demo = true
        sim.fish = []
        sim.food = []
        sim.bubbles = []
        sim.hoops = []
        sim.decor = []
        sim.eggs = []
        sim.floatingGifts = []
        sim.activeWish = nil
        sim.nextWishAt = 10_000
        sim.visitors = []
        sim.submarine.active = false
        sim.moss = AquaMossPatch.makeDefault()
        sim.pump = false
        sim.resolveSandLayout()
        return sim
    }

    private func run(_ sim: AquariumSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { sim.step(dt: 1.0 / 60) }
        sim.flushPendingRewards()
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
        sim.flushPendingRewards()

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
        XCTAssertNotNil(sim.quickAction)
        XCTAssertFalse(sim.bubbles.isEmpty, "tapping net should send rising bubbles along the scoop arc")
        XCTAssertTrue(sim.particles.contains { $0.kind == .sparkle }, "tapping net should emit sparkle particles")
        run(sim, seconds: 1)
        XCTAssertEqual(sim.fish.count, 1)
        XCTAssertFalse(sim.fish[0].caught)
    }

    func testHoopAndChestCoinPayoutsEnforceCooldown() {
        let sim = freshSim()
        let chestIdx = sim.addDecor(.chest, x: 680)
        let chestTap = CGPoint(x: 680, y: sim.decor[chestIdx].y - 26)

        // First chest tap awards 3 coins.
        sim.handBegan(chestTap)
        sim.handEnded(chestTap, tap: true)
        XCTAssertEqual(Coins.shared.balance, 3)

        // Rapid second tap inside the 2.5s cooldown does not farm coins.
        run(sim, seconds: 1.0)
        sim.handBegan(chestTap)
        sim.handEnded(chestTap, tap: true)
        XCTAssertEqual(Coins.shared.balance, 3)

        // After cooldown elapses, chest pays out again.
        run(sim, seconds: AquariumSim.coinCooldown + 0.2)
        sim.handBegan(chestTap)
        sim.handEnded(chestTap, tap: true)
        XCTAssertEqual(Coins.shared.balance, 6)

        // Hoop tricks also enforce the standardized 2.5s coin cooldown.
        Coins.shared.resetForTests()
        let hoopSim = freshSim()
        let f0 = hoopSim.spawn(.goldfish, variant: 0, at: CGPoint(x: 425, y: 348))
        let f1 = hoopSim.spawn(.goldfish, variant: 1, at: CGPoint(x: 410, y: 372))
        hoopSim.fish[f0].dir = 1
        hoopSim.fish[f0].facing = 1
        hoopSim.fish[f1].dir = 1
        hoopSim.fish[f1].facing = 1
        hoopSim.spawnBubbleHoop(at: CGPoint(x: 460, y: 360))
        hoopSim.hoops[0].phase = 0
        run(hoopSim, seconds: 1.2)
        XCTAssertEqual(hoopSim.hoops.first?.tricks, 2)
        XCTAssertEqual(Coins.shared.balance, 2, "back-to-back hoop tricks within cooldown must only pay once")

        run(hoopSim, seconds: AquariumSim.coinCooldown + 0.3)
        hoopSim.hoops.removeAll()
        hoopSim.fish[f0].p = CGPoint(x: 425, y: 360)
        hoopSim.fish[f0].dir = 1
        hoopSim.fish[f0].facing = 1
        hoopSim.spawnBubbleHoop(at: CGPoint(x: 460, y: 360))
        run(hoopSim, seconds: 0.4)
        XCTAssertEqual(Coins.shared.balance, 4, "hoop trick after cooldown pays out again")
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

    func testDecorCatalogHasTwelveFreeAndFourTreasureItems() {
        XCTAssertEqual(AquaDecorKind.available.count, 12)
        XCTAssertEqual(AquaDecorKind.allCases.count, 16)
        let treasures = Set(AquaDecorKind.allCases.compactMap(\.treasure))
        XCTAssertEqual(treasures, ["aquarium/crystal", "aquarium/coral", "aquarium/unicorn", "aquarium/koiBridge"])

        Coins.shared.resetForTests(balance: 40)
        XCTAssertTrue(Coins.shared.buy("aquarium/coral", price: 12))
        XCTAssertEqual(AquaDecorKind.available.count, 13)
        XCTAssertTrue(AquaDecorKind.available.contains(.rainbowCoral))

        XCTAssertTrue(Coins.shared.buy("aquarium/koiBridge", price: 12))
        XCTAssertEqual(AquaDecorKind.available.count, 14)
        XCTAssertTrue(AquaDecorKind.available.contains(.koiBridge))
        XCTAssertTrue(AquaDecorKind.koiBridge.bubbles)

        let sim = freshSim()
        sim.pump = true
        let idx = sim.addDecor(.koiBridge, x: 512)
        sim.decor[idx].nextPuff = 0
        run(sim, seconds: 0.2)
        XCTAssertFalse(sim.bubbles.isEmpty, "koi bridge should release gentle bubbles through its arch")
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
        XCTAssertEqual(entry?.stickers.count, 17)
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
            let url = GameFiles.url(sfx.rawValue, "caf", game: "Aquarium")
                ?? GameFiles.url(sfx.rawValue, "wav", game: "Aquarium")
            XCTAssertNotNil(url, "missing bundled Aquarium sound \(sfx.rawValue)")
        }
    }

    // MARK: - 60 FPS Performance Fixes (Deferred Rewards, Cached AquaBody, Particle Cap)

    func testDeferredRewardsQueueDuringStepWithoutMutatingCoinsUntilFlushed() {
        let sim = freshSim()
        let fIdx = sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 420, y: 360))
        sim.fish[fIdx].dir = 1
        sim.fish[fIdx].facing = 1
        sim.spawnBubbleHoop(at: CGPoint(x: 460, y: 360))

        for _ in 0..<120 { sim.step(dt: 1.0 / 60) }

        XCTAssertFalse(sim.pendingCoins.isEmpty, "step(dt:) should queue coin rewards rather than mutating @Published inside Canvas")
        XCTAssertEqual(Coins.shared.balance, 0, "Coins.shared.balance must remain untouched during step(dt:)")

        sim.flushPendingRewards()
        XCTAssertTrue(sim.pendingCoins.isEmpty)
        XCTAssertEqual(Coins.shared.balance, 2, "flushPendingRewards() applies queued coin rewards deterministically")
    }

    func testAquaBodyCachesOutlinePathAndUsesPrecomputedProfiles() {
        let body = AquaBody(L: 70, H: 46, a: 0.85, b: 0.5, bend: 0.08)
        XCTAssertTrue(AquaBody.hasCachedProfile(a: 0.85, b: 0.5))
        XCTAssertTrue(AquaBody.hasCachedProfile(a: 0.75, b: 0.6))
        XCTAssertTrue(AquaBody.hasCachedProfile(a: 0.65, b: 0.7))
        XCTAssertTrue(AquaBody.hasCachedProfile(a: 0.78, b: 0.58))
        XCTAssertGreaterThan(body.peak, 0)
        XCTAssertFalse(body.outlinePath.isEmpty)
        XCTAssertEqual(body.outline.boundingRect, body.outlinePath.boundingRect)
        XCTAssertGreaterThan(body.half(0.5), 10)
        XCTAssertEqual(body.half(0), body.half(-0.5), accuracy: 0.001)
    }

    func testGlobalParticleCapEnforcedAcrossAllEmitters() {
        let sim = freshSim()
        sim.night = 1
        for k in 0..<15 {
            sim.splash(at: 200 + CGFloat(k * 40), strength: 1.2)
            sim.emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: 400, y: 300),
                    v: .zero,
                    life: 2.0,
                    size: 14,
                    color: ARGB(0xFFE69A)
                )
            )
            sim.emitParticle(
                AquaParticle(
                    kind: .glow,
                    p: CGPoint(x: 500, y: 350),
                    v: .zero,
                    life: 5.0,
                    size: 3,
                    color: ARGB(0x8CF7FF)
                )
            )
        }
        XCTAssertLessThanOrEqual(sim.particles.count, AquariumSim.maxParticles)
        XCTAssertEqual(AquariumSim.maxParticles, 120)
        run(sim, seconds: 0.5)
        XCTAssertLessThanOrEqual(sim.particles.count, AquariumSim.maxParticles)
    }

    // MARK: - Hatchable Mystery Reef Eggs & Baby Growth Loop

    func testMysteryEggThreeTapHatchSpawnsBabyCreatureAndRespectsMaxCap() {
        let sim = freshSim()
        XCTAssertNotNil(sim.dropEgg(at: 320, y: AGeo.sand(320), species: .axolotl))
        XCTAssertNotNil(sim.dropEgg(at: 480, y: AGeo.sand(480), species: .seaBunny))
        XCTAssertNotNil(sim.dropEgg(at: 640, y: AGeo.sand(640), species: .narwhal))
        XCTAssertNil(sim.dropEgg(at: 720, y: AGeo.sand(720), species: .goldfish), "tank holds at most 3 mystery eggs")
        XCTAssertEqual(sim.eggs.count, 3)

        let tapSpot = CGPoint(x: 320, y: AGeo.sand(320) - 22)
        XCTAssertTrue(sim.tapEgg(tapSpot))
        XCTAssertEqual(sim.eggs[0].taps, 1)
        XCTAssertTrue(sim.fish.isEmpty)

        XCTAssertTrue(sim.tapEgg(tapSpot))
        XCTAssertEqual(sim.eggs[0].taps, 2)
        XCTAssertTrue(sim.fish.isEmpty)

        XCTAssertTrue(sim.tapEgg(tapSpot))
        XCTAssertEqual(sim.eggs.count, 2, "3rd tap hatches and removes the egg")
        XCTAssertEqual(sim.fish.count, 1)
        XCTAssertEqual(sim.fish[0].kind, .axolotl)
        XCTAssertEqual(sim.fish[0].growthStage, 0)
        XCTAssertEqual(sim.fish[0].growthScale, 0.55, accuracy: 0.001)
    }

    func testFeedingBabyCreatureGrowsBabyToKidToAdultAndAwardsCoins() {
        let sim = freshSim()
        sim.lastFeedRewardAt = 1000 // Isolate growth coins from the 3-flake baby-visitor bonus.
        let idx = sim.spawn(.seaBunny, variant: 0, at: CGPoint(x: 500, y: 420), growthStage: 0)
        sim.fish[idx].dir = 1
        sim.fish[idx].facing = 1
        sim.fish[idx].appetite = 5

        for k in 0..<3 {
            sim.addFlake(at: CGPoint(x: 508 + CGFloat(k) * 8, y: 420), v: .zero, kind: .pearls)
        }
        run(sim, seconds: 6)
        XCTAssertEqual(sim.fish[idx].growthStage, 1, "3 bites grows baby -> kid")
        XCTAssertEqual(sim.fish[idx].growthScale, 0.78, accuracy: 0.001)
        XCTAssertEqual(Coins.shared.balance, 2, "growing to kid awards 2 Play Coins")

        for k in 0..<3 {
            sim.addFlake(at: CGPoint(x: sim.fish[idx].p.x + CGFloat(k) * 8, y: sim.fish[idx].p.y), v: .zero, kind: .pearls)
        }
        run(sim, seconds: 6)
        XCTAssertEqual(sim.fish[idx].growthStage, 2, "3 more bites grows kid -> shimmering adult")
        XCTAssertEqual(sim.fish[idx].growthScale, 1.0, accuracy: 0.001)
        XCTAssertTrue(sim.fish[idx].grewUp)
        XCTAssertEqual(Coins.shared.balance, 4, "growing to adult awards 2 more Play Coins")
    }

    // MARK: - Interactive Yellow Submarine, Musical Singing Clams & Pearl Pellets

    func testYellowSubmarineSteeringAndSpotlightWakeHiddenSurprises() {
        let sim = freshSim()
        XCTAssertFalse(sim.submarine.active)
        sim.toggleSubmarine()
        XCTAssertTrue(sim.submarine.active)

        let spot = sim.hiddenSpots[0]
        sim.steerSubmarine(to: CGPoint(x: spot.p.x - 45, y: spot.p.y - 60))
        run(sim, seconds: 3.5)

        XCTAssertLessThan(hypot(sim.submarine.p.x - sim.submarine.target.x, sim.submarine.p.y - sim.submarine.target.y), 25)
        XCTAssertGreaterThan(sim.hiddenSpots[0].pop, 0.4, "submarine spotlight wakes hiding reef surprise")
        XCTAssertEqual(Coins.shared.balance, 2, "waking hidden surprise awards 2 Play Coins")

        // Immediate re-run inside cooldown must not double-pay the same spot.
        run(sim, seconds: 1.0)
        XCTAssertEqual(Coins.shared.balance, 2)
    }

    func testMusicalSingingClamsTriggerFishRibbonDance() {
        let sim = freshSim()
        sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 200, y: 300))
        sim.spawn(.narwhal, variant: 0, at: CGPoint(x: 800, y: 300))
        XCTAssertEqual(sim.clams.count, 4)
        XCTAssertFalse(sim.isRibbonDanceActive)

        for idx in 0..<3 {
            let c = sim.clams[idx]
            XCTAssertTrue(sim.tapClam(CGPoint(x: c.x, y: c.y - 10)))
            run(sim, seconds: 0.35)
        }

        XCTAssertTrue(sim.isRibbonDanceActive, "tapping 3+ clams within 4s triggers Fish Ribbon Dance")
        XCTAssertTrue(sim.particles.contains { $0.kind == .note }, "singing clams emit floating music notes")
        XCTAssertTrue(sim.clams.allSatisfy { $0.open > 0.3 }, "all clams sing together during Ribbon Dance")
    }

    func testPearlPelletsSinkDirectlyAndGiveFishStardustShimmer() {
        let sim = freshSim()
        sim.toggleTreatMode()
        XCTAssertEqual(sim.treatMode, .pearls)

        sim.addFlake(at: CGPoint(x: 420, y: 80), v: .zero)
        run(sim, seconds: 0.5)
        XCTAssertEqual(sim.food.first?.kind, .pearls)
        XCTAssertEqual(sim.food.first?.state, .sinking, "glowing pearl pellets sink gently without floating")

        let idx = sim.spawn(.narwhal, variant: 0, at: CGPoint(x: 420, y: sim.food[0].p.y + 8))
        run(sim, seconds: 2.5)
        XCTAssertGreaterThan(sim.fish[idx].stardustUntil, sim.time, "eating a pearl pellet gives fish stardust shimmer for 6s")
    }

    func testAquaSaveBackwardCompatibilityDefaultsGrowthStageAndRoundTripsEggs() throws {
        let legacyFishJSON = """
        {
            "fish": [{"kind": "goldfish", "variant": 1}],
            "decor": [],
            "moss": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "night": false,
            "pump": true
        }
        """
        let legacyDecoded = try JSONDecoder().decode(AquaSave.self, from: Data(legacyFishJSON.utf8))
        XCTAssertEqual(legacyDecoded.fish.first?.growthStage, 2, "legacy saves default fish growthStage to adult (2)")
        XCTAssertTrue(legacyDecoded.eggs.isEmpty)

        let sim = freshSim()
        sim.spawn(.narwhal, variant: 2, growthStage: 0, growthBites: 2)
        _ = sim.dropEgg(at: 410, y: AGeo.sand(410), species: .seaBunny)
        sim.eggs[0].taps = 2

        let data = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(AquaSave.self, from: data)
        let restored = AquariumSim(save: decoded)
        XCTAssertEqual(restored.fish.first?.kind, .narwhal)
        XCTAssertEqual(restored.fish.first?.growthStage, 0)
        XCTAssertEqual(restored.fish.first?.growthBites, 2)
        XCTAssertEqual(restored.eggs.count, 1)
        XCTAssertEqual(restored.eggs[0].species, .seaBunny)
        XCTAssertEqual(restored.eggs[0].taps, 2)
    }

    // MARK: - Aquarium A1: Agency Fixes, Living Decor, Active Discovery & Play Wishes

    func testSubmarineHullOnlyDragUsesFingerLiftAndLeavesOpenWaterTapsAndHoldsIntact() {
        let sim = freshSim()
        sim.demo = false
        sim.toggleSubmarine()
        sim.bubbles = []
        sim.submarine.p = CGPoint(x: 300, y: 360)
        sim.submarine.target = CGPoint(x: 300, y: 360)

        let fIdx = sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 840, y: 380))

        let openTap = CGPoint(x: 680, y: 380)
        sim.handBegan(openTap)
        XCTAssertFalse(sim.isGrabbingSubmarine)
        sim.handEnded(openTap, tap: true)
        XCTAssertEqual(sim.submarine.target, CGPoint(x: 300, y: 360), "open water tap must never hijack submarine")
        XCTAssertTrue(sim.particles.contains { $0.kind == .ring }, "open water tap triggers glass ring")
        XCTAssertGreaterThan(sim.fish[fIdx].fleeUntil, sim.time, "open water tap startles nearby fish")

        sim.fish[fIdx].fleeUntil = -10
        let holdSpot = CGPoint(x: 700, y: 400)
        sim.handBegan(holdSpot)
        XCTAssertFalse(sim.isGrabbingSubmarine)
        run(sim, seconds: 0.6)
        XCTAssertEqual(sim.fish[fIdx].curious, holdSpot, "holding open water attracts curious fish even with active sub")
        XCTAssertEqual(sim.submarine.target, CGPoint(x: 300, y: 360))
        sim.handEnded(holdSpot, tap: false)

        let rarePos = CGPoint(x: 310, y: 365)
        let rareIdx = sim.spawn(.axolotl, variant: AquaRare.variant, at: rarePos)
        sim.fish[rareIdx].restUntil = 100
        sim.handBegan(rarePos)
        sim.handEnded(rarePos, tap: true)
        XCTAssertTrue(
            StickerBook.shared.has(game: AquariumSim.gameID, id: AquaFind.starlightAxolotl.rawValue),
            "parked submarine hull must not swallow foreground taps on rare fish"
        )

        let hullTouch = CGPoint(x: 300, y: 360)
        let dragFinger = CGPoint(x: 540, y: 490)
        sim.handBegan(hullTouch)
        XCTAssertTrue(sim.isGrabbingSubmarine)
        sim.handMoved(dragFinger, dt: 1.0 / 60)
        let expected = sim.liftedSubmarineTarget(for: dragFinger)
        XCTAssertEqual(sim.submarine.target.x, expected.x, accuracy: 2.0)
        XCTAssertEqual(sim.submarine.target.y, expected.y, accuracy: 2.0)
        XCTAssertLessThan(sim.submarine.target.y, dragFinger.y - 40, "FingerLift lifts submarine above finger")
        sim.handEnded(dragFinger, tap: false)
        XCTAssertFalse(sim.isGrabbingSubmarine)
    }

    func testDynamicSandLayoutDodgesPlacedDecorAndGroundedEggsWhilePreservingState() {
        let sim = freshSim()
        sim.clams[1].openUntil = 42
        sim.hiddenSpots[2].awakeUntil = 55

        let castleIdx = sim.addDecor(.castle, x: 396)
        let shipIdx = sim.addDecor(.ship, x: 695)
        let eggIdx = sim.dropEgg(at: 188, y: AGeo.sand(188), species: .axolotl)
        XCTAssertNotNil(eggIdx)
        let castle = sim.decor[castleIdx]
        let ship = sim.decor[shipIdx]
        let eggX = sim.eggs[0].x

        for clam in sim.clams {
            XCTAssertGreaterThanOrEqual(abs(clam.x - castle.x), castle.kind.size.width * 0.5 - 1, "clam dodges castle footprint")
            XCTAssertGreaterThanOrEqual(abs(clam.x - ship.x), ship.kind.size.width * 0.5 - 1, "clam dodges ship footprint")
            XCTAssertGreaterThanOrEqual(abs(clam.x - eggX), AquaSandLayout.eggHalfWidth - 1, "clam dodges grounded egg footprint")
            XCTAssertEqual(clam.y, AGeo.sand(clam.x) - 8, accuracy: 0.5)
        }
        for spot in sim.hiddenSpots {
            XCTAssertGreaterThanOrEqual(abs(spot.p.x - castle.x), castle.kind.size.width * 0.5 - 1, "hidden spot dodges castle")
            XCTAssertGreaterThanOrEqual(abs(spot.p.x - ship.x), ship.kind.size.width * 0.5 - 1, "hidden spot dodges ship")
            XCTAssertGreaterThanOrEqual(abs(spot.p.x - eggX), AquaSandLayout.eggHalfWidth - 1, "hidden spot dodges grounded egg")
            let expectedY = AGeo.sand(spot.p.x) + (spot.kind == .glowSeahorse ? -18 : 0)
            XCTAssertEqual(spot.p.y, expectedY, accuracy: 0.5)
        }
        XCTAssertEqual(sim.clams[1].openUntil, 42, "sand layout preserves clam state")
        XCTAssertEqual(sim.hiddenSpots[2].awakeUntil, 55, "sand layout preserves hidden spot state")
    }

    func testAwakenedHiddenSpotTapCelebratesAndEnforcesCoinCooldown() {
        let sim = freshSim()
        let spotPos = CGPoint(x: sim.hiddenSpots[0].p.x, y: sim.hiddenSpots[0].p.y - 16)

        XCTAssertFalse(sim.tapHiddenSpot(spotPos))
        XCTAssertEqual(Coins.shared.balance, 0)

        sim.hiddenSpots[0].awakeUntil = sim.time + 5
        sim.hiddenSpots[0].pop = 0.85
        sim.handBegan(spotPos)
        sim.handEnded(spotPos, tap: true)
        XCTAssertGreaterThan(sim.hiddenSpots[0].celebrateUntil, sim.time)
        XCTAssertTrue(sim.particles.contains { $0.kind == .heart })
        XCTAssertEqual(Coins.shared.balance, 1, "tapping awakened hidden spot awards 1 Play Coin")

        sim.handBegan(spotPos)
        sim.handEnded(spotPos, tap: true)
        XCTAssertEqual(Coins.shared.balance, 1)
    }

    func testActiveDiscoveryRequiresTapForRareReefBabiesVisitorsAndChestPearl() {
        let sim = freshSim()
        sim.demo = false

        let axIdx = sim.spawn(.axolotl, variant: AquaRare.variant, at: CGPoint(x: 240, y: 360))
        let sbIdx = sim.spawn(.seaBunny, variant: AquaRare.variant, at: CGPoint(x: 420, y: 360))
        let nwIdx = sim.spawn(.narwhal, variant: AquaRare.variant, at: CGPoint(x: 600, y: 360))
        for idx in [axIdx, sbIdx, nwIdx] {
            sim.fish[idx].restUntil = 100
        }

        sim.visitors.append(AVisitor(kind: .turtle, p: CGPoint(x: 340, y: 260), target: CGPoint(x: 820, y: 260), state: .arriving, facing: 1))
        var octo = AVisitor(kind: .octopus, p: CGPoint(x: 780, y: AGeo.sand(780)), facing: -1)
        octo.state = .staying
        octo.stayUntil = 30
        sim.visitors.append(octo)

        let chestIdx = sim.addDecor(.chest, x: 512)
        sim.decor[chestIdx].open = 1
        sim.decor[chestIdx].openUntil = 20
        sim.revealChestPearl(chestIdx)

        run(sim, seconds: 3.0)
        XCTAssertEqual(StickerBook.shared.count(game: AquariumSim.gameID), 0, "stickers must never passively auto-unlock")
        XCTAssertTrue(sim.needsDiscoveryTap(for: sim.fish[axIdx]))
        XCTAssertTrue(sim.needsDiscoveryTap(for: sim.fish[sbIdx]))
        XCTAssertTrue(sim.needsDiscoveryTap(for: sim.fish[nwIdx]))
        XCTAssertTrue(sim.chestPearlNeedsDiscoveryTap)

        sim.tapFish(axIdx)
        sim.tapFish(sbIdx)
        sim.tapFish(nwIdx)
        XCTAssertTrue(StickerBook.shared.has(game: AquariumSim.gameID, id: AquaFind.starlightAxolotl.rawValue))
        XCTAssertTrue(StickerBook.shared.has(game: AquariumSim.gameID, id: AquaFind.lavenderSeaBunny.rawValue))
        XCTAssertTrue(StickerBook.shared.has(game: AquariumSim.gameID, id: AquaFind.pastelNarwhal.rawValue))
        XCTAssertFalse(sim.needsDiscoveryTap(for: sim.fish[axIdx]))

        for v in sim.visitors {
            let tapPt = v.kind == .octopus ? CGPoint(x: v.p.x, y: v.p.y - 24) : v.p
            XCTAssertTrue(sim.tapVisitor(tapPt))
        }
        XCTAssertTrue(StickerBook.shared.has(game: AquariumSim.gameID, id: AquaFind.turtle.rawValue))
        XCTAssertTrue(StickerBook.shared.has(game: AquariumSim.gameID, id: AquaFind.octopus.rawValue))

        let pearlPt = CGPoint(x: sim.decor[chestIdx].x, y: sim.decor[chestIdx].y - 50)
        XCTAssertTrue(sim.tapChestPearl(pearlPt))
        XCTAssertTrue(StickerBook.shared.has(game: AquariumSim.gameID, id: AquaFind.pearl.rawValue))
        XCTAssertFalse(sim.chestPearlNeedsDiscoveryTap)
    }

    func testNightModeSleepingUsesSleepBedsAndRestUntilAndWakesOnTapFoodOrLights() {
        let sim = freshSim()
        let shellIdx = sim.addDecor(.shell, x: 340)
        _ = sim.addDecor(.castle, x: 640)
        let f0 = sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 345, y: 550))
        let f1 = sim.spawn(.clownfish, variant: 0, at: CGPoint(x: 610, y: 550))
        let f2 = sim.spawn(.puffer, variant: 0, at: CGPoint(x: 490, y: 550))

        sim.setLights(false)
        run(sim, seconds: 6.0)

        XCTAssertTrue(sim.isFishSleeping(sim.fish[f0]), "fish settles to sleep in Night Mode")
        XCTAssertTrue(sim.isFishSleeping(sim.fish[f1]), "second fish settles to sleep in Night Mode")
        XCTAssertTrue(sim.isFishSleeping(sim.fish[f2]), "third fish settles to sleep in Night Mode")
        XCTAssertGreaterThan(sim.fish[f0].restUntil, sim.time, "Night Mode wires AquaFish.restUntil")
        if case .sleeping(let bedID, _, _) = sim.fish[f0].activity {
            XCTAssertEqual(bedID, sim.decor[shellIdx].id, "nearby fish curls into available sleepBed decor anchor")
        } else {
            XCTFail("expected fish to be sleeping in shell bed")
        }
        XCTAssertTrue(sim.particles.contains { $0.kind == .sleepZ }, "sleeping fish emits gentle sleep Z-bubbles")

        sim.tapFish(f0)
        XCTAssertFalse(sim.isFishSleeping(sim.fish[f0]))
        XCTAssertLessThan(sim.fish[f0].restUntil, sim.time)

        sim.fish[f2].appetite = 5
        sim.addFlake(at: CGPoint(x: sim.fish[f2].p.x + 24, y: sim.fish[f2].p.y - 12), v: .zero)
        run(sim, seconds: 0.4)
        XCTAssertFalse(sim.isFishSleeping(sim.fish[f2]), "nearby food wakes sleeping fish")

        sim.setLights(true)
        XCTAssertFalse(sim.isFishSleeping(sim.fish[f1]))
        XCTAssertLessThan(sim.fish[f1].restUntil, sim.time)
    }

    func testLivingDecorAnchorsKoiBridgeSwimThroughAndCastleHideoutPopOut() {
        XCTAssertTrue(AquaDecorKind.koiBridge.anchorSpecs.contains { $0.role == .swimThrough })
        XCTAssertTrue(AquaDecorKind.castle.anchorSpecs.contains { $0.role == .hideout })
        XCTAssertTrue(AquaDecorKind.castle.anchorSpecs.contains { $0.role == .sleepBed })
        XCTAssertTrue(AquaDecorKind.ship.anchorSpecs.contains { $0.role == .hideout })
        XCTAssertTrue(AquaDecorKind.ship.anchorSpecs.contains { $0.role == .swimThrough })
        XCTAssertTrue(AquaDecorKind.rock.anchorSpecs.contains { $0.role == .hideout })
        for bedKind in [AquaDecorKind.shell, .anemone, .coral, .rainbowCoral] {
            XCTAssertTrue(bedKind.anchorSpecs.contains { $0.role == .sleepBed })
        }

        let sim = freshSim()
        let bridgeIdx = sim.addDecor(.koiBridge, x: 512)
        let fIdx = sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 380, y: sim.decor[bridgeIdx].y - 34))
        XCTAssertTrue(sim.sendFish(fIdx, toDecor: bridgeIdx, role: .swimThrough))
        var completed = false
        for _ in 0..<240 {
            sim.step(dt: 1.0 / 60)
            if sim.fish[fIdx].activity == .cruising {
                completed = true
                break
            }
        }
        sim.flushPendingRewards()
        XCTAssertTrue(completed, "fish completes koi bridge swim-through")
        XCTAssertGreaterThan(sim.fish[fIdx].p.x, 512, "fish glided across to the far side of the koi bridge")
        XCTAssertGreaterThanOrEqual(sim.fish[fIdx].happy, 0)

        let castleIdx = sim.addDecor(.castle, x: 300)
        let hideFish = sim.spawn(.clownfish, variant: 0, at: CGPoint(x: 300, y: sim.decor[castleIdx].y - 30))
        XCTAssertTrue(sim.sendFish(hideFish, toDecor: castleIdx, role: .hideout))
        run(sim, seconds: 1.0)
        if case .hiding(let did, _, _) = sim.fish[hideFish].activity {
            XCTAssertEqual(did, sim.decor[castleIdx].id)
        } else {
            XCTFail("expected fish to be hiding inside castle doorway")
        }

        let castleTap = CGPoint(x: 300, y: sim.decor[castleIdx].y - 110)
        sim.handBegan(castleTap)
        sim.handEnded(castleTap, tap: true)
        XCTAssertEqual(sim.fish[hideFish].activity, .cruising, "tapping castle pops hidden fish out")
        XCTAssertGreaterThanOrEqual(sim.fish[hideFish].flipStart, 0)
        XCTAssertTrue(sim.particles.contains { $0.kind == .heart })

        XCTAssertTrue(sim.sendFish(hideFish, toDecor: castleIdx, role: .hideout))
        run(sim, seconds: 1.0)
        _ = sim.spawnPlayWish(kind: .decorPlay(.castle, .hideout))
        sim.tapFish(hideFish)
        XCTAssertEqual(sim.fish[hideFish].activity, .cruising, "tapping a hiding fish directly pops it out")
        XCTAssertNil(sim.activeWish, "tapping a hiding fish fulfills its hideout decor wish")
        XCTAssertEqual(Coins.shared.balance, 3)
    }

    func testDockNetAndDraggedNetScoopFloatingGiftsAndNeverStealPearlFromClosedChest() {
        let sim = freshSim()
        sim.demo = false
        let chestIdx = sim.addDecor(.chest, x: 680)
        let fIdx = sim.spawn(.clownfish, variant: 0, at: CGPoint(x: 420, y: 360))
        sim.fish[fIdx].restUntil = 100

        sim.tapDockNet()
        XCTAssertFalse(
            StickerBook.shared.has(game: AquariumSim.gameID, id: AquaFind.pearl.rawValue),
            "tapping dock net must never steal pearl sticker from a closed chest"
        )
        XCTAssertEqual(Coins.shared.balance, 2)
        XCTAssertEqual(sim.fish.count, 1)
        XCTAssertFalse(sim.fish[0].caught)

        sim.decor[chestIdx].open = 1
        sim.decor[chestIdx].openUntil = sim.time + 10
        sim.revealChestPearl(chestIdx)
        XCTAssertEqual(sim.pearl?.id, sim.decor[chestIdx].id)
        XCTAssertTrue(
            sim.floatingGifts.filter({ $0.kind == .pearl }).isEmpty,
            "opening chest renders one unified pearl without a duplicate floating pearl on top"
        )

        run(sim, seconds: AquariumSim.coinCooldown + 0.3)
        sim.tapDockNet()
        XCTAssertTrue(
            StickerBook.shared.has(game: AquariumSim.gameID, id: AquaFind.pearl.rawValue),
            "dock net scoops gleaming pearl once chest is open"
        )

        sim.spawnFloatingGift(.bubbleGift, at: CGPoint(x: 420, y: 360))
        sim.pickUp(.net, at: CGPoint(x: 420, y: 360))
        XCTAssertTrue(sim.floatingGifts.isEmpty)
        XCTAssertNil(sim.caught, "scooping a floating gift must not catch nearby fish")
        XCTAssertEqual(sim.fish.count, 1)
        sim.release(home: CGPoint(x: 608, y: AGeo.dockY))
    }

    func testSpeciesDistinctEggPatternsCoverAllElevenSpecies() {
        let patterns = FishKind.allCases.map { AquaEggPattern.forSpecies($0) }
        XCTAssertEqual(patterns.count, 11)
        for i in patterns.indices {
            for j in (i + 1)..<patterns.count {
                XCTAssertNotEqual(patterns[i], patterns[j], "every species has its own distinct egg pattern")
            }
        }
    }

    func testPictorialPlayWishesFulfillViaPlayAndDrainEffectsDeterministically() {
        let sim = freshSim()
        let fIdx = sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 420, y: 360))
        sim.fish[fIdx].dir = 1
        sim.fish[fIdx].facing = 1

        let w1 = sim.spawnPlayWish(kind: .nightGlow)
        XCTAssertNotNil(w1)
        XCTAssertEqual(sim.activeWish?.kind, .nightGlow)
        XCTAssertEqual(sim.spawnPlayWish(kind: .hoopTrick)?.id, w1?.id)
        sim.setLights(false)
        XCTAssertNil(sim.activeWish)
        XCTAssertEqual(Coins.shared.balance, 3)

        sim.setLights(true)
        run(sim, seconds: AquariumSim.coinCooldown + 0.3)
        sim.lastFeedRewardAt = 1000
        sim.fish[fIdx].appetite = 5
        sim.fish[fIdx].dir = 1
        sim.fish[fIdx].facing = 1
        _ = sim.spawnPlayWish(kind: .pearlPellet)
        sim.addFlake(at: CGPoint(x: sim.fish[fIdx].p.x + 12, y: sim.fish[fIdx].p.y), v: .zero, kind: .pearls)
        for _ in 0..<120 { sim.step(dt: 1.0 / 60) }
        XCTAssertNil(sim.activeWish, "eating pearl pellet fulfills .pearlPellet wish")
        let drained = sim.drainEffectsForTesting()
        XCTAssertEqual(drained.coins, 3, "wish payout queues cleanly in deferred outbox")
        XCTAssertEqual(Coins.shared.balance, 6)

        run(sim, seconds: AquariumSim.coinCooldown + 0.3)
        sim.fish[fIdx].p = CGPoint(x: 200, y: 260)
        let bridgeIdx = sim.addDecor(.koiBridge, x: 512)
        _ = sim.spawnPlayWish(kind: .decorPlay(.koiBridge, .swimThrough))
        let bridgeTap = CGPoint(x: 512, y: sim.decor[bridgeIdx].y - 30)
        sim.handBegan(bridgeTap)
        sim.handEnded(bridgeTap, tap: true)
        XCTAssertNil(sim.activeWish)
        XCTAssertEqual(Coins.shared.balance, 9)
    }

    func testSmartEvictionSparesRareAndGrownFromEggFish() {
        let sim = freshSim()
        var rareIDs: Set<Int> = []
        var grownIDs: Set<Int> = []
        for k in 0..<12 {
            let idx = sim.spawn(.axolotl, variant: AquaRare.variant, at: CGPoint(x: 200 + CGFloat(k * 20), y: 360))
            rareIDs.insert(sim.fish[idx].id)
        }
        for k in 0..<10 {
            let idx = sim.spawn(.narwhal, variant: 0, at: CGPoint(x: 460 + CGFloat(k * 20), y: 360), growthStage: 2, grewUp: true)
            grownIDs.insert(sim.fish[idx].id)
        }
        let ord0 = sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 300, y: 300))
        let ord1 = sim.spawn(.clownfish, variant: 0, at: CGPoint(x: 350, y: 300))
        let ordIDs = Set([sim.fish[ord0].id, sim.fish[ord1].id])
        XCTAssertEqual(sim.fish.count, AquariumSim.maxFish)

        sim.addFish(.puffer, x: 500, y: 300)
        sim.addFish(.betta, x: 550, y: 300)
        XCTAssertEqual(sim.fish.count, AquariumSim.maxFish)
        let survivingIDs = Set(sim.fish.map(\.id))
        XCTAssertTrue(rareIDs.isSubset(of: survivingIDs), "all original rare fish survive eviction")
        XCTAssertTrue(grownIDs.isSubset(of: survivingIDs), "all original grown-from-egg fish survive eviction")
        XCTAssertTrue(survivingIDs.isDisjoint(with: ordIDs), "oldest ordinary fish are evicted first")

        for i in sim.fish.indices { sim.fish[i].grewUp = true }
        let protectedIDs = Set(sim.fish.map(\.id))
        sim.addFish(.goldfish, x: 500, y: 300)
        XCTAssertEqual(Set(sim.fish.map(\.id)), protectedIDs, "rare/raised fish must never be silently evicted")
    }

    func testAtomicSchoolingEvictionDeletesZeroFishWhenNotEnoughRoom() {
        let sim = freshSim()
        for k in 0..<22 {
            sim.spawn(.axolotl, variant: AquaRare.variant, at: CGPoint(x: 180 + CGFloat(k * 25), y: 360))
        }
        let ord0 = sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 320, y: 280))
        let ord1 = sim.spawn(.clownfish, variant: 0, at: CGPoint(x: 420, y: 280))
        let beforeIDs = Set(sim.fish.map(\.id))
        let ordIDs = Set([sim.fish[ord0].id, sim.fish[ord1].id])
        XCTAssertEqual(sim.fish.count, AquariumSim.maxFish)

        sim.addFish(.tetra, x: 512, y: 300)
        XCTAssertEqual(sim.fish.count, AquariumSim.maxFish)
        XCTAssertEqual(Set(sim.fish.map(\.id)), beforeIDs, "atomic schooling check deletes zero fish when only 2 ordinary slots exist for 5 tetras")
        XCTAssertTrue(ordIDs.isSubset(of: Set(sim.fish.map(\.id))))
    }

    func testLegacyFishSaveDefaultsGrewUpFalseAndRoundTripsRaisedFish() throws {
        let legacy = """
        {"fish":[{"kind":"goldfish","variant":0}],"decor":[],"moss":[0,0,0,0,0,0,0,0,0,0],"night":false,"pump":true}
        """
        let decoded = try JSONDecoder().decode(AquaSave.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.fish.first?.grewUp, false)

        let sim = freshSim()
        sim.spawn(.axolotl, variant: AquaRare.variant, growthStage: 2, grewUp: true)
        let data = try JSONEncoder().encode(sim.makeSave())
        let back = AquariumSim(save: try JSONDecoder().decode(AquaSave.self, from: data))
        XCTAssertEqual(back.fish.first?.grewUp, true)
        XCTAssertEqual(back.fish.first?.variant, AquaRare.variant)
    }
}
