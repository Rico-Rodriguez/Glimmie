import XCTest
@testable import Glimmie

final class FairiesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.glimmie.fairies.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        Coins.shared.resetForTests()
        StickerBook.shared.resetForTests()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func freshSim() -> FairiesSim {
        let sim = FairiesSim(persist: false, userDefaults: defaults)
        sim.quiet = true
        return sim
    }

    private func advance(_ sim: FairiesSim, seconds: Double) {
        let steps = Int(seconds * 60)
        for _ in 0..<steps {
            sim.step(dt: 1.0 / 60)
        }
    }

    private func catchFairy(_ sim: FairiesSim, kind: FairyKind, viaWand: Bool = false) {
        sim.transitionToCatchRing(for: kind, from: kind.preferredSpot, startPos: FGeo.catchCenter)
        XCTAssertEqual(sim.befriendActiveFairy(viaWand: viaWand), kind)
    }

    func testAllTwelveFairyDefinitionsAndFourEncounterMappings() {
        let expectedIDs = [
            "heart", "star", "berry", "cloud",
            "ribbon", "moon", "melody", "peach",
            "dewdrop", "honey", "blossom", "silk",
        ]
        XCTAssertEqual(FairyKind.allCases.count, 12)
        XCTAssertEqual(FairyKind.allCases.map(\.rawValue), expectedIDs)
        XCTAssertEqual(FairyKind.starters, [.heart, .star])
        XCTAssertEqual(MeadowSpot.allCases.count, 4)
        XCTAssertEqual(MeadowChime.allCases.count, 3)
        XCTAssertEqual(CompactSpot.allCases.count, 5)
        XCTAssertEqual(FairyAccessory.allCases.count, 5)
        XCTAssertEqual(FairyEncounterKind.allCases.count, 4)

        XCTAssertEqual(FairyKind.allCases.filter { $0.encounterKind == .flutterDash }, [.heart, .ribbon, .blossom])
        XCTAssertEqual(FairyKind.allCases.filter { $0.encounterKind == .bubblePop }, [.cloud, .dewdrop])
        XCTAssertEqual(FairyKind.allCases.filter { $0.encounterKind == .chimeEcho }, [.star, .moon, .melody])
        XCTAssertEqual(FairyKind.allCases.filter { $0.encounterKind == .treatLure }, [.berry, .peach, .honey, .silk])
    }

    func testStarterStateIsImmediatelyAlive() {
        let sim = freshSim()
        XCTAssertEqual(sim.befriended, [.heart, .star])
        XCTAssertEqual(sim.spotOccupants.count, 2)
        XCTAssertEqual(sim.spotOccupants[.danceStage], .heart)
        XCTAssertEqual(sim.spotOccupants[.cloudBed], .star)
        XCTAssertEqual(sim.compactActors.count, 2)
        XCTAssertGreaterThanOrEqual(sim.rustlingSpots.count, 2)
        XCTAssertNil(sim.pinnedFairy)
        XCTAssertNil(defaults.string(forKey: FairyKind.pinnedDefaultsKey))
    }

    // MARK: - 4 Interactive Meadow Mini-Games + Heart Jewel Ring Catch

    func testFlutterDashThreeChasesAdvanceToCatchRing() throws {
        let sim = freshSim()
        XCTAssertEqual(sim.startEncounter(for: .ribbon, from: .rainbowMushroom), .ribbon)

        // Advance so fairy arrives on first perch and verify playful auto-hop after ~2.5s peek.
        advance(sim, seconds: 0.6)
        guard case .flutterDash(let initialDash) = sim.encounter?.phase else {
            return XCTFail("Expected flutterDash phase")
        }
        let firstPerch = initialDash.currentPerchIndex
        advance(sim, seconds: 2.7)
        if case .flutterDash(let hoppedDash) = sim.encounter?.phase {
            XCTAssertNotEqual(hoppedDash.currentPerchIndex, firstPerch)
        } else {
            XCTFail("Expected flutterDash after peek hop")
        }

        // 3 playful chase taps drop star-hearts and transition into Heart Jewel Ring catching!
        for chase in 1...3 {
            guard case .flutterDash(let state) = sim.encounter?.phase else {
                return XCTFail("Expected flutterDash on chase \(chase)")
            }
            sim.tapMeadow(at: state.position)
            if chase < 3 {
                guard case .flutterDash(let nextState) = sim.encounter?.phase else {
                    return XCTFail("Expected flutterDash progress \(chase)")
                }
                XCTAssertEqual(nextState.dashProgress, chase)
                XCTAssertFalse(nextState.starHearts.isEmpty)
            }
        }

        guard case .catching(let ring) = sim.encounter?.phase else {
            return XCTFail("Expected .catching phase after 3 flutterDash chases")
        }
        XCTAssertEqual(sim.encounter?.kind, .ribbon)
        XCTAssertEqual(ring.catchCharge, 0)
    }

    func testBubblePopReleasesFairyToCatchRing() throws {
        let sim = freshSim()
        XCTAssertEqual(sim.startEncounter(for: .dewdrop, from: .bubbleFountain), .dewdrop)

        guard case .bubblePop(let initial) = sim.encounter?.phase else {
            return XCTFail("Expected bubblePop phase")
        }
        XCTAssertEqual(initial.bubbles.count, 6)
        XCTAssertEqual(initial.bubbles.filter(\.containsFairy).count, 1)

        // Popping a decoy bubble removes only that bubble and keeps encounter active.
        let decoy = try XCTUnwrap(initial.bubbles.first(where: { !$0.containsFairy }))
        XCTAssertTrue(sim.popMeadowBubble(id: decoy.id))
        guard case .bubblePop(let afterDecoy) = sim.encounter?.phase else {
            return XCTFail("Decoy pop should remain in bubblePop")
        }
        XCTAssertEqual(afterDecoy.bubbles.count, 5)

        // Popping the shimmering fairy bubble transitions into Heart Jewel Ring catching!
        let fairyBubble = try XCTUnwrap(afterDecoy.bubbles.first(where: \.containsFairy))
        sim.tapMeadow(at: fairyBubble.pos)
        guard case .catching = sim.encounter?.phase else {
            return XCTFail("Popping fairy bubble should transition into .catching")
        }
        XCTAssertEqual(sim.encounter?.kind, .dewdrop)
    }

    func testChimeEchoSequenceForgivingAndSummonsFairyToCatchRing() throws {
        let sim = freshSim()
        let sequence: [MeadowChime] = [.left, .middle, .right]
        XCTAssertEqual(sim.startEncounter(for: .melody, from: .bubbleFountain, chimeSequence: sequence), .melody)

        // Forgiving zero-fail-state: tapping another chime doesn't reset and softly hints the next chime.
        _ = sim.ringChime(.right)
        guard case .chimeEcho(let afterWrong) = sim.encounter?.phase else {
            return XCTFail("Expected chimeEcho after off-order tap")
        }
        XCTAssertEqual(afterWrong.matchedCount, 0)
        XCTAssertEqual(afterWrong.hintedChime, .left)
        XCTAssertTrue(sim.unlockedFinds.contains(.musicChime))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.musicChime.rawValue))

        // Completing the exact melody summons the fairy into Heart Jewel Ring catching!
        _ = sim.ringChime(.left)
        _ = sim.ringChime(.middle)
        _ = sim.ringChime(.right)

        guard case .catching = sim.encounter?.phase else {
            return XCTFail("Completing chimeEcho sequence should transition into .catching")
        }
        XCTAssertEqual(sim.encounter?.kind, .melody)
    }

    func testTreatLureNibblesAndSilkRibbonSwirlAdvanceToCatchRing() throws {
        let sim = freshSim()
        XCTAssertEqual(sim.startEncounter(for: .berry, from: .blossomBush), .berry)
        XCTAssertEqual(sim.activeTreatLureFairy, .berry)
        XCTAssertEqual(sim.availableMeadowTreats, [.strawberry, .honeyDrop, .bungeoppang])

        // Serve 2 yummy treats onto the picnic mat -> 2 happy nibbles -> .catching!
        XCTAssertTrue(sim.serveMeadowTreat(.strawberry))
        advance(sim, seconds: 1.0)
        guard case .treatLure(let afterFirst) = sim.encounter?.phase else {
            return XCTFail("Expected treatLure after first nibble")
        }
        XCTAssertEqual(afterFirst.nibblesCount, 1)

        XCTAssertTrue(sim.serveMeadowTreat(.bungeoppang))
        advance(sim, seconds: 1.0)
        guard case .catching = sim.encounter?.phase else {
            return XCTFail("Expected .catching after 2 happy nibbles")
        }
        XCTAssertNil(sim.activeTreatLureFairy)

        // Verify .silk unlocks the 4th silkSwirl treat and responds to silk ribbon swirl tracing!
        sim.encounter = nil
        XCTAssertEqual(sim.startEncounter(for: .silk, from: .teacupLantern), .silk)
        XCTAssertEqual(sim.availableMeadowTreats, [.strawberry, .honeyDrop, .bungeoppang, .silkSwirl])

        // Trace a sparkling ribbon swirl over the clearing mat to delight .silk (counts as 1 lure step).
        for step in 0...20 {
            let a = CGFloat(step) * 0.35
            let pt = CGPoint(x: FGeo.treatMatCenter.x + cos(a) * 55, y: FGeo.treatMatCenter.y + sin(a) * 35)
            sim.traceSilkRibbon(at: pt)
        }
        guard case .treatLure(let afterSwirl) = sim.encounter?.phase else {
            return XCTFail("Expected treatLure after first silk ribbon swirl")
        }
        XCTAssertEqual(afterSwirl.nibblesCount, 1)

        XCTAssertTrue(sim.serveMeadowTreat(.silkSwirl))
        advance(sim, seconds: 1.0)
        guard case .catching = sim.encounter?.phase else {
            return XCTFail("Expected .catching for .silk after ribbon swirl + silkSwirl treat")
        }
    }

    func testHeartJewelRingWandChargeBefriendsAwardsCoinsAndStickers() throws {
        let sim = freshSim()
        sim.transitionToCatchRing(for: .silk, from: .teacupLantern, startPos: FGeo.catchCenter)
        advance(sim, seconds: 0.45)

        let ringPos = try XCTUnwrap(sim.activeCatchRing?.position)
        let coinsBefore = Coins.shared.balance

        // Holding the Heart Magic Wand over the glowing Heart Jewel Ring charges 0% -> 100% (~1s) and befriends!
        sim.beginWand(finger: CGPoint(x: ringPos.x + 60, y: ringPos.y + 80), lifted: ringPos)
        advance(sim, seconds: 1.15)
        sim.endWand()

        XCTAssertTrue(sim.befriended.contains(.silk))
        XCTAssertEqual(sim.totalCatches, 1)
        XCTAssertNotNil(sim.celebration)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + FairiesSim.catchCoinReward)
        XCTAssertTrue(sim.unlockedFinds.contains(.firstFairy))
        XCTAssertTrue(sim.unlockedFinds.contains(.wandMagic))
        XCTAssertTrue(sim.unlockedFinds.contains(.silkFairy))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.silkFairy.rawValue))

        // Rapid taps on the Heart Ring also charge 0 -> 1 cleanly (3 taps).
        advance(sim, seconds: 1.8)
        sim.transitionToCatchRing(for: .berry, from: .blossomBush, startPos: FGeo.catchCenter)
        advance(sim, seconds: 0.45)
        let berryPos = try XCTUnwrap(sim.activeCatchRing?.position)
        sim.tapMeadow(at: berryPos)
        sim.tapMeadow(at: berryPos)
        sim.tapMeadow(at: berryPos)
        XCTAssertTrue(sim.befriended.contains(.berry))

        // Befriending up to 6 total fairies unlocks rainbowCollection sticker.
        for kind in [FairyKind.cloud, .ribbon, .moon] where !sim.befriended.contains(kind) {
            catchFairy(sim, kind: kind)
        }
        XCTAssertGreaterThanOrEqual(sim.befriended.count, 6)
        XCTAssertTrue(sim.unlockedFinds.contains(.rainbowCollection))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.rainbowCollection.rawValue))
    }

    func testRepeatCatchCoinCooldownPreventsInfiniteFarming() {
        let sim = freshSim()
        let startCoins = Coins.shared.balance

        catchFairy(sim, kind: .heart)
        XCTAssertEqual(Coins.shared.balance, startCoins + FairiesSim.catchCoinReward)

        // Immediate second repeat catch within cooldown awards 0 extra coins.
        catchFairy(sim, kind: .heart)
        XCTAssertEqual(Coins.shared.balance, startCoins + FairiesSim.catchCoinReward)

        // After repeatCoinCooldown passes, repeat catch awards +4 coins again.
        advance(sim, seconds: FairiesSim.repeatCoinCooldown + 0.5)
        catchFairy(sim, kind: .star)
        XCTAssertEqual(Coins.shared.balance, startCoins + FairiesSim.catchCoinReward * 2)
    }

    // MARK: - Alive Free-Roaming Compact Dollhouse

    func testCompactUpToEightRoamingFairiesAndSocialHeartChats() throws {
        let sim = freshSim()
        for kind in FairyKind.allCases where !sim.befriended.contains(kind) {
            catchFairy(sim, kind: kind)
        }
        XCTAssertEqual(sim.befriended.count, 12)
        // Newly befriended fairies auto-welcome up to maxCompactFairies (8).
        XCTAssertEqual(sim.compactActors.count, FairiesSim.maxCompactFairies)

        // Inviting a 9th fairy keeps room gracefully capped at 8.
        XCTAssertTrue(sim.inviteFairyToCompact(.silk))
        XCTAssertEqual(sim.compactActors.count, FairiesSim.maxCompactFairies)

        // Bring two roaming fairies close together in Compact mode -> social heart-chat triggers!
        sim.switchMode(.compact)
        advance(sim, seconds: 2.2)
        for i in sim.compactActors.indices {
            sim.compactActors[i].chatTimer = 0
            sim.compactActors[i].chatPartner = nil
            sim.compactActors[i].chatCooldownUntil = i < 2 ? 0 : 999
            sim.compactActors[i].idleTimer = 10
        }
        sim.compactActors[0].position = CGPoint(x: 480, y: 380)
        sim.compactActors[0].target = CGPoint(x: 480, y: 380)
        sim.compactActors[1].position = CGPoint(x: 520, y: 380)
        sim.compactActors[1].target = CGPoint(x: 520, y: 380)

        advance(sim, seconds: 0.1)
        XCTAssertGreaterThan(sim.compactActors[0].chatTimer, 0)
        XCTAssertEqual(sim.compactActors[0].chatPartner, sim.compactActors[1].kind)
        XCTAssertEqual(sim.compactActors[1].chatPartner, sim.compactActors[0].kind)
        XCTAssertEqual(sim.compactActors[0].mood, .giggle)
    }

    func testCompactWishBubblesAndInteractiveToys() throws {
        let sim = freshSim()
        catchFairy(sim, kind: .berry)
        sim.switchMode(.compact)

        // 1. Wish bubble fulfillment via interactive toy awards +2 coins and clears wish!
        let spawned = try XCTUnwrap(sim.spawnCompactWish(for: .heart, wish: .bubbles))
        XCTAssertEqual(spawned.0, .heart)
        XCTAssertEqual(spawned.1, .bubbles)

        let coinsBefore = Coins.shared.balance
        sim.tapCompact(at: CompactSpot.teacupBath.center)
        XCTAssertNil(sim.compactActor(for: .heart)?.wish)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + FairiesSim.wishCoinReward)
        // Teacup bath also spawned poppable floating soap bubbles!
        XCTAssertEqual(sim.compactBubbles.count, 5)

        let bubblePos = try XCTUnwrap(sim.compactBubbles.first?.pos)
        sim.tapCompact(at: bubblePos)
        XCTAssertEqual(sim.compactBubbles.count, 4)

        // 2. Music Box Disco Party gathers ALL fairies into a joyful dancing circle!
        sim.tapCompact(at: CompactSpot.danceStage.center)
        XCTAssertEqual(sim.discoPartyTimer, FairiesSim.discoPartyDuration, accuracy: 0.01)
        advance(sim, seconds: 1.5)
        XCTAssertTrue(sim.compactActors.allSatisfy { $0.mood == .celebrate })

        // 3. Rainbow Swing pump boosts swing energy!
        sim.discoPartyTimer = 0
        let energyBefore = sim.swingEnergy
        sim.tapCompact(at: CompactSpot.rainbowSwing.center)
        XCTAssertGreaterThan(sim.swingEnergy, energyBefore)

        // 4. Sweet Treat Table spawns interactive treats & pours Celadon Tea when owned!
        Coins.shared.resetForTests(balance: 80)
        XCTAssertTrue(Coins.shared.buy("fairies/hanbokTea", price: 12))
        sim.tapCompact(at: CompactSpot.treatTable.center)
        XCTAssertEqual(sim.compactTableTreats.count, 3)
        XCTAssertGreaterThan(sim.teaPourTimer, 0)

        // 5. Top arch / Chandelier toggles Starlight Night Mode and cozies fairies up!
        _ = sim.spawnCompactWish(for: .star, wish: .sleep)
        sim.tapCompact(at: FGeo.chandelierCenter)
        XCTAssertTrue(sim.isNightMode)
        XCTAssertNil(sim.compactActor(for: .star)?.wish)
        advance(sim, seconds: 1.0)
        XCTAssertTrue(sim.compactActors.allSatisfy { $0.mood == .sleepy })

        // 6. Interactive Cloud Carousel spins faster and hops fairies on when owned!
        XCTAssertTrue(Coins.shared.buy("fairies/carousel", price: 14))
        sim.tapCompact(at: FGeo.carouselCenter)
        XCTAssertFalse(sim.isNightMode)
        XCTAssertGreaterThan(sim.carouselBoostTimer, 0)
        XCTAssertTrue(sim.compactActors.contains(where: \.ridingCarousel))
    }

    func testCompactSpotPlacementSwapReturnAndAccessories() {
        let sim = freshSim()
        catchFairy(sim, kind: .berry)

        // Placing .berry on teacupBath reaches 3+ -> compactParty!
        XCTAssertTrue(sim.placeFairy(.berry, at: .teacupBath))
        XCTAssertEqual(sim.spotOccupants.count, 3)
        XCTAssertEqual(sim.spotOccupants[.teacupBath], .berry)
        XCTAssertTrue(sim.unlockedFinds.contains(.compactParty))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.compactParty.rawValue))

        // Dragging .heart from danceStage onto cloudBed swaps .heart and .star.
        sim.beginCompactDrag(fairy: .heart, fromSpot: .danceStage, at: CompactSpot.danceStage.center, fromRoom: true)
        sim.updateCompactDrag(to: CompactSpot.cloudBed.center)
        sim.endCompactDrag(at: CompactSpot.cloudBed.center)
        XCTAssertEqual(sim.spotOccupants[.cloudBed], .heart)
        XCTAssertEqual(sim.spotOccupants[.danceStage], .star)

        // Dragging .berry down into the return drop zone removes her cleanly from the room.
        sim.beginCompactDrag(fairy: .berry, fromSpot: .teacupBath, at: CompactSpot.teacupBath.center, fromRoom: true)
        sim.updateCompactDrag(to: CGPoint(x: 512, y: FGeo.returnDropY + 12))
        XCTAssertTrue(sim.compactReturnHovered)
        sim.endCompactDrag(at: CGPoint(x: 512, y: FGeo.returnDropY + 12))
        XCTAssertNil(sim.spotOccupants[.teacupBath])
        XCTAssertFalse(sim.isFairyInCompact(.berry))

        // Accessory toggle equips and removes per fairy.
        sim.selectFairy(.heart)
        sim.toggleAccessory(.crown)
        XCTAssertEqual(sim.accessories[.heart], .crown)
        sim.toggleAccessory(.daenggiRibbon)
        XCTAssertEqual(sim.accessories[.heart], .daenggiRibbon)
        sim.toggleAccessory(.daenggiRibbon)
        XCTAssertNil(sim.accessories[.heart])
    }

    func testPinnedFairySyncsWithUserDefaults() {
        let sim = freshSim()
        sim.selectFairy(.star)

        XCTAssertEqual(sim.togglePin(), .star)
        XCTAssertEqual(sim.pinnedFairy, .star)
        XCTAssertEqual(defaults.string(forKey: FairyKind.pinnedDefaultsKey), "star")

        XCTAssertEqual(sim.togglePin(.heart), .heart)
        XCTAssertEqual(defaults.string(forKey: FairyKind.pinnedDefaultsKey), "heart")

        XCTAssertNil(sim.togglePin(.heart))
        XCTAssertNil(sim.pinnedFairy)
        XCTAssertNil(defaults.string(forKey: FairyKind.pinnedDefaultsKey))
    }

    func testFairiesSaveCodableRoundTripAndLegacyDecoding() throws {
        let original = FairiesSave(
            befriended: [.heart, .star, .silk, .melody, .berry, .dewdrop],
            spotOccupants: [.danceStage: .silk, .rainbowSwing: .melody, .treatTable: .heart],
            accessories: [.silk: .daenggiRibbon, .heart: .crown],
            pinnedFairy: .silk,
            totalCatches: 7,
            roamingFairies: [.silk, .melody, .heart, .star, .berry, .dewdrop]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FairiesSave.self, from: data)
        XCTAssertEqual(decoded, original)

        // Verify backward-compatible decoding of legacy saves without roamingFairies!
        let legacyJSON = """
        {
          "befriended": ["heart", "star", "silk"],
          "spotOccupants": { "danceStage": "silk", "cloudBed": "star" },
          "accessories": { "silk": "daenggiRibbon" },
          "pinnedFairy": "silk",
          "totalCatches": 4
        }
        """
        let legacyDecoded = try JSONDecoder().decode(FairiesSave.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(legacyDecoded.befriended, [.heart, .star, .silk])
        XCTAssertEqual(legacyDecoded.spotOccupants, [.danceStage: .silk, .cloudBed: .star])
        XCTAssertEqual(Set(legacyDecoded.roamingFairies), Set([.silk, .star]))
        XCTAssertEqual(legacyDecoded.pinnedFairy, .silk)

        // Verify GameStorage round-trip and FairiesSim load + UserDefaults sync in an isolated folder.
        let testGame = "tests-fairies-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(at: GameStorage.folder(testGame)) }
        GameStorage.save(original, game: testGame, file: FairiesSim.saveFile)
        let loaded = GameStorage.load(FairiesSave.self, game: testGame, file: FairiesSim.saveFile)
        XCTAssertEqual(loaded, original)

        let restoredSim = FairiesSim(persist: true, storageGameID: testGame, userDefaults: defaults)
        XCTAssertEqual(restoredSim.befriended, original.befriended)
        XCTAssertEqual(restoredSim.spotOccupants, original.spotOccupants)
        XCTAssertEqual(restoredSim.compactActors.count, 6)
        XCTAssertEqual(restoredSim.accessories, original.accessories)
        XCTAssertEqual(restoredSim.pinnedFairy, .silk)
        XCTAssertEqual(restoredSim.totalCatches, 7)
        XCTAssertEqual(defaults.string(forKey: FairyKind.pinnedDefaultsKey), "silk")
    }

    func testAllSixStickersAndThirteenGameRegistryPresence() {
        let expectedStickers = [
            "firstFairy", "wandMagic", "musicChime",
            "compactParty", "rainbowCollection", "silkFairy",
        ]
        XCTAssertEqual(FairiesFind.allCases.count, 6)
        XCTAssertEqual(FairiesFind.allCases.map(\.rawValue), expectedStickers)
        XCTAssertEqual(FairiesGame.entry.stickers.map(\.id), expectedStickers)

        XCTAssertEqual(GameRegistry.all.count, 13)
        XCTAssertEqual(GameRegistry.all.last?.id, "fairies")
        XCTAssertEqual(GameRegistry.all.last?.title, "Fairies")

        // Verify 13 games fit cleanly in a 5 x 3 grid on an 11-inch iPad landscape screen.
        let layout = DrawerLayout.best(count: GameRegistry.all.count, in: CGSize(width: 1194, height: 760))
        XCTAssertEqual(layout.columns, 5)
        XCTAssertGreaterThanOrEqual(layout.tile, DrawerLayout.minFitTile)
    }

    func testCompactRoomTreasuresRespondToOwnership() {
        let sim = freshSim()
        XCTAssertFalse(sim.hasChandelier)
        XCTAssertFalse(sim.hasCarousel)
        XCTAssertFalse(sim.hasHanbokTea)

        Coins.shared.resetForTests(balance: 80)
        XCTAssertTrue(Coins.shared.buy("fairies/chandelier", price: 14))
        XCTAssertTrue(sim.hasChandelier)
        XCTAssertFalse(sim.hasCarousel)
        XCTAssertFalse(sim.hasHanbokTea)

        XCTAssertTrue(Coins.shared.buy("fairies/carousel", price: 16))
        XCTAssertTrue(Coins.shared.buy("fairies/hanbokTea", price: 12))
        XCTAssertTrue(sim.hasCarousel)
        XCTAssertTrue(sim.hasHanbokTea)

        sim.switchMode(.compact)
        advance(sim, seconds: 1.0)
        XCTAssertEqual(sim.mode, .compact)
    }
}
