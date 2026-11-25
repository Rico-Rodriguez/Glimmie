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
        XCTAssertEqual(sim.valveAngle, 0, accuracy: 0.001, "lever is vertical when shut")

        sim.addIngredient(.mermaidWave)
        sim.addIngredient(.bubbleBerry)
        sim.stir()
        run(sim, seconds: 0.6)
        XCTAssertEqual(sim.rare, .mermaid)

        sim.toggleDrain()
        XCTAssertTrue(sim.draining)
        XCTAssertEqual(sim.valveAngle, .pi / 4, accuracy: 0.001, "lever tilts open toward the spout without hitting the pipe or basin")

        run(sim, seconds: 2.5)
        XCTAssertFalse(sim.draining)
        XCTAssertEqual(sim.valveAngle, 0, accuracy: 0.001)
        XCTAssertTrue(sim.ingredients.isEmpty)
        XCTAssertNil(sim.rare)
        XCTAssertEqual(sim.meanColor().1, 0, accuracy: 0.01, "cauldron resets sparkling clean")
        XCTAssertGreaterThan(sim.volume, PotionGeometry.baseVolume * 0.9, "cauldron refills with crystal water ready to brew")
    }

    func testPassiveTicksDoNotAutoCompleteOrAutoBottleWithoutStirring() {
        let sim = freshSim()
        sim.addIngredient(.fairyRose)
        sim.addIngredient(.starGlitter)

        run(sim, seconds: 3.0)
        XCTAssertLessThanOrEqual(sim.mixProgress, 0.55 + 0.001, "passive settling must cap at 0.55 without stirring")
        XCTAssertNil(sim.rare, "2-ingredient recipe must not auto-complete from passive ticks")
        XCTAssertTrue(sim.stand.isEmpty, "2-ingredient recipe must not auto-bottle without stirring")
        XCTAssertEqual(Coins.shared.balance, 0)

        sim.stir()
        XCTAssertEqual(sim.rare, .love)
        XCTAssertEqual(sim.stand.last?.potion, .love)
        XCTAssertEqual(Coins.shared.balance, 4)
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
            sim.stir()
            run(sim, seconds: 0.6)

            XCTAssertEqual(sim.rare, kind, "expected recipe for \(kind)")
            XCTAssertTrue(StickerBook.shared.has(game: PotionSim.gameID, id: kind.rawValue), "instant sticker unlock for \(kind)")
            XCTAssertEqual(Coins.shared.balance, 4, "instant 4 Play Coins reward for \(kind)")
            XCTAssertEqual(sim.stand.last?.potion, kind, "tasting stand receives bottled \(kind)")
            XCTAssertEqual(sim.stand.last?.bottleShape, kind.shape, "bottle uses specialty shape for \(kind)")
        }
    }

    func testRepeatBrewInSameSessionDoesNotFarmCoins() {
        let sim = freshSim()
        sim.addIngredient(.fairyRose)
        sim.addIngredient(.starGlitter)
        sim.stir()
        XCTAssertEqual(sim.rare, .love)
        XCTAssertEqual(Coins.shared.balance, 4)

        // Drain and re-brew the exact same recipe in the same session: zero extra coins.
        sim.toggleDrain()
        run(sim, seconds: 2.5)
        XCTAssertTrue(sim.ingredients.isEmpty)

        sim.addIngredient(.fairyRose)
        sim.addIngredient(.starGlitter)
        sim.stir()
        XCTAssertEqual(sim.rare, .love)
        XCTAssertEqual(Coins.shared.balance, 4, "repeating the same recipe after draining must not farm coins")

        // Brewing a new distinct recipe in the same session still pays 4 coins.
        sim.toggleDrain()
        run(sim, seconds: 2.5)
        sim.addIngredient(.mermaidWave)
        sim.addIngredient(.bubbleBerry)
        sim.stir()
        XCTAssertEqual(sim.rare, .mermaid)
        XCTAssertEqual(Coins.shared.balance, 8)
    }

    func testConditionalRecipesRequireBoilOrMoonlitAndWildPrecedence() {
        // Moonlight needs moonlit == true.
        let moonSim = freshSim()
        moonSim.addIngredient(.sleepyLavender)
        moonSim.addIngredient(.starGlitter)
        moonSim.stir()
        run(moonSim, seconds: 0.6)
        XCTAssertNil(moonSim.rare)
        moonSim.setMoonlit(true)
        XCTAssertEqual(moonSim.rare, .moonlight)

        // Dragon needs burner == .boil.
        let dragonSim = freshSim()
        dragonSim.addIngredient(.dragonChili)
        dragonSim.addIngredient(.starGlitter)
        dragonSim.stir()
        run(dragonSim, seconds: 0.6)
        XCTAssertNil(dragonSim.rare)
        dragonSim.setBurner(.simmer)
        XCTAssertNil(dragonSim.rare)
        dragonSim.setBurner(.boil)
        XCTAssertEqual(dragonSim.rare, .dragon)

        // Specific 3-ingredient recipe wins over .wild even when a 4th distinct ingredient is present.
        let specificSim = freshSim()
        specificSim.addIngredient(.rainbowMane)
        specificSim.addIngredient(.fairyRose)
        specificSim.addIngredient(.mermaidWave)
        specificSim.addIngredient(.frostFlake)
        specificSim.stir()
        XCTAssertEqual(specificSim.rare, .rainbow, "specific recipes must take precedence over .wild")

        // Wild triggers for 4+ distinct ingredients that do not match a specific recipe.
        let wildSim = freshSim()
        wildSim.addIngredient(.frostFlake)
        wildSim.addIngredient(.dragonChili)
        wildSim.addIngredient(.rainbowMane)
        wildSim.addIngredient(.sleepyLavender)
        wildSim.stir()
        run(wildSim, seconds: 0.6)
        XCTAssertEqual(wildSim.rare, .wild)
    }

    func testCustomBrewBottlingAndFiveSlotTastingStandCap() {
        let sim = freshSim()
        sim.addIngredient(.fairyRose)
        sim.addIngredient(.frostFlake)
        sim.stir()
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

    func testSwitchableCreaturesTransformAndResetWithWater() {
        let sim = freshSim()
        XCTAssertEqual(LabCreature.allCases, [.unicorn, .dragon, .kitty, .frog])

        for friend in LabCreature.allCases {
            sim.selectCreature(friend)
            XCTAssertEqual(sim.creature, friend)
        }

        // Mermaid/bubble potion floats creature high.
        sim.addIngredient(.mermaidWave)
        sim.addIngredient(.bubbleBerry)
        sim.stir()
        run(sim, seconds: 0.6)
        let floatEffect = sim.serveBottle(at: 0)
        XCTAssertEqual(floatEffect, .mermaid)
        XCTAssertTrue(sim.hasActiveEffect)
        run(sim, seconds: 1.2)
        XCTAssertLessThan(sim.creatureState.floatY, -80, "creature floats high inside giant bubble")

        // Water drop reset splashes droplets, shakes off effects, and lands smoothly back on cushion.
        sim.resetCreatureEffects()
        XCTAssertNil(sim.creatureState.activeEffect)
        XCTAssertFalse(sim.hasActiveEffect)
        XCTAssertGreaterThan(sim.creatureState.shake, 0.5)
        run(sim, seconds: 1.5)
        XCTAssertEqual(sim.creatureState.floatY, 0, accuracy: 0.5)
    }

    func testUnicornStickersRequireUnicornCreature() {
        XCTAssertNil(TransformationEffect.mermaid.unlocksStickerID(for: .frog))
        XCTAssertNil(TransformationEffect.bubbleFloat.unlocksStickerID(for: .frog))
        XCTAssertNil(TransformationEffect.rainbow.unlocksStickerID(for: .dragon))
        XCTAssertEqual(TransformationEffect.bubbleFloat.unlocksStickerID(for: .unicorn), "floatingUnicorn")
        XCTAssertEqual(TransformationEffect.rainbow.unlocksStickerID(for: .unicorn), "rainbowUnicorn")

        // Feeding mermaid to Frog must NOT unlock floatingUnicorn.
        let frogSim = freshSim()
        frogSim.selectCreature(.frog)
        frogSim.addIngredient(.mermaidWave)
        frogSim.addIngredient(.bubbleBerry)
        frogSim.stir()
        let frogEffect = frogSim.serveBottle(at: 0)
        XCTAssertEqual(frogEffect, .mermaid)
        XCTAssertFalse(frogSim.unlockedStickersInSession.contains("floatingUnicorn"))

        // Feeding bubbleFloat to Unicorn unlocks floatingUnicorn.
        let unicornFloatSim = freshSim()
        unicornFloatSim.selectCreature(.unicorn)
        unicornFloatSim.addIngredient(.bubbleBerry)
        unicornFloatSim.stir()
        guard let bubbleBottle = unicornFloatSim.bottleCurrentBrew() else {
            return XCTFail("Expected custom bubble bottle")
        }
        XCTAssertEqual(bubbleBottle.effect, .bubbleFloat)
        _ = unicornFloatSim.applyToCreature(bubbleBottle)
        XCTAssertTrue(unicornFloatSim.unlockedStickersInSession.contains("floatingUnicorn"))
        XCTAssertTrue(StickerBook.shared.has(game: PotionSim.gameID, id: "floatingUnicorn"))

        // Feeding rainbow to Dragon must NOT unlock rainbowUnicorn, while Unicorn DOES.
        let dragonSim = freshSim()
        dragonSim.selectCreature(.dragon)
        dragonSim.addIngredient(.rainbowMane)
        dragonSim.addIngredient(.fairyRose)
        dragonSim.addIngredient(.mermaidWave)
        dragonSim.stir()
        dragonSim.tapCreature()
        XCTAssertEqual(dragonSim.creatureState.activeEffect, .rainbow)
        XCTAssertFalse(dragonSim.unlockedStickersInSession.contains("rainbowUnicorn"))

        let unicornRainbowSim = freshSim()
        unicornRainbowSim.selectCreature(.unicorn)
        unicornRainbowSim.addIngredient(.rainbowMane)
        unicornRainbowSim.addIngredient(.fairyRose)
        unicornRainbowSim.addIngredient(.mermaidWave)
        unicornRainbowSim.stir()
        unicornRainbowSim.tapCreature()
        XCTAssertEqual(unicornRainbowSim.creatureState.activeEffect, .rainbow)
        XCTAssertTrue(unicornRainbowSim.unlockedStickersInSession.contains("rainbowUnicorn"))
        XCTAssertTrue(StickerBook.shared.has(game: PotionSim.gameID, id: "rainbowUnicorn"))
    }

    func testSaveLoadRoundTripAndLegacySaveCompatibility() throws {
        let sim = freshSim()
        sim.selectCreature(.kitty)
        sim.setMoonlit(true)
        sim.setBurner(.boil)
        sim.addIngredient(.fairyRose)
        sim.addIngredient(.starGlitter)
        sim.stir()
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
            let url = GameFiles.url(sfx.rawValue, "caf", game: "PotionLab")
                ?? GameFiles.url(sfx.rawValue, "wav", game: "PotionLab")
            XCTAssertNotNil(url, "missing bundled audio \(sfx.rawValue)")
        }
    }

    func testHeartCauldronAndFairyLadleTreasureUnlocks() {
        let sim = freshSim()
        XCTAssertFalse(sim.hasHeartCauldron)
        XCTAssertFalse(sim.hasFairyLadle)

        Coins.shared.resetForTests(balance: 60)
        XCTAssertTrue(Coins.shared.buy("potionlab/heartCauldron", price: 14))
        XCTAssertTrue(Coins.shared.buy("potionlab/fairyLadle", price: 12))
        XCTAssertTrue(sim.hasHeartCauldron)
        XCTAssertTrue(sim.hasFairyLadle)

        let center = PotionGeometry.cauldronCenter
        sim.motes.removeAll()
        sim.beginStir(at: CGPoint(x: center.x - 50, y: center.y + 10))
        for k in 0..<40 {
            let a = CGFloat(k) / 40 * 2 * .pi
            sim.moveStir(to: CGPoint(x: center.x + cos(a) * 60, y: center.y + 12 + sin(a) * 48))
            sim.step(dt: 1.0 / 60)
        }
        sim.endStir()
        XCTAssertTrue(sim.motes.contains { $0.kind == .sparkle }, "fairy ladle should trail starlight sparkles when stirring")
    }

    func testLiftedDockClearsWorkbenchAndCreatureControls() {
        XCTAssertEqual(GameChromeLayout.dockY, 740)
        XCTAssertEqual(PotionGeometry.dockY, 740)
        let dockTop = PotionGeometry.dockY - 51

        XCTAssertLessThanOrEqual(PotionGeometry.burnerCenter.y + 28, 650)
        XCTAssertLessThanOrEqual(PotionGeometry.dialCenter.y + PotionGeometry.dialRadius + 5, 650)
        XCTAssertLessThanOrEqual(PotionGeometry.basinRect.maxY, 650)
        XCTAssertLessThan(PotionGeometry.creatureSwitcherCenter.y + 32, dockTop)
        XCTAssertTrue(PotionGeometry.inside(PotionSim.spoonRest))
    }
}
