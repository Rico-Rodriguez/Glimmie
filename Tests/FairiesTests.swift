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

    private func advance(_ sim: FairiesSim, seconds: Double, flush: Bool = true) {
        let steps = Int(seconds * 60)
        for _ in 0..<steps {
            sim.step(dt: 1.0 / 60)
        }
        if flush {
            sim.flushPendingEffects()
        }
    }

    func testDirectLaunchIntoStageWithAllTwelveFairiesUnlocked() {
        let sim = freshSim()
        let expectedIDs = [
            "heart", "star", "berry", "cloud",
            "ribbon", "moon", "melody", "peach",
            "dewdrop", "honey", "blossom", "silk",
        ]

        XCTAssertEqual(sim.station, .stage)
        XCTAssertEqual(FairyKind.allCases.count, 12)
        XCTAssertEqual(FairyKind.allCases.map(\.rawValue), expectedIDs)
        XCTAssertEqual(sim.befriended, FairyKind.allCases)
        XCTAssertEqual(FairyStation.allCases, [.stage, .salon, .teaTable])
        XCTAssertEqual(CompactSpot.allCases.count, 5)
        XCTAssertEqual(FairyAccessory.allCases.count, 5)
        XCTAssertEqual(sim.spotOccupants[.danceStage], .heart)
        XCTAssertEqual(sim.spotOccupants[.cloudBed], .star)
        XCTAssertGreaterThanOrEqual(sim.compactActors.count, 2)
        XCTAssertNil(sim.pinnedFairy)
        XCTAssertNil(defaults.string(forKey: FairyKind.pinnedDefaultsKey))
    }

    func testCanonicalHalfWingMirroringClampingAndBudgetTrimming() throws {
        let clampedLow = WingPoint(u: -0.4, v: -2.0)
        XCTAssertEqual(clampedLow.u, 0)
        XCTAssertEqual(clampedLow.v, -1)
        let clampedHigh = WingPoint(u: 1.8, v: 2.5)
        XCTAssertEqual(clampedHigh.u, 1)
        XCTAssertEqual(clampedHigh.v, 1)

        let rightPoint = FairyWingPainter.toStagePoint(
            WingPoint(u: 0.55, v: -0.35),
            side: 1,
            wingCenter: FGeo.salonWingCenter,
            wingHalfSpan: FGeo.salonWingHalfSpan
        )
        let leftPoint = FairyWingPainter.toStagePoint(
            WingPoint(u: 0.55, v: -0.35),
            side: -1,
            wingCenter: FGeo.salonWingCenter,
            wingHalfSpan: FGeo.salonWingHalfSpan
        )

        let canonicalRight = try XCTUnwrap(
            FairyWingPainter.toCanonical(stagePoint: rightPoint, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)
        )
        let canonicalLeft = try XCTUnwrap(
            FairyWingPainter.toCanonical(stagePoint: leftPoint, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)
        )
        XCTAssertEqual(canonicalRight.u, canonicalLeft.u, accuracy: 0.001)
        XCTAssertEqual(canonicalRight.v, canonicalLeft.v, accuracy: 0.001)

        let outside = CGPoint(x: FGeo.salonWingCenter.x, y: FGeo.salonWingCenter.y)
        XCTAssertNil(FairyWingPainter.toCanonical(stagePoint: outside, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan))

        var bigDesign = FairyWingDesign(
            strokes: (0..<12).map { i in
                WingBrushStroke(
                    color: WingBrushColor.allCases[i % WingBrushColor.allCases.count],
                    points: (0..<25).map { j in WingPoint(u: Float(j) / 30, v: -0.3) }
                )
            },
            glitter: (0..<120).map { _ in WingGlitterFleck(point: WingPoint(u: 0.5, v: -0.3), colorHex: 0xFFE378) },
            stamps: (0..<20).map { _ in WingStamp(kind: .dewdrop, point: WingPoint(u: 0.5, v: -0.3)) }
        )
        bigDesign.trimToBudget()
        XCTAssertLessThanOrEqual(bigDesign.totalStrokePoints, FairyWingDesign.maxStrokePoints)
        XCTAssertLessThanOrEqual(bigDesign.glitter.count, FairyWingDesign.maxGlitterFlecks)
        XCTAssertLessThanOrEqual(bigDesign.stamps.count, FairyWingDesign.maxStamps)
    }

    func testWingSalonPaintingGlitterStickingDewdropStampsWipeUndoAndOneTapParity() throws {
        let sim = freshSim()
        sim.selectStation(.salon)
        sim.selectFairy(.heart)

        let pt1 = FairyWingPainter.toStagePoint(WingPoint(u: 0.42, v: -0.35), side: 1, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)
        let pt2 = FairyWingPainter.toStagePoint(WingPoint(u: 0.62, v: -0.42), side: -1, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)

        XCTAssertTrue(sim.applyWingBrushPoint(at: pt1, color: .rosePearl, startNewStroke: true))
        XCTAssertTrue(sim.applyWingBrushPoint(at: pt2, color: .rosePearl, startNewStroke: false))
        XCTAssertEqual(sim.wingDesign(for: .heart).strokes.count, 1)
        XCTAssertEqual(sim.wingDesign(for: .heart).strokes[0].points.count, 2)
        XCTAssertTrue(sim.unlockedFinds.contains(.firstFairy))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.firstFairy.rawValue))

        sim.selectSalonTool(.brush(.mintDew))
        sim.tapSalonQuickApply()
        sim.selectSalonTool(.brush(.skyOpal))
        sim.tapSalonQuickApply()
        XCTAssertGreaterThanOrEqual(sim.wingDesign(for: .heart).distinctBrushColors.count, 3)
        XCTAssertTrue(sim.unlockedFinds.contains(.rainbowCollection))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.rainbowCollection.rawValue))

        sim.selectSalonTool(.glitter(0xFFE378))
        sim.tapSalonQuickApply()
        XCTAssertFalse(sim.fallingGlitter.isEmpty)
        advance(sim, seconds: 0.8)
        XCTAssertTrue(sim.fallingGlitter.isEmpty)
        XCTAssertFalse(sim.wingDesign(for: .heart).glitter.isEmpty)

        sim.selectSalonTool(.stamp(.dewdrop))
        XCTAssertTrue(sim.placeWingStamp(.dewdrop, at: pt1))
        XCTAssertEqual(sim.wingDesign(for: .heart).stamps.last?.kind, .dewdrop)

        let stampCountBeforeUndo = sim.wingDesign(for: .heart).stamps.count
        XCTAssertTrue(sim.undoSalonAction())
        XCTAssertEqual(sim.wingDesign(for: .heart).stamps.count, stampCountBeforeUndo - 1)

        sim.selectSalonTool(.stamp(.heart))
        sim.tapSalonQuickApply()
        XCTAssertFalse(sim.wingDesign(for: .heart).stamps.isEmpty)

        sim.selectSalonTool(.wipe)
        XCTAssertTrue(sim.eraseWingArt(at: pt1))
        sim.clearCurrentWings()
        XCTAssertTrue(sim.wingDesign(for: .heart).isEmpty)
        XCTAssertTrue(sim.undoSalonAction())
        XCTAssertFalse(sim.wingDesign(for: .heart).isEmpty)
    }

    func testThreePartWandBuilderAndWaveFlourish() {
        let sim = freshSim()
        sim.selectStation(.salon)
        sim.selectFairy(.silk)
        sim.selectSalonTool(.wandBuilder)

        sim.setWandTopper(.crescentMoon)
        sim.setWandShaft(.skyCrystal)
        sim.setWandRibbon(.rainbowStream)

        let wand = sim.currentWand(for: .silk)
        XCTAssertEqual(wand.topper, .crescentMoon)
        XCTAssertEqual(wand.shaft, .skyCrystal)
        XCTAssertEqual(wand.ribbon, .rainbowStream)
        XCTAssertTrue(sim.unlockedFinds.contains(.wandMagic))
        XCTAssertTrue(sim.unlockedFinds.contains(.silkFairy))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.wandMagic.rawValue))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.silkFairy.rawValue))

        sim.tapSalonQuickApply()
        advance(sim, seconds: 0.25)
        XCTAssertFalse(sim.wandTrail.isEmpty)
    }

    func testPixieTeaFullCyclePourFizzTreatServeCoinsAndStageTransformCarryover() throws {
        let sim = freshSim()
        sim.selectFairy(.silk)
        sim.selectStation(.teaTable)

        guard case .awaitingPour(let seatedFairy, let wish, _) = sim.teaSession else {
            return XCTFail("Expected awaitingPour when entering teaTable")
        }
        XCTAssertEqual(seatedFairy, .silk)

        XCTAssertTrue(sim.pourTeapot(wish.nectar))
        advance(sim, seconds: 0.85)
        XCTAssertEqual(sim.teaSession.draft?.nectar, wish.nectar)
        XCTAssertEqual(sim.teaSession.draft?.fillLevel ?? 0, 1.0, accuracy: 0.01)

        XCTAssertTrue(sim.addSugarStar(wish.sugarStar))
        XCTAssertEqual(sim.teaSession.draft?.liquidHex, wish.sugarStar.fizzHex)
        XCTAssertGreaterThan(sim.teaSession.draft?.fizzTimer ?? 0, 0)

        XCTAssertTrue(sim.plateTreat(wish.treat))
        guard case .ready(_, _, let readyDraft) = sim.teaSession else {
            return XCTFail("Expected .ready once nectar + sugar star + treat are complete")
        }
        XCTAssertTrue(readyDraft.isReadyToServe)

        let coinsBefore = Coins.shared.balance
        XCTAssertTrue(sim.serveTea())
        guard case .sipping = sim.teaSession else {
            return XCTFail("Expected .sipping immediately after serveTea()")
        }

        advance(sim, seconds: 1.1)
        guard case .transformed(let transformedFairy, _, let transformKind, _) = sim.teaSession else {
            return XCTFail("Expected .transformed after sipping completes")
        }
        XCTAssertEqual(transformedFairy, .silk)
        XCTAssertEqual(transformKind, wish.sugarStar.transform)
        XCTAssertEqual(sim.lastTeaStars, 3)
        XCTAssertEqual(sim.teasServed, 1)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + Coins.reward(stars: 3))
        XCTAssertTrue(sim.unlockedFinds.contains(.silkFairy))

        sim.selectStation(.stage)
        let carried = try XCTUnwrap(sim.activeTransforms[.silk])
        XCTAssertEqual(carried.kind, transformKind)
        XCTAssertGreaterThan(carried.remaining, 25.0)

        advance(sim, seconds: 31.0)
        XCTAssertNil(sim.activeTransforms[.silk])

        sim.selectStation(.teaTable)
        sim.startNextTeaOrder(for: .heart)
        let heartWish = sim.teaSession.wish
        let wrongNectar = TeaNectar.allCases.first { $0 != heartWish.nectar }!
        let wrongStar = SugarStarKind.allCases.first { $0 != heartWish.sugarStar }!
        let wrongTreat = FairyTeaTreatKind.allCases.first { $0 != heartWish.treat }!
        let coinsBeforeGentle = Coins.shared.balance

        XCTAssertTrue(sim.pourTeapot(wrongNectar))
        advance(sim, seconds: 0.85)
        XCTAssertTrue(sim.addSugarStar(wrongStar))
        XCTAssertTrue(sim.plateTreat(wrongTreat))
        XCTAssertTrue(sim.serveTea())
        advance(sim, seconds: 1.1)
        XCTAssertEqual(sim.lastTeaStars, 1)
        XCTAssertEqual(Coins.shared.balance, coinsBeforeGentle + Coins.reward(stars: 1))
    }

    func testStageRoamingChatsWishesToysPartyCarouselNightModeAndDrag() throws {
        let sim = freshSim()
        for kind in FairyKind.allCases {
            _ = sim.inviteFairyToCompact(kind)
        }
        XCTAssertEqual(sim.compactActors.count, FairiesSim.maxCompactFairies)
        XCTAssertTrue(sim.unlockedFinds.contains(.compactParty))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.compactParty.rawValue))

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

        let wishSpawned = try XCTUnwrap(sim.spawnCompactWish(for: sim.compactActors[0].kind, wish: .bubbles))
        let coinsBefore = Coins.shared.balance
        sim.tapCompact(at: CompactSpot.teacupBath.center)
        XCTAssertNil(sim.compactActor(for: wishSpawned.0)?.wish)
        XCTAssertEqual(Coins.shared.balance, coinsBefore + FairiesSim.wishCoinReward)
        XCTAssertEqual(sim.compactBubbles.count, 5)
        let bubblePos = try XCTUnwrap(sim.compactBubbles.first?.pos)
        sim.tapCompact(at: bubblePos)
        XCTAssertEqual(sim.compactBubbles.count, 4)

        sim.tapCompact(at: CompactSpot.danceStage.center)
        XCTAssertEqual(sim.discoPartyTimer, FairiesSim.discoPartyDuration, accuracy: 0.01)
        XCTAssertTrue(sim.unlockedFinds.contains(.musicChime))
        XCTAssertTrue(StickerBook.shared.has(game: FairiesSim.gameID, id: FairiesFind.musicChime.rawValue))

        sim.discoPartyTimer = 0
        sim.tapCompact(at: CompactSpot.rainbowSwing.center)
        XCTAssertGreaterThan(sim.swingEnergy, 0)

        sim.tapCompact(at: FGeo.chandelierCenter)
        XCTAssertTrue(sim.isNightMode)

        Coins.shared.resetForTests(balance: 80)
        XCTAssertTrue(Coins.shared.buy("fairies/carousel", price: 14))
        XCTAssertTrue(Coins.shared.buy("fairies/hanbokTea", price: 12))
        sim.tapCompact(at: FGeo.carouselCenter)
        XCTAssertFalse(sim.isNightMode)
        XCTAssertGreaterThan(sim.carouselBoostTimer, 0)
        XCTAssertTrue(sim.compactActors.contains(where: \.ridingCarousel))

        XCTAssertTrue(sim.placeFairy(.heart, at: .danceStage))
        XCTAssertTrue(sim.placeFairy(.star, at: .cloudBed))
        sim.beginCompactDrag(fairy: .heart, fromSpot: .danceStage, at: CompactSpot.danceStage.center, fromRoom: true)
        sim.updateCompactDrag(to: CompactSpot.cloudBed.center)
        sim.endCompactDrag(at: CompactSpot.cloudBed.center)
        XCTAssertEqual(sim.spotOccupants[.cloudBed], .heart)
        XCTAssertEqual(sim.spotOccupants[.danceStage], .star)

        sim.beginCompactDrag(fairy: .star, fromSpot: .danceStage, at: CompactSpot.danceStage.center, fromRoom: true)
        sim.updateCompactDrag(to: CGPoint(x: 512, y: FGeo.returnDropY + 12))
        XCTAssertTrue(sim.compactReturnHovered)
        sim.endCompactDrag(at: CGPoint(x: 512, y: FGeo.returnDropY + 12))
        XCTAssertFalse(sim.isFairyInCompact(.star))

        _ = sim.spawnCompactWish(for: .heart, wish: .wingSalon)
        let heartActor = try XCTUnwrap(sim.compactActor(for: .heart))
        let bubbleCenter = CGPoint(x: max(195, min(829, heartActor.position.x + 34)), y: max(172, heartActor.position.y - 78))
        sim.tapCompact(at: bubbleCenter)
        XCTAssertEqual(sim.station, .salon)
    }

    func testPinnedFairyCodecAndDressUpResolveSyncAndMismatchFallback() throws {
        let sim = freshSim()
        sim.selectFairy(.silk)
        sim.toggleAccessory(.daenggiRibbon)
        sim.selectStation(.salon)
        sim.selectSalonTool(.brush(.lilacMist))
        sim.tapSalonQuickApply()
        sim.selectSalonTool(.wandBuilder)
        sim.setWandTopper(.butterflyCrystal)
        sim.setWandShaft(.mintVine)
        sim.setWandRibbon(.celadonJade)

        XCTAssertEqual(sim.togglePin(.silk), .silk)
        XCTAssertEqual(defaults.string(forKey: PinnedFairySpec.defaultsKey), "silk")

        let resolved = try XCTUnwrap(PinnedFairySpec.resolve(from: defaults))
        XCTAssertEqual(resolved.spec.id, "silk")
        XCTAssertEqual(resolved.accessoryID, "daenggiRibbon")
        XCTAssertEqual(resolved.wand?.topper, .butterflyCrystal)
        XCTAssertEqual(resolved.wingDesign?.strokes.first?.color, .lilacMist)

        sim.selectSalonTool(.stamp(.dewdrop))
        sim.tapSalonQuickApply()
        let updatedResolved = try XCTUnwrap(PinnedFairySpec.resolve(from: defaults))
        XCTAssertEqual(updatedResolved.wingDesign?.stamps.last?.kind, .dewdrop)

        XCTAssertNil(sim.togglePin(.silk))
        XCTAssertNil(PinnedFairySpec.resolve(from: defaults))
        XCTAssertNil(defaults.string(forKey: PinnedFairySpec.defaultsKey))
        XCTAssertNil(defaults.data(forKey: PinnedFairyLook.defaultsKey))

        defaults.set("star", forKey: PinnedFairySpec.defaultsKey)
        let legacyOnly = try XCTUnwrap(PinnedFairySpec.resolve(from: defaults))
        XCTAssertEqual(legacyOnly.spec.id, "star")
        XCTAssertNil(legacyOnly.look)

        let wrongLook = PinnedFairyLook(fairyID: "heart", accessoryID: "crown")
        defaults.set(try JSONEncoder().encode(wrongLook), forKey: PinnedFairyLook.defaultsKey)
        let mismatched = try XCTUnwrap(PinnedFairySpec.resolve(from: defaults))
        XCTAssertEqual(mismatched.spec.id, "star")
        XCTAssertNil(mismatched.look)
    }

    func testLegacyFairiesSaveV1MigrationAndF1RoundTrip() throws {
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
        XCTAssertEqual(legacyDecoded.befriended, FairyKind.allCases)
        XCTAssertEqual(legacyDecoded.spotOccupants, [.danceStage: .silk, .cloudBed: .star])
        XCTAssertEqual(Set(legacyDecoded.roamingFairies), Set([.silk, .star]))
        XCTAssertEqual(legacyDecoded.accessories, [.silk: .daenggiRibbon])
        XCTAssertEqual(legacyDecoded.pinnedFairy, .silk)
        XCTAssertEqual(legacyDecoded.totalCatches, 4)
        XCTAssertTrue(legacyDecoded.wingDesigns.isEmpty)
        XCTAssertTrue(legacyDecoded.wands.isEmpty)
        XCTAssertEqual(legacyDecoded.teasServed, 0)

        let customWings = FairyWingDesign(
            strokes: [WingBrushStroke(color: .rosePearl, points: [WingPoint(u: 0.4, v: -0.3), WingPoint(u: 0.7, v: -0.4)])],
            glitter: [WingGlitterFleck(point: WingPoint(u: 0.5, v: -0.2), colorHex: 0xFFE378)],
            stamps: [WingStamp(kind: .dewdrop, point: WingPoint(u: 0.6, v: 0.4))]
        )
        let customWand = FairyWandDesign(topper: .starBurst, shaft: .goldTwist, ribbon: .rainbowStream)
        let original = FairiesSave(
            spotOccupants: [.danceStage: .silk, .rainbowSwing: .melody],
            accessories: [.silk: .daenggiRibbon, .heart: .crown],
            pinnedFairy: .silk,
            totalCatches: 7,
            roamingFairies: [.silk, .melody, .heart],
            wingDesigns: [.silk: customWings],
            wands: [.silk: customWand],
            teasServed: 5
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FairiesSave.self, from: data)
        XCTAssertEqual(decoded, original)

        let testGame = "tests-fairies-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(at: GameStorage.folder(testGame)) }
        GameStorage.save(original, game: testGame, file: FairiesSim.saveFile)

        let restored = FairiesSim(persist: true, storageGameID: testGame, userDefaults: defaults)
        XCTAssertEqual(restored.befriended, FairyKind.allCases)
        XCTAssertEqual(restored.wingDesigns[.silk], customWings)
        XCTAssertEqual(restored.wands[.silk], customWand)
        XCTAssertEqual(restored.teasServed, 5)
        XCTAssertEqual(restored.pinnedFairy, .silk)
        let syncedLook = try XCTUnwrap(PinnedFairySpec.resolve(from: defaults))
        XCTAssertEqual(syncedLook.wingDesign, customWings)
        XCTAssertEqual(syncedLook.wand, customWand)
    }

    func testPostFrameOutboxDeterminismTreasuresAndStickerRegistry() {
        let sim = freshSim()
        sim.deferAllEffectsForTesting = true

        sim.selectFairy(.silk)
        sim.selectStation(.teaTable)
        let wish = sim.teaSession.wish
        _ = sim.pourTeapot(wish.nectar)
        advance(sim, seconds: 0.85, flush: false)
        _ = sim.addSugarStar(wish.sugarStar)
        _ = sim.plateTreat(wish.treat)
        _ = sim.serveTea()
        let coinsBeforeStep = Coins.shared.balance
        advance(sim, seconds: 1.1, flush: false)

        XCTAssertEqual(Coins.shared.balance, coinsBeforeStep)
        let queued = sim.drainEffectsForTesting()
        XCTAssertTrue(queued.contains {
            if case .coins(let amount, _) = $0 { return amount == Coins.reward(stars: 3) }
            return false
        })
        XCTAssertTrue(queued.contains(.sticker(.silkFairy)))

        sim.deferAllEffectsForTesting = false
        Coins.shared.resetForTests(balance: 80)
        XCTAssertFalse(sim.hasChandelier)
        XCTAssertFalse(sim.hasCarousel)
        XCTAssertFalse(sim.hasHanbokTea)
        XCTAssertTrue(Coins.shared.buy("fairies/chandelier", price: 10))
        XCTAssertTrue(Coins.shared.buy("fairies/carousel", price: 14))
        XCTAssertTrue(Coins.shared.buy("fairies/hanbokTea", price: 12))
        XCTAssertTrue(sim.hasChandelier)
        XCTAssertTrue(sim.hasCarousel)
        XCTAssertTrue(sim.hasHanbokTea)

        let expectedStickers = [
            "firstFairy", "wandMagic", "musicChime",
            "compactParty", "rainbowCollection", "silkFairy",
        ]
        XCTAssertEqual(FairiesFind.allCases.map(\.rawValue), expectedStickers)
        XCTAssertEqual(FairiesGame.entry.stickers.map(\.id), expectedStickers)
        XCTAssertEqual(GameRegistry.all.count, 13)
        XCTAssertEqual(GameRegistry.all.last?.id, "fairies")
    }

    func testIdleTeaTableEmitsZeroUIStateCallbacksAcrossSixtyFrames() {
        let sim = freshSim()
        sim.selectStation(.teaTable)
        sim.flushPendingEffects()

        var uiUpdates = 0
        sim.onUIStateChange = { _ in uiUpdates += 1 }

        for _ in 0..<60 {
            sim.step(dt: 1.0 / 60)
            sim.flushPendingEffects()
        }
        XCTAssertEqual(uiUpdates, 0)

        let wish = sim.teaSession.wish
        XCTAssertTrue(sim.pourTeapot(wish.nectar))
        advance(sim, seconds: 0.9)
        XCTAssertTrue(sim.addSugarStar(wish.sugarStar))
        XCTAssertTrue(sim.plateTreat(wish.treat))
        sim.flushPendingEffects()
        XCTAssertEqual(sim.currentUIState().tea.stage, .ready)

        uiUpdates = 0
        for _ in 0..<60 {
            sim.step(dt: 1.0 / 60)
            sim.flushPendingEffects()
        }
        XCTAssertEqual(uiUpdates, 0)

        sim.selectStation(.stage)
        _ = sim.spawnCompactWish(for: sim.selectedFairy, wish: .pixieTea)
        sim.selectStation(.teaTable)
        let activeWish = sim.teaSession.wish
        _ = sim.pourTeapot(activeWish.nectar)
        advance(sim, seconds: 0.9)
        _ = sim.addSugarStar(activeWish.sugarStar)
        _ = sim.plateTreat(activeWish.treat)
        sim.deferAllEffectsForTesting = true
        _ = sim.serveTea()
        advance(sim, seconds: 1.1, flush: false)
        let effects = sim.drainEffectsForTesting()
        let coinEffects = effects.compactMap { effect -> Int? in
            if case .coins(let amount, _) = effect { return amount }
            return nil
        }
        XCTAssertEqual(coinEffects.count, 1)
        XCTAssertEqual(coinEffects.first, Coins.reward(stars: 3) + FairiesSim.wishCoinReward)
    }

    func testReturnDropBadgeMatchesRawFingerDespiteFingerLiftOffset() throws {
        let sim = freshSim()
        XCTAssertTrue(sim.placeFairy(.star, at: .danceStage))
        let actorPos = try XCTUnwrap(sim.compactActor(for: .star)?.position)

        sim.handleSceneDragChanged(start: actorPos, current: CGPoint(x: actorPos.x, y: actorPos.y + 20))
        sim.handleSceneDragChanged(start: actorPos, current: FGeo.returnBadgeCenter)
        XCTAssertTrue(sim.compactReturnHovered)

        sim.handleSceneDragEnded(at: FGeo.returnBadgeCenter, isTap: false)
        XCTAssertFalse(sim.isFairyInCompact(.star))
    }

    func testSalonTapSingleUndoLocalWipePreservesArtAndOffWingOrEraseSplitsStrokes() {
        let sim = freshSim()
        sim.selectStation(.salon)
        sim.selectFairy(.heart)
        sim.selectSalonTool(.brush(.rosePearl))

        let tapPt = FairyWingPainter.toStagePoint(
            WingPoint(u: 0.55, v: -0.35),
            side: 1,
            wingCenter: FGeo.salonWingCenter,
            wingHalfSpan: FGeo.salonWingHalfSpan
        )
        sim.handleSceneDragChanged(start: tapPt, current: tapPt)
        sim.handleSceneDragEnded(at: tapPt, isTap: true)
        XCTAssertEqual(sim.wingDesign(for: .heart).strokes.count, 1)
        XCTAssertTrue(sim.undoSalonAction())
        XCTAssertTrue(sim.wingDesign(for: .heart).isEmpty)

        let upperWing = FairyWingPainter.toStagePoint(WingPoint(u: 0.52, v: -0.36), side: 1, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)
        let spineOffWing = FGeo.salonWingCenter
        let lowerWing = FairyWingPainter.toStagePoint(WingPoint(u: 0.42, v: 0.46), side: 1, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)

        let startFinger = FingerLift.finger(for: upperWing, lift: FingerLift.tool, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
        let f1 = CGPoint(x: startFinger.x + 14, y: startFinger.y)
        let fOff = FingerLift.finger(for: spineOffWing, lift: FingerLift.tool, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
        let f2 = FingerLift.finger(for: lowerWing, lift: FingerLift.tool, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
        sim.handleSceneDragChanged(start: startFinger, current: f1)
        sim.handleSceneDragChanged(start: startFinger, current: fOff)
        sim.handleSceneDragChanged(start: startFinger, current: f2)
        sim.handleSceneDragEnded(at: f2, isTap: false)
        XCTAssertEqual(sim.wingDesign(for: .heart).strokes.count, 2)

        sim.clearCurrentWings()
        let lineUs: [Float] = [0.22, 0.36, 0.50, 0.64, 0.78]
        for (idx, u) in lineUs.enumerated() {
            let p = FairyWingPainter.toStagePoint(WingPoint(u: u, v: -0.32), side: 1, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)
            XCTAssertTrue(sim.applyWingBrushPoint(at: p, color: .skyOpal, startNewStroke: idx == 0))
        }
        XCTAssertEqual(sim.wingDesign(for: .heart).strokes.count, 1)
        let midPt = FairyWingPainter.toStagePoint(WingPoint(u: 0.50, v: -0.32), side: 1, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)
        XCTAssertTrue(sim.eraseWingArt(at: midPt, radius: 0.12))
        XCTAssertEqual(sim.wingDesign(for: .heart).strokes.count, 2)

        sim.clearCurrentWings()
        XCTAssertTrue(sim.placeWingStamp(.dewdrop, at: upperWing))
        XCTAssertTrue(sim.placeWingStamp(.heart, at: lowerWing))
        sim.selectSalonTool(.wipe)
        sim.tapSalonQuickApply(near: upperWing)
        XCTAssertEqual(sim.wingDesign(for: .heart).stamps.count, 1)
        XCTAssertEqual(sim.wingDesign(for: .heart).stamps.first?.kind, .heart)
    }

    func testCarouselDropAssignsDistinctSeatsAndEvictsSeatZeroWhenFull() {
        let sim = freshSim()
        Coins.shared.resetForTests(balance: 80)
        XCTAssertTrue(Coins.shared.buy("fairies/carousel", price: 14))

        let firstFour: [FairyKind] = [.heart, .star, .berry, .cloud]
        for fairy in firstFour {
            sim.beginCompactDrag(fairy: fairy, fromSpot: nil, at: FGeo.carouselCenter, fromRoom: false)
            sim.endCompactDrag(at: FGeo.carouselCenter)
        }
        let riders = sim.compactActors.filter(\.ridingCarousel)
        XCTAssertEqual(riders.count, 4)
        XCTAssertEqual(Set(riders.map(\.carouselSeatIndex)), Set([0, 1, 2, 3]))

        let originalSeatZero = riders.first { $0.carouselSeatIndex == 0 }?.kind
        sim.beginCompactDrag(fairy: .ribbon, fromSpot: nil, at: FGeo.carouselCenter, fromRoom: false)
        sim.endCompactDrag(at: FGeo.carouselCenter)

        let updatedRiders = sim.compactActors.filter(\.ridingCarousel)
        XCTAssertEqual(updatedRiders.count, 4)
        XCTAssertEqual(Set(updatedRiders.map(\.carouselSeatIndex)), Set([0, 1, 2, 3]))
        XCTAssertEqual(sim.compactActor(for: .ribbon)?.carouselSeatIndex, 0)
        if let evicted = originalSeatZero {
            XCTAssertFalse(sim.compactActor(for: evicted)?.ridingCarousel ?? true)
        }
    }
}
