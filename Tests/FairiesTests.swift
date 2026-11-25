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

    func testAllTwelveFairyDefinitionsAndExactIDs() {
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
    }

    func testStarterStateIsImmediatelyAlive() {
        let sim = freshSim()
        XCTAssertEqual(sim.befriended, [.heart, .star])
        XCTAssertEqual(sim.spotOccupants.count, 2)
        XCTAssertEqual(sim.spotOccupants[.danceStage], .heart)
        XCTAssertEqual(sim.spotOccupants[.cloudBed], .star)
        XCTAssertGreaterThanOrEqual(sim.rustlingSpots.count, 2)
        XCTAssertNil(sim.pinnedFairy)
        XCTAssertNil(defaults.string(forKey: FairyKind.pinnedDefaultsKey))
    }

    func testMeadowRevealAndBefriendAwardsCoinsAndUnlocksStickers() throws {
        let sim = freshSim()
        let spot = try XCTUnwrap(sim.rustlingSpots.first)
        let revealed = try XCTUnwrap(sim.coaxSpot(spot))
        XCTAssertFalse(FairyKind.starters.contains(revealed), "unbefriended fairies should be prioritized first")
        XCTAssertEqual(sim.revealedFairy?.kind, revealed)

        let coinsBefore = Coins.shared.balance
        let caught = sim.befriendRevealedFairy()
        XCTAssertEqual(caught, revealed)
        XCTAssertTrue(sim.befriended.contains(revealed))
        XCTAssertEqual(sim.totalCatches, 1)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + FairiesSim.catchCoinReward)
        XCTAssertTrue(sim.unlockedFinds.contains(.firstFairy))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.firstFairy.rawValue))

        // Catching the Hanbok silk fairy unlocks silkFairy sticker.
        _ = sim.revealFairy(.silk, from: .teacupLantern)
        _ = sim.befriendRevealedFairy()
        XCTAssertTrue(sim.befriended.contains(.silk))
        XCTAssertTrue(sim.unlockedFinds.contains(.silkFairy))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.silkFairy.rawValue))

        // Befriending up to 6 total fairies unlocks rainbowCollection sticker.
        for kind in [FairyKind.berry, .cloud, .ribbon, .moon] where !sim.befriended.contains(kind) {
            _ = sim.revealFairy(kind, from: kind.preferredSpot)
            _ = sim.befriendRevealedFairy()
        }
        XCTAssertGreaterThanOrEqual(sim.befriended.count, 6)
        XCTAssertTrue(sim.unlockedFinds.contains(.rainbowCollection))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.rainbowCollection.rawValue))
    }

    func testRepeatCatchCoinCooldownPreventsInfiniteFarming() {
        let sim = freshSim()
        _ = sim.revealFairy(.heart, from: .blossomBush)
        let startCoins = Coins.shared.balance

        // First repeat catch awards +4 coins because cooldown has elapsed.
        XCTAssertEqual(sim.befriendRevealedFairy(), .heart)
        XCTAssertEqual(Coins.shared.balance, startCoins + FairiesSim.catchCoinReward)

        // Immediate second repeat catch within cooldown awards 0 extra coins.
        _ = sim.revealFairy(.heart, from: .blossomBush)
        XCTAssertEqual(sim.befriendRevealedFairy(), .heart)
        XCTAssertEqual(Coins.shared.balance, startCoins + FairiesSim.catchCoinReward)

        // After repeatCoinCooldown passes, repeat catch awards +4 coins again.
        advance(sim, seconds: FairiesSim.repeatCoinCooldown + 0.5)
        _ = sim.revealFairy(.star, from: .teacupLantern)
        XCTAssertEqual(sim.befriendRevealedFairy(), .star)
        XCTAssertEqual(Coins.shared.balance, startCoins + FairiesSim.catchCoinReward * 2)
    }

    func testWandMagicAndMusicalChimesCoaxAndCatchFairies() throws {
        let sim = freshSim()

        // Ringing a musical chime unlocks musicChime and reveals a fairy.
        let chimeFairy = sim.ringChime(.middle)
        XCTAssertNotNil(chimeFairy)
        XCTAssertEqual(sim.revealedFairy?.kind, chimeFairy)
        XCTAssertTrue(sim.unlockedFinds.contains(.musicChime))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.musicChime.rawValue))

        // Dragging the Heart Magic Wand over the revealed fairy befriends her and unlocks wandMagic.
        let fairyPos = try XCTUnwrap(sim.revealedFairy?.position)
        sim.beginWand(finger: CGPoint(x: fairyPos.x + 60, y: fairyPos.y + 80), lifted: fairyPos)
        sim.endWand()
        XCTAssertTrue(sim.unlockedFinds.contains(.wandMagic))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.wandMagic.rawValue))
        XCTAssertEqual(sim.totalCatches, 1)

        // 1-tap wand sweep coaxes a rustling spot cleanly after celebration finishes.
        advance(sim, seconds: 1.5)
        sim.triggerWandTapMagic()
        advance(sim, seconds: 0.7)
        XCTAssertNotNil(sim.revealedFairy)
    }

    func testCompactSpotPlacementSwapReturnAndAccessories() {
        let sim = freshSim()
        _ = sim.revealFairy(.berry, from: .blossomBush)
        _ = sim.befriendRevealedFairy()

        // Starters occupy danceStage (.heart) and cloudBed (.star); placing .berry on teacupBath reaches 3+ -> compactParty!
        XCTAssertTrue(sim.placeFairy(.berry, at: .teacupBath))
        XCTAssertEqual(sim.spotOccupants.count, 3)
        XCTAssertEqual(sim.spotOccupants[.teacupBath], .berry)
        XCTAssertTrue(sim.unlockedFinds.contains(.compactParty))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.compactParty.rawValue))

        // Dragging .heart from danceStage onto cloudBed swaps .heart and .star.
        sim.beginCompactDrag(fairy: .heart, fromSpot: .danceStage, at: CompactSpot.danceStage.center)
        sim.updateCompactDrag(to: CompactSpot.cloudBed.center)
        sim.endCompactDrag(at: CompactSpot.cloudBed.center)
        XCTAssertEqual(sim.spotOccupants[.cloudBed], .heart)
        XCTAssertEqual(sim.spotOccupants[.danceStage], .star)

        // Dragging .berry down into the return drop zone removes her cleanly from the spot.
        sim.beginCompactDrag(fairy: .berry, fromSpot: .teacupBath, at: CompactSpot.teacupBath.center)
        sim.updateCompactDrag(to: CGPoint(x: 512, y: FGeo.returnDropY + 12))
        XCTAssertTrue(sim.compactReturnHovered)
        sim.endCompactDrag(at: CGPoint(x: 512, y: FGeo.returnDropY + 12))
        XCTAssertNil(sim.spotOccupants[.teacupBath])

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

        // Switching pin to .heart updates UserDefaults immediately.
        XCTAssertEqual(sim.togglePin(.heart), .heart)
        XCTAssertEqual(defaults.string(forKey: FairyKind.pinnedDefaultsKey), "heart")

        // Toggling pin on the already-pinned fairy clears it.
        XCTAssertNil(sim.togglePin(.heart))
        XCTAssertNil(sim.pinnedFairy)
        XCTAssertNil(defaults.string(forKey: FairyKind.pinnedDefaultsKey))
    }

    func testFairiesSaveCodableRoundTrip() throws {
        let original = FairiesSave(
            befriended: [.heart, .star, .silk, .melody],
            spotOccupants: [.danceStage: .silk, .rainbowSwing: .melody, .treatTable: .heart],
            accessories: [.silk: .daenggiRibbon, .heart: .crown],
            pinnedFairy: .silk,
            totalCatches: 7
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FairiesSave.self, from: data)
        XCTAssertEqual(decoded, original)

        // Verify GameStorage round-trip and FairiesSim load + UserDefaults sync in an isolated folder.
        let testGame = "tests-fairies-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(at: GameStorage.folder(testGame)) }
        GameStorage.save(original, game: testGame, file: FairiesSim.saveFile)
        let loaded = GameStorage.load(FairiesSave.self, game: testGame, file: FairiesSim.saveFile)
        XCTAssertEqual(loaded, original)

        let restoredSim = FairiesSim(persist: true, storageGameID: testGame, userDefaults: defaults)
        XCTAssertEqual(restoredSim.befriended, original.befriended)
        XCTAssertEqual(restoredSim.spotOccupants, original.spotOccupants)
        XCTAssertEqual(restoredSim.accessories, original.accessories)
        XCTAssertEqual(restoredSim.pinnedFairy, .silk)
        XCTAssertEqual(restoredSim.totalCatches, 7)
        XCTAssertEqual(defaults.string(forKey: FairyKind.pinnedDefaultsKey), "silk")
    }

    func testAllSixStickersAndTwelveGameRegistryPresence() {
        let expectedStickers = [
            "firstFairy", "wandMagic", "musicChime",
            "compactParty", "rainbowCollection", "silkFairy",
        ]
        XCTAssertEqual(FairiesFind.allCases.count, 6)
        XCTAssertEqual(FairiesFind.allCases.map(\.rawValue), expectedStickers)
        XCTAssertEqual(FairiesGame.entry.stickers.map(\.id), expectedStickers)

        XCTAssertEqual(GameRegistry.all.count, 12)
        XCTAssertEqual(GameRegistry.all.last?.id, "fairies")
        XCTAssertEqual(GameRegistry.all.last?.title, "Fairies")

        // Verify 12 games fit cleanly in a 4 x 3 grid on an 11-inch iPad landscape screen.
        let layout = DrawerLayout.best(count: GameRegistry.all.count, in: CGSize(width: 1194, height: 760))
        XCTAssertEqual(layout.columns, 4)
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
