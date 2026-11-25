import XCTest
@testable import Glimmie

final class IceCreamTests: XCTestCase {
    private func freshSim() -> IceSim {
        let sim = IceSim()
        sim.demo = true
        return sim
    }

    private func run(_ sim: IceSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { sim.step(dt: 1.0 / 60) }
    }

    func testScoopingMakesABallThatLandsOnTheCone() {
        let sim = freshSim()
        sim.placeBase(.waffle)
        let c = ICGeo.tubs[0]
        sim.pickUp(.scoop, at: c)
        for k in 0..<90 {
            sim.carry(to: CGPoint(x: c.x - 40 + CGFloat(k % 20) * 4, y: c.y + CGFloat(k % 3)), finger: CGPoint(x: c.x, y: c.y + 120))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertGreaterThan(sim.ball, 0.9)
        XCTAssertEqual(sim.ballFlavor, .vanilla)
        XCTAssertFalse(sim.tubs[0].marks.isEmpty, "the dipper leaves grooves in the tub")
        sim.carry(to: CGPoint(x: sim.S.x + 6, y: sim.S.y - 140), finger: CGPoint(x: sim.S.x, y: sim.S.y))
        sim.step(dt: 1.0 / 60)
        sim.release()
        run(sim, seconds: 2)
        XCTAssertEqual(sim.build.scoops.count, 1)
        XCTAssertTrue(sim.build.scoops[0].landed)
        XCTAssertEqual(sim.build.scoops[0].h, sim.restHeight(0), accuracy: 1)
        XCTAssertEqual(sim.ball, 0)
    }

    func testScoopsStackAndWobble() {
        let sim = freshSim()
        sim.placeBase(.cup)
        sim.dropScoop(flavor: .chocolate, swirl: nil, size: 1, dx: 0, fromY: 200)
        run(sim, seconds: 1.5)
        sim.dropScoop(flavor: .mint, swirl: nil, size: 1, dx: 60, fromY: 100)
        var wobbled = false
        for _ in 0..<60 {
            sim.step(dt: 1.0 / 60)
            if abs(sim.build.scoops[0].wob) > 0.5 { wobbled = true }
        }
        run(sim, seconds: 2)
        XCTAssertTrue(wobbled, "the scoop below takes the knock")
        let a = sim.build.scoops[0], b = sim.build.scoops[1]
        XCTAssertGreaterThan(b.h, a.h + 30)
        XCTAssertLessThanOrEqual(abs(b.dx - a.dx), a.r * 0.35, "a scoop dropped off to one side still sits on the one below")
        XCTAssertEqual(a.wob, 0, accuracy: 0.5)
    }

    func testSoftServeCoilsIntoASwirlAndStops() {
        let sim = freshSim()
        sim.setStation(.soft)
        sim.placeBase(.waffle)
        run(sim, seconds: 0.5)
        let startY = sim.S.y
        sim.pressLever(ICSoft.strawberry.rawValue)
        run(sim, seconds: 6)
        XCTAssertTrue(sim.softFull, "the machine stops when the swirl is tall")
        XCTAssertNil(sim.lever)
        let hs = sim.build.rope.map { $0.h }
        XCTAssertGreaterThan(sim.build.rope.count, 100)
        XCTAssertGreaterThan((hs.max() ?? 0) - (hs.min() ?? 0), 100, "rings climb")
        XCTAssertGreaterThan(sim.S.y, startY + 60, "the stand sinks as the swirl grows")
        run(sim, seconds: 1)
        XCTAssertTrue(sim.build.ropeTipped)
        XCTAssertEqual(sim.build.softFlavor, .strawberry)
        XCTAssertTrue(sim.free.isEmpty)
    }

    func testOrderSwirlIsTheSameHeightInACupAsInACone() {
        for base in [ICBase.waffle, .cup] {
            let rope = ICBuild.sampleSwirl(.vanilla, floor: base.floor)
            let hs = rope.map { $0.h - base.floor }
            XCTAssertLessThan(hs.max() ?? 0, 135, "\(base)")
            XCTAssertLessThan(rope.filter { abs($0.x) < 1 && abs($0.z) < 1 }.count, 20, "\(base): no tower of beads at the tip")
        }
    }

    func testBlenderChopsFruitIntoAColoredDrink() {
        let sim = freshSim()
        sim.setStation(.smoothie)
        for _ in 0..<4 {
            sim.dropFruit(.strawberry, at: CGPoint(x: sim.jarP.x, y: sim.jarP.y - 320), v: .zero)
            run(sim, seconds: 0.3)
        }
        run(sim, seconds: 1)
        XCTAssertEqual(sim.chunks.count, 4)
        for c in sim.chunks {
            XCTAssertLessThan(c.p.y, 0.5, "fruit rests inside the jar")
            XCTAssertLessThanOrEqual(abs(c.p.x), ICGeo.jarHW(c.p.y) - c.r + 1)
        }
        let before = sim.chunks.reduce(CGFloat(0)) { $0 + $1.r * $1.r }
        sim.jarVolume = 0.15
        sim.jarPaint.add(IceSim.milk, 0.15)
        sim.blending = true
        run(sim, seconds: 8)
        let after = sim.chunks.reduce(CGFloat(0)) { $0 + $1.r * $1.r }
        XCTAssertLessThan(after, before * 0.3, "the blades chop it up")
        XCTAssertGreaterThan(sim.jarVolume, 0.18)
        let c = sim.smoothieColor
        XCTAssertGreaterThan(c.r - c.g, 0.2, "strawberries make it pink")
        XCTAssertGreaterThan(sim.jarFruit[ICFruit.strawberry.rawValue], 0)
    }

    func testPouringTheJarFillsTheGlass() {
        let sim = freshSim()
        sim.setStation(.smoothie)
        XCTAssertEqual(sim.build.base, .glass)
        sim.jarVolume = 0.4
        sim.jarPaint.add(ICFruit.mango.juice, 1)
        sim.jarFruit[ICFruit.mango.rawValue] = 0.3
        sim.pickUp(.jar, at: sim.jarP)
        let at = CGPoint(x: sim.S.x - 150, y: sim.S.y - 170)
        for _ in 0..<300 {
            sim.carry(to: at, finger: CGPoint(x: at.x, y: at.y + 180))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertGreaterThan(sim.build.fill, 0.5)
        XCTAssertLessThan(sim.jarVolume, 0.2)
        XCTAssertGreaterThan(sim.build.fruitIn[ICFruit.mango.rawValue], 0.1)
        sim.release()
        run(sim, seconds: 2)
        XCTAssertTrue(sim.jarOnBase, "the jar goes back on the blender")
    }

    func testLiquidLevelKeepsItsVolumeWhenTipped() {
        let sim = freshSim()
        sim.jarVolume = 0.3
        sim.jarTilt = 0
        let poly0 = sim.jarInside()
        let a0 = IceSim.areaBelow(poly0, sim.jarLevel())
        sim.jarTilt = 0.6
        let a1 = IceSim.areaBelow(sim.jarInside(), sim.jarLevel())
        XCTAssertEqual(a0, 0.3 * IceSim.jarArea, accuracy: IceSim.jarArea * 0.01)
        XCTAssertEqual(a1, a0, accuracy: IceSim.jarArea * 0.01)
    }

    func testSprinklesAndSauceLandOnTheTreat() {
        let sim = freshSim()
        sim.placeBase(.waffle)
        sim.dropScoop(flavor: .vanilla, swirl: nil, size: 1, dx: 0, fromY: 200)
        run(sim, seconds: 1.5)
        sim.autoTopping(.sprinkles)
        run(sim, seconds: 2)
        XCTAssertGreaterThan(sim.build.sprinkles.count, 20)
        XCTAssertTrue(sim.build.has(.sprinkles))
        sim.autoTopping(.chocoSauce)
        run(sim, seconds: 3)
        let s = sim.build.sauces.first { $0.topping == .chocoSauce }
        XCTAssertNotNil(s)
        XCTAssertGreaterThan(s?.run.max() ?? 0, 8, "sauce runs down the scoop")
        XCTAssertTrue(sim.build.has(.chocoSauce))
    }

    func testTheCherryBouncesAndSettlesOnTop() {
        let sim = freshSim()
        sim.placeBase(.waffle)
        sim.dropScoop(flavor: .strawberry, swirl: nil, size: 1, dx: 0, fromY: 200)
        run(sim, seconds: 1.5)
        sim.autoTopping(.cherry)
        run(sim, seconds: 3)
        guard let c = sim.build.cherry else { return XCTFail("the cherry stays on") }
        XCTAssertTrue(c.resting)
        let top = sim.build.supportForCherry(c.dx) ?? 0
        XCTAssertEqual(c.h, top + 11, accuracy: 3)
    }

    func testStars() {
        let o = ICOrder(customer: 0, kind: .scoops, base: .waffle, flavors: [ICFlavor.vanilla.rawValue], topping: .cherry)
        var b = ICBuild()
        b.base = .waffle
        b.scoops = [ICScoop(id: 1, flavor: .vanilla, swirl: nil, r: 44, dx: 0, h: 26)]
        XCTAssertEqual(o.stars(for: b), 2)
        b.cherry = ICBody(dx: 0, h: 80, vx: 0, vh: 0, resting: true)
        XCTAssertEqual(o.stars(for: b), 3)
        var other = ICBuild()
        other.base = .cup
        XCTAssertEqual(o.stars(for: other), 1, "always at least one star")
    }

    func testEveryOrderPictureIsItsOwnPerfectTreat() {
        for seed in 0..<60 {
            let o = ICOrder.random(customer: seed % 8, seed: seed)
            let p = o.picture()
            XCTAssertTrue(p.hasTreat, "order \(seed)")
            XCTAssertEqual(o.stars(for: p), 3, "order \(seed): \(o)")
        }
    }

    func testSpecialtyOrdersOnlyAskForTreatsAtTheirStation() {
        for kind in [ICKind.soft, .smoothie] {
            for seed in 0..<30 {
                let order = ICOrder.random(customer: 0, seed: seed, kind: kind)
                XCTAssertEqual(order.kind, kind)
                XCTAssertEqual(order.base == .glass, kind == .smoothie)
                XCTAssertEqual(order.stars(for: order.picture()), 3)
            }
        }
    }

    func testResetClearsTheGlassAndBlenderWhilePouring() {
        let sim = freshSim()
        sim.setStation(.smoothie)
        sim.addToGlass(IceSim.milk, 0.5, fruit: nil)
        sim.jarVolume = 0.4
        sim.jarPaint.add(ICFruit.mango.juice, 1)
        sim.pickUp(.jar, at: sim.jarP)
        XCTAssertNil(sim.serve(), "a drink cannot be served while the jar is held")

        sim.clearStand()

        XCTAssertEqual(sim.build.base, .glass)
        XCTAssertEqual(sim.build.fill, 0)
        XCTAssertEqual(sim.jarVolume, 0)
        XCTAssertTrue(sim.jarOnBase)
        XCTAssertNil(sim.held)
    }

    func testServingClearsTheStand() {
        let sim = freshSim()
        sim.placeBase(.waffle)
        XCTAssertNil(sim.serve(), "nothing to serve yet")
        sim.dropScoop(flavor: .mango, swirl: nil, size: 1, dx: 0, fromY: 200)
        run(sim, seconds: 1)
        let b = sim.serve()
        XCTAssertNotNil(b)
        XCTAssertNil(sim.build.base)
        XCTAssertNotNil(sim.servedPoint())
    }

    func testRealBlendedStrawberriesMatchSmoothieOrder() {
        let sim = freshSim()
        sim.setStation(.smoothie)
        for _ in 0..<3 {
            sim.dropFruit(.strawberry, at: CGPoint(x: sim.jarP.x, y: sim.jarP.y - 320), v: .zero)
            run(sim, seconds: 0.3)
        }
        run(sim, seconds: 0.8)
        sim.jarVolume = 0.25
        sim.jarPaint.add(IceSim.milk, 0.25)
        sim.blending = true
        run(sim, seconds: 8)
        sim.blending = false

        sim.autoPourJar()
        run(sim, seconds: 4.5)
        sim.autoTopping(.straw)

        let order = ICOrder(customer: 0, kind: .smoothie, base: .glass, flavors: [ICFruit.strawberry.rawValue], topping: .straw)
        XCTAssertGreaterThan(sim.build.fill, 0.4)
        XCTAssertGreaterThan(sim.build.fruitIn[ICFruit.strawberry.rawValue], 0.05)
        XCTAssertTrue(order.matches(.base, sim.build))
        XCTAssertTrue(order.matches(.flavor, sim.build), "2-3 real blended strawberries must satisfy smoothie flavor match")
        XCTAssertEqual(order.stars(for: sim.build), 3)
        XCTAssertTrue(sim.jarOnBase)
    }

    func testScoopAutoPlacesWaffleConeAndClearsSmallResidue() {
        let sim = freshSim()
        XCTAssertNil(sim.build.base)
        let c = ICGeo.tubs[2]
        sim.pickUp(.scoop, at: c)
        for k in 0..<40 {
            sim.carry(to: CGPoint(x: c.x - 30 + CGFloat(k % 15) * 4, y: c.y), finger: CGPoint(x: c.x, y: c.y + 110))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertGreaterThan(sim.ball, 0.5)
        sim.carry(to: CGPoint(x: sim.S.x, y: sim.S.y - 120), finger: CGPoint(x: sim.S.x, y: sim.S.y))
        sim.step(dt: 1.0 / 60)
        sim.release()
        run(sim, seconds: 1.5)
        XCTAssertEqual(sim.build.base, .waffle)
        XCTAssertEqual(sim.build.scoops.count, 1)

        // Small dipper residue (< 0.2) clears cleanly when released
        sim.pickUp(.scoop, at: c)
        sim.ball = 0.12
        sim.ballFlavor = .mint
        sim.release()
        XCTAssertEqual(sim.ball, 0)
        XCTAssertNil(sim.ballFlavor)
    }

    func testSoftServeResumesAfterTippedPeakAndTapBurstDispensesLayer() {
        let sim = freshSim()
        sim.setStation(.soft)
        sim.placeBase(.waffle)
        run(sim, seconds: 0.4)
        // 1-tap burst dispenses enough beads to pass hasTreat & softFlavor
        sim.tapLever(ICSoft.vanilla.rawValue)
        run(sim, seconds: 1.5)
        XCTAssertTrue(sim.build.hasTreat, "1 tap on a soft-serve lever produces a servable swirl layer")
        XCTAssertEqual(sim.build.softFlavor, .vanilla)
        XCTAssertTrue(sim.build.ropeTipped)
        let firstCount = sim.build.rope.count

        // Pressing a second flavor lever unfurls the temporary peak and adds more swirls (no soft-lock!)
        sim.pressLever(ICSoft.chocolate.rawValue)
        XCTAssertFalse(sim.build.ropeTipped)
        XCTAssertEqual(sim.lever, ICSoft.chocolate.rawValue)
        run(sim, seconds: 1.2)
        sim.pressLever(nil)
        run(sim, seconds: 1.0)
        XCTAssertGreaterThan(sim.build.rope.count, firstCount + 15)
        XCTAssertTrue(sim.build.rope.contains { $0.c / 2 == ICSoft.chocolate.rawValue })
    }

    func testSoundsAreBundled() {
        XCTAssertFalse(IceSFX.allCases.map { $0.rawValue }.contains("splash"))
        for s in IceSFX.allCases { XCTAssertNotNil(IceSound.url(for: s), s.rawValue) }
    }

    func testBingsuShavesSnowTopsAndScoresThreeStars() {
        let sim = freshSim()
        sim.setStation(.bingsu)
        XCTAssertEqual(sim.build.base, .bowl)
        XCTAssertEqual(sim.build.kind, .bingsu)
        XCTAssertFalse(sim.build.hasTreat)

        sim.tapShaver()
        run(sim, seconds: 1.2)
        XCTAssertGreaterThanOrEqual(sim.build.snowLevel, 0.50, "1 tap must reach >= 0.50 snow so base star is never silently lost")
        XCTAssertTrue(sim.build.hasTreat)

        let order = ICOrder(customer: 0, kind: .bingsu, base: .bowl, flavors: [ICBingsuHero.redBean.rawValue], topping: .condensedMilk)
        XCTAssertTrue(order.matches(.base, sim.build))

        sim.pressShaver(true)
        run(sim, seconds: 2.0)
        sim.pressShaver(false)
        XCTAssertEqual(sim.build.snowLevel, 1, accuracy: 0.01)

        sim.autoTopping(.redBean)
        sim.autoTopping(.mangoCubes)
        sim.autoTopping(.strawberries)
        sim.autoTopping(.injeolmi)
        sim.autoTopping(.condensedMilk)
        run(sim, seconds: 2.4)

        XCTAssertTrue(sim.build.has(.redBean))
        XCTAssertTrue(sim.build.has(.mangoCubes))
        XCTAssertTrue(sim.build.has(.strawberries))
        XCTAssertTrue(sim.build.has(.injeolmi))
        XCTAssertTrue(sim.build.has(.condensedMilk))
        XCTAssertEqual(order.stars(for: sim.build), 3)
    }

    func testDockLayoutIncludesInlineBasesFilteredSmoothieToppingsAndSafeDockY() {
        XCTAssertEqual(ICGeo.dockY, 740)

        let scoop = IceCreamView.dockLayout(for: .scoop)
        XCTAssertTrue(scoop.hasBase)
        XCTAssertEqual(scoop.baseSpots.count, 3)
        XCTAssertEqual(scoop.toppings, ICTopping.parlor)
        XCTAssertLessThan(scoop.baseSpots.last?.x ?? 999, scoop.spots.first?.x ?? 0)

        let soft = IceCreamView.dockLayout(for: .soft)
        XCTAssertTrue(soft.hasBase)
        XCTAssertEqual(soft.baseSpots.count, 3)

        let smoothie = IceCreamView.dockLayout(for: .smoothie)
        XCTAssertFalse(smoothie.hasBase)
        XCTAssertTrue(smoothie.baseSpots.isEmpty)
        XCTAssertEqual(smoothie.toppings, ICTopping.smoothie)
        XCTAssertEqual(smoothie.toppings, [.whip, .cherry, .sprinkles, .straw])
        XCTAssertFalse(smoothie.toppings.contains(.wafer))
        XCTAssertFalse(smoothie.toppings.contains(.chocoSauce))
        XCTAssertFalse(smoothie.toppings.contains(.berrySauce))

        let bingsu = IceCreamView.dockLayout(for: .bingsu)
        XCTAssertFalse(bingsu.hasBase)
        XCTAssertTrue(bingsu.baseSpots.isEmpty)
        XCTAssertEqual(bingsu.toppings, ICTopping.bingsu)
        XCTAssertEqual(bingsu.spots.count, 5)
    }

    func testStandaloneEntryStickersAndStorePersistence() {
        let ids = GameRegistry.all.map(\.id)
        guard let bakeryIdx = ids.firstIndex(of: "bakery"),
              let iceIdx = ids.firstIndex(of: IceSim.gameID) else {
            return XCTFail("both bakery and icecream must be registered")
        }
        XCTAssertEqual(iceIdx, bakeryIdx + 1, "Ice Cream should sit right after Bakery in the drawer")
        XCTAssertEqual(IceCreamGame.entry.id, "icecream")
        XCTAssertEqual(IceCreamGame.entry.title, "Ice Cream")

        let expectedStickers = [
            "scoopMaster", "swirlStar", "smoothiePop",
            "bingsuSnow", "rainbowSundae", "happyParlor",
        ]
        XCTAssertEqual(IceCreamFind.allCases.count, 6)
        XCTAssertEqual(IceCreamFind.allCases.map(\.rawValue), expectedStickers)
        XCTAssertEqual(IceCreamGame.entry.stickers.map(\.id), expectedStickers)

        var sundae = ICBuild()
        sundae.base = .cup
        sundae.scoops = [
            ICScoop(id: 1, flavor: .mint, swirl: nil, r: 44, dx: 0, h: 20),
            ICScoop(id: 2, flavor: .strawberry, swirl: nil, r: 44, dx: 0, h: 80),
        ]
        XCTAssertEqual(Set(IceCreamFind.earned(for: sundae, stars: 3, totalServed: 1)), [.scoopMaster, .rainbowSundae, .happyParlor])

        var bingsu = ICBuild()
        bingsu.base = .bowl
        bingsu.snowLevel = 0.8
        XCTAssertEqual(Set(IceCreamFind.earned(for: bingsu, stars: 2, totalServed: 3)), [.bingsuSnow, .happyParlor])

        let savedBefore = ICStorage.load()
        defer { ICStorage.save(savedBefore) }
        ICStorage.save(ICSave(hearts: 11, served: 4))
        let store = IceCreamStore()
        XCTAssertEqual(store.hearts, 11)
        XCTAssertEqual(store.served, 4)
        store.recordServe(hearts: 3)
        XCTAssertEqual(ICStorage.load(), ICSave(hearts: 14, served: 5))
    }

    func testUnlockedBaseSwappingPreservesScoopsAndSoftServe() {
        let sim = freshSim()
        sim.placeBase(.waffle)
        sim.dropScoop(flavor: .strawberry, swirl: nil, size: 1, dx: 0, fromY: 200)
        run(sim, seconds: 1.5)
        XCTAssertEqual(sim.build.scoops.count, 1)

        sim.placeBase(.cup)
        XCTAssertEqual(sim.build.base, .cup)
        XCTAssertEqual(sim.build.scoops.count, 1, "swapping cone to cup preserves existing scoops")
        XCTAssertEqual(sim.build.scoops[0].flavor, .strawberry)

        sim.placeBase(.choco)
        XCTAssertEqual(sim.build.base, .choco)
        XCTAssertEqual(sim.build.scoops.count, 1)

        let softSim = freshSim()
        softSim.setStation(.soft)
        softSim.placeBase(.waffle)
        run(softSim, seconds: 0.4)
        softSim.tapLever(ICSoft.twist.rawValue)
        run(softSim, seconds: 1.4)
        let beadsBefore = softSim.build.rope.count
        XCTAssertGreaterThan(beadsBefore, 20)
        softSim.placeBase(.cup)
        XCTAssertEqual(softSim.build.base, .cup)
        XCTAssertEqual(softSim.build.rope.count, beadsBefore, "swapping base preserves soft-serve swirls")
    }

    func testOneTapScoopFrontRowLockAndOffConeBallReset() {
        let sim = freshSim()
        // Front-row tub 3 (mint) 1-tap drops mint immediately and auto-places waffle cone
        sim.tapTub(3)
        run(sim, seconds: 1.5)
        XCTAssertEqual(sim.build.base, .waffle)
        XCTAssertEqual(sim.build.scoops.count, 1)
        XCTAssertEqual(sim.build.scoops[0].flavor, .mint)

        // Dragging from front-row tub 5 (mango) locks flavor even when tip lifts upward toward back row
        let front = ICGeo.tubs[5]
        let back = ICGeo.tubs[2]
        sim.pickUpScoop(fromTub: 5, at: front)
        for k in 0..<30 {
            let x = front.x - 24 + CGFloat(k) * 2.5
            sim.carry(to: CGPoint(x: x, y: back.y), finger: CGPoint(x: x, y: front.y))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertGreaterThan(sim.ball, 0.5)
        XCTAssertEqual(sim.ballFlavor, .mango, "front-row drag must never shift into back-row flavor")

        // Releasing off-cone always resets ball to 0 (no stale ball trap!)
        sim.carry(to: CGPoint(x: 200, y: 180), finger: CGPoint(x: 200, y: 260))
        sim.step(dt: 1.0 / 60)
        sim.release()
        XCTAssertEqual(sim.ball, 0)
        XCTAssertNil(sim.ballFlavor)
        XCTAssertNil(sim.scoopLockedTub)
    }

    func testSmoothieAutoMilkBlendAndAutoPourProducesFullMatch() {
        let sim = freshSim()
        sim.setStation(.smoothie)
        // Toss strawberry with ZERO milk poured first, then 1-tap Blend
        sim.tossFruit(.strawberry)
        run(sim, seconds: 0.5)
        XCTAssertEqual(sim.jarVolume, 0, accuracy: 0.001)

        sim.tapBlend()
        XCTAssertGreaterThan(sim.jarVolume, 0.2, "tapping Blend with fruit auto-adds a helpful splash of milk")
        run(sim, seconds: 6.0)

        XCTAssertTrue(sim.jarOnBase, "jar glides home after auto-pour")
        XCTAssertGreaterThanOrEqual(sim.build.fill, 0.35, "auto-milk + blend + auto-pour produces a full servable smoothie")
        XCTAssertTrue(sim.build.hasTreat)
        XCTAssertTrue(sim.canServe)

        let order = ICOrder(customer: 0, kind: .smoothie, base: .glass, flavors: [ICFruit.strawberry.rawValue], topping: .straw)
        XCTAssertTrue(order.matches(.base, sim.build))
        XCTAssertTrue(order.matches(.flavor, sim.build))
    }

    func testRainbowBingsuAndUnicornConeTreasureHooksRespondToOwnership() {
        Coins.shared.resetForTests(balance: 40)
        defer { Coins.shared.resetForTests() }

        XCTAssertEqual(ICArt.rainbowBingsuTreasureID, "icecream/rainbowBingsu")
        XCTAssertFalse(ICArt.hasRainbowBingsu)
        XCTAssertTrue(Coins.shared.buy("icecream/rainbowBingsu", price: 12))
        XCTAssertTrue(ICArt.hasRainbowBingsu)

        // Legacy bakery/rainbowBingsu ownership also unlocks Rainbow Bingsu seamlessly
        Coins.shared.resetForTests(balance: 40)
        XCTAssertFalse(ICArt.hasRainbowBingsu)
        XCTAssertTrue(Coins.shared.buy("bakery/rainbowBingsu", price: 12))
        XCTAssertTrue(ICArt.hasRainbowBingsu)

        // Unicorn Cone treasure hook
        XCTAssertEqual(ICArt.unicornConeTreasureID, "icecream/unicornCone")
        XCTAssertFalse(ICArt.hasUnicornCone)
        XCTAssertTrue(Coins.shared.buy("icecream/unicornCone", price: 10))
        XCTAssertTrue(ICArt.hasUnicornCone)
    }
}
