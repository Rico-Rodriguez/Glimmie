import XCTest
@testable import Glimmie

final class PotionLabTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StickerBook.shared.demo = true
        Coins.shared.resetForTests(balance: 0)
    }

    private func freshSim() -> PotionSim {
        let sim = PotionSim(save: nil)
        sim.demo = true
        sim.trackRewards = true
        return sim
    }

    private func run(_ sim: PotionSim, seconds: Double) {
        let frames = max(1, Int((seconds * 60).rounded()))
        for _ in 0..<frames {
            sim.step(dt: 1.0 / 60)
        }
    }

    func testCauldronLevelFollowsVolumeAndShape() {
        XCTAssertEqual(PotionGeometry.level(for: 0), PotionGeometry.bottomY, accuracy: 0.5)
        XCTAssertEqual(PotionGeometry.level(for: PotionGeometry.capacity), PotionGeometry.rimY, accuracy: 0.5)
        var last = PotionGeometry.bottomY + 1
        for k in 1..<20 {
            let v = PotionGeometry.capacity * CGFloat(k) / 20
            let y = PotionGeometry.level(for: v)
            XCTAssertLessThan(y, last)
            XCTAssertEqual(PotionGeometry.volume(below: y), v, accuracy: v * 0.015)
            last = y
        }
    }

    func testBottleShapesHoldLiquidLevelWhenTipped() {
        for shape in PBottleShape.allCases {
            XCTAssertGreaterThan(shape.area, 2500, "\(shape) should hold potion")
            let poly = PPoly.transform(shape.outline, at: .zero, angle: 0.85, scale: 1)
            let y = PPoly.level(poly, fill: 0.5)
            XCTAssertEqual(PPoly.area(PPoly.below(poly, y)), shape.area * 0.5, accuracy: shape.area * 0.03, "\(shape)")
        }
    }

    func testAddingIngredientGuaranteesIntegerScoopsAndLuminousColor() {
        let sim = freshSim()
        XCTAssertTrue(sim.ingredients.isEmpty)
        XCTAssertEqual(sim.meanColor().1, 0, accuracy: 0.001)

        sim.addIngredient(.fairyRose)
        XCTAssertEqual(sim.ingredients[.fairyRose], 1)
        sim.addIngredient(.fairyRose, from: CGPoint(x: 520, y: 310))
        XCTAssertEqual(sim.ingredients[.fairyRose], 2)

        run(sim, seconds: 0.3)
        let (color, strength) = sim.meanColor()
        XCTAssertGreaterThan(strength, 0.05)
        XCTAssertGreaterThan(color.r, color.g)

        // Mixing complementary hues stays luminous and never collapses to muddy grey/brown.
        let muddyInput = RGB(0.50, 0.48, 0.47)
        let boosted = PotionColor.luminous(muddyInput)
        let spread = max(boosted.r, max(boosted.g, boosted.b)) - min(boosted.r, min(boosted.g, boosted.b))
        XCTAssertGreaterThan(spread, 0.35, "luminous boost must keep mixed potions vibrant")
    }

    func testDirectFingerStirringMovesPaddleSwirlsFluidAndPlaysHarpChimes() {
        let sim = freshSim()
        sim.addIngredient(.fairyRose)
        sim.addIngredient(.starGlitter)

        let center = PotionGeometry.cauldronCenter
        sim.beginStir(at: CGPoint(x: center.x - 55, y: center.y + 10))
        for k in 0..<45 {
            let a = CGFloat(k) / 45 * 2 * .pi
            sim.moveStir(to: CGPoint(x: center.x + cos(a) * 65, y: center.y + 15 + sin(a) * 55))
            sim.step(dt: 1.0 / 60)
        }
        sim.endStir()

        XCTAssertTrue(PotionGeometry.inside(sim.spoon), "stirring paddle stays inside glass")
        XCTAssertGreaterThan(sim.swirl, 0.5, "stirring swirls the liquid")
        XCTAssertFalse(sim.harpNotes.isEmpty, "sweeping the paddle emits harp chimes")
        XCTAssertEqual(sim.rare, .love)
    }

    func testThreeStepBurnerCyclesCleanlyAndBoils() {
        let sim = freshSim()
        XCTAssertEqual(sim.burner, .off)

        sim.cycleBurner()
        XCTAssertEqual(sim.burner, .simmer)

        sim.cycleBurner()
        XCTAssertEqual(sim.burner, .boil)
        run(sim, seconds: 2.0)
        XCTAssertGreaterThan(sim.boiling, 0.5)
        XCTAssertFalse(sim.bubbles.isEmpty)

        sim.cycleBurner()
        XCTAssertEqual(sim.burner, .off)
        let hotTemp = sim.temp
        run(sim, seconds: 3.0)
        XCTAssertLessThan(sim.temp, hotTemp)
    }

    func testFixedDrainValveOrientationAndCleanCauldronReset() {
        let sim = freshSim()
        XCTAssertFalse(sim.draining)
        XCTAssertEqual(sim.valveAngle, 0, accuracy: 0.001, "lever is perpendicular to horizontal pipe when shut")

        sim.addIngredient(.mermaidWave)
        sim.addIngredient(.bubbleBerry)
        run(sim, seconds: 0.6)
        XCTAssertEqual(sim.rare, .mermaid)

        sim.toggleDrain()
        XCTAssertTrue(sim.draining)
        XCTAssertEqual(sim.valveAngle, .pi / 2, accuracy: 0.001, "lever aligns inline with horizontal pipe when open")

        run(sim, seconds: 2.5)
        XCTAssertFalse(sim.draining)
        XCTAssertEqual(sim.valveAngle, 0, accuracy: 0.001)
        XCTAssertTrue(sim.ingredients.isEmpty)
        XCTAssertNil(sim.rare)
        XCTAssertEqual(sim.meanColor().1, 0, accuracy: 0.01, "cauldron resets sparkling clean")
        XCTAssertGreaterThan(sim.volume, PotionGeometry.baseVolume * 0.9, "cauldron refills with crystal water ready to brew")
    }

    func testAllTenRarePotionRecipesUnlockStickersAwardCoinsAndBottleOntoStand() {
        for kind in PotionKind.allCases {
            Coins.shared.resetForTests(balance: 0)
            let sim = freshSim()
            if kind.recipe.requiresBoil { sim.setBurner(.boil) }
            if kind.recipe.requiresMoonlit { sim.setMoonlit(true) }

            for ing in kind.recipe.ingredients {
                sim.addIngredient(ing)
            }
            run(sim, seconds: 0.6)

            XCTAssertEqual(sim.rare, kind, "expected recipe for \(kind)")
            XCTAssertTrue(StickerBook.shared.has(game: PotionSim.gameID, id: kind.rawValue), "instant sticker unlock for \(kind)")
            XCTAssertEqual(Coins.shared.balance, 4, "instant 4 Play Coins reward for \(kind)")
            XCTAssertEqual(sim.stand.last?.potion, kind, "tasting stand receives bottled \(kind)")
            XCTAssertEqual(sim.stand.last?.bottleShape, kind.shape, "bottle uses specialty shape for \(kind)")
        }
    }

    func testConditionalRecipesRequireBoilOrMoonlitAndWildWorksForAnyFourDistinct() {
        // Moonlight needs moonlit == true.
        let moonSim = freshSim()
        moonSim.addIngredient(.sleepyLavender)
        moonSim.addIngredient(.starGlitter)
        run(moonSim, seconds: 0.6)
        XCTAssertNil(moonSim.rare)
        moonSim.setMoonlit(true)
        XCTAssertEqual(moonSim.rare, .moonlight)

        // Dragon needs burner == .boil.
        let dragonSim = freshSim()
        dragonSim.addIngredient(.dragonChili)
        dragonSim.addIngredient(.starGlitter)
        run(dragonSim, seconds: 0.6)
        XCTAssertNil(dragonSim.rare)
        dragonSim.setBurner(.simmer)
        XCTAssertNil(dragonSim.rare)
        dragonSim.setBurner(.boil)
        XCTAssertEqual(dragonSim.rare, .dragon)

        // Wild triggers for any 4+ distinct ingredients.
        let wildSim = freshSim()
        wildSim.addIngredient(.frostFlake)
        wildSim.addIngredient(.dragonChili)
        wildSim.addIngredient(.rainbowMane)
        wildSim.addIngredient(.sleepyLavender)
        run(wildSim, seconds: 0.6)
        XCTAssertEqual(wildSim.rare, .wild)
    }

    func testCustomBrewBottlingAndFiveSlotTastingStandCap() {
        let sim = freshSim()
        sim.addIngredient(.fairyRose)
        sim.addIngredient(.frostFlake)
        run(sim, seconds: 0.6)
        XCTAssertNil(sim.rare)
        XCTAssertTrue(sim.canBottle)

        for _ in 0..<7 {
            let bottled = sim.bottleCurrentBrew()
            XCTAssertNotNil(bottled)
        }
        XCTAssertEqual(sim.stand.count, PotionGeometry.standCapacity)
        XCTAssertEqual(sim.stand.count, 5)
    }

    func testSwitchableCreaturesTransformUnlockStickersAndResetWithWater() {
        let sim = freshSim()
        XCTAssertEqual(LabCreature.allCases, [.unicorn, .dragon, .kitty, .frog])

        for friend in LabCreature.allCases {
            sim.selectCreature(friend)
            XCTAssertEqual(sim.creature, friend)
        }

        // Mermaid/bubble potion floats creature high and unlocks floatingUnicorn sticker.
        sim.addIngredient(.mermaidWave)
        sim.addIngredient(.bubbleBerry)
        run(sim, seconds: 0.6)
        let floatEffect = sim.serveBottle(at: 0)
        XCTAssertEqual(floatEffect, .mermaid)
        XCTAssertTrue(sim.hasActiveEffect)
        XCTAssertTrue(StickerBook.shared.has(game: PotionSim.gameID, id: "floatingUnicorn"))
        run(sim, seconds: 1.2)
        XCTAssertLessThan(sim.creatureState.floatY, -80, "creature floats high inside giant bubble")

        // Water drop reset splashes droplets, shakes off effects, and lands smoothly back on cushion.
        sim.resetCreatureEffects()
        XCTAssertNil(sim.creatureState.activeEffect)
        XCTAssertFalse(sim.hasActiveEffect)
        XCTAssertGreaterThan(sim.creatureState.shake, 0.5)
        run(sim, seconds: 1.5)
        XCTAssertEqual(sim.creatureState.floatY, 0, accuracy: 0.5)

        // Rainbow potion triggers rainbow transformation & unlocks rainbowUnicorn sticker.
        let rainbowSim = freshSim()
        rainbowSim.selectCreature(.dragon)
        rainbowSim.addIngredient(.rainbowMane)
        rainbowSim.addIngredient(.fairyRose)
        rainbowSim.addIngredient(.mermaidWave)
        run(rainbowSim, seconds: 0.6)
        rainbowSim.tapCreature()
        XCTAssertEqual(rainbowSim.creatureState.activeEffect, .rainbow)
        XCTAssertTrue(StickerBook.shared.has(game: PotionSim.gameID, id: "rainbowUnicorn"))
    }

    func testSaveLoadRoundTripAndLegacySaveCompatibility() throws {
        let sim = freshSim()
        sim.selectCreature(.kitty)
        sim.setMoonlit(true)
        sim.setBurner(.boil)
        sim.addIngredient(.fairyRose)
        sim.addIngredient(.starGlitter)
        run(sim, seconds: 0.6)

        let encoded = try JSONEncoder().encode(sim.makeSave())
        let decoded = try JSONDecoder().decode(PotionSave.self, from: encoded)
        let restored = PotionSim(save: decoded)

        XCTAssertEqual(restored.creature, .kitty)
        XCTAssertTrue(restored.moonlit)
        XCTAssertEqual(restored.burner, .boil)
        XCTAssertEqual(restored.ingredients[.fairyRose], 1)
        XCTAssertEqual(restored.ingredients[.starGlitter], 1)
        XCTAssertEqual(restored.stand.count, 1)
        XCTAssertEqual(restored.stand.first?.potion, .love)

        // Legacy potionlab.json format without new fields decodes cleanly.
        let legacyJSON = """
        {
            "bottles": [],
            "nextID": 5,
            "volume": 32000,
            "pr": 0.4,
            "pg": 0.2,
            "pb": 0.6,
            "pa": 0.8,
            "doses": { "nectar": 1.0, "stars": 2.0 },
            "lightsOn": false,
            "heat": 3,
            "made": 4
        }
        """.data(using: .utf8)!
        let legacySave = try JSONDecoder().decode(PotionSave.self, from: legacyJSON)
        let fromLegacy = PotionSim(save: legacySave)
        XCTAssertTrue(fromLegacy.moonlit)
        XCTAssertEqual(fromLegacy.burner, .boil)
        XCTAssertEqual(fromLegacy.creature, .unicorn)
        XCTAssertEqual(fromLegacy.ingredients[.fairyRose], 1)
        XCTAssertEqual(fromLegacy.ingredients[.starGlitter], 2)
    }

    func testStickerBookHasAllTwelvePotionStickers() {
        let ids = Set(PotionGame.entry.stickers.map(\.id))
        XCTAssertEqual(ids.count, 12)
        for kind in PotionKind.allCases {
            XCTAssertTrue(ids.contains(kind.rawValue))
        }
        XCTAssertTrue(ids.contains("rainbowUnicorn"))
        XCTAssertTrue(ids.contains("floatingUnicorn"))
    }

    func testBundledPotionLabAudioExists() {
        for sfx in PotionSFX.allCases {
            XCTAssertNotNil(
                GameFiles.url(sfx.rawValue, "wav", game: "PotionLab"),
                "missing bundled audio \(sfx.rawValue).wav"
            )
        }
    }
}
