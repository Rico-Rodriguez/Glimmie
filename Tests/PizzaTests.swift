import XCTest
@testable import Glimmie

final class PizzaTests: XCTestCase {
    private func freshSim() -> PizzaSim {
        let sim = PizzaSim(load: false)
        sim.demo = true
        sim.order = PizzaOrder(customer: 0, wants: [.pepperoni, .olive])
        sim.selectedTopping = .pepperoni
        return sim
    }

    private func run(_ sim: PizzaSim, seconds: Double) {
        let steps = max(1, Int((seconds * 60).rounded()))
        for _ in 0..<steps { sim.step(dt: 1.0 / 60) }
    }

    private func swipe(_ sim: PizzaSim, from a: CGPoint, to b: CGPoint, frames: Int = 10) {
        sim.handBegan(a)
        sim.step(dt: 1.0 / 60)
        for i in 1...max(1, frames) {
            let u = CGFloat(i) / CGFloat(max(1, frames))
            let p = CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)
            sim.handMoved(p, dt: 1.0 / 60)
            sim.step(dt: 1.0 / 60)
        }
        sim.handEnded(b, tap: false)
    }

    func testThreeStageFlowEndToEnd() {
        Coins.shared.resetForTests(balance: 0)
        defer { Coins.shared.resetForTests() }

        XCTAssertEqual(PizzaStep.allCases, [.dough, .prep, .bake, .slice])
        let sim = freshSim()
        XCTAssertEqual(sim.stage, .dough)

        // Stage 1: Fast rolling-pin expansion + fun crust shape
        swipe(sim, from: CGPoint(x: PGeo.center.x - 100, y: PGeo.center.y), to: CGPoint(x: PGeo.center.x + 100, y: PGeo.center.y), frames: 8)
        swipe(sim, from: CGPoint(x: PGeo.center.x, y: PGeo.center.y - 100), to: CGPoint(x: PGeo.center.x, y: PGeo.center.y + 100), frames: 8)
        sim.setCrustShape(.heart)
        run(sim, seconds: 0.4)
        XCTAssertFalse(sim.ball)
        XCTAssertTrue(sim.ready(.dough))

        // Stage 2: Open Prep (sauce + cheese + wanted toppings)
        sim.go(.prep)
        XCTAssertEqual(sim.stage, .prep)
        sim.selectSauce(.goguma)
        swipe(sim, from: CGPoint(x: PGeo.center.x - 120, y: PGeo.center.y), to: CGPoint(x: PGeo.center.x + 120, y: PGeo.center.y), frames: 4)
        sim.selectCheese(.cornCheese)
        sim.sprinkleBurstCheese()
        run(sim, seconds: 0.5)
        sim.selectTopping(.pepperoni)
        sim.handBegan(CGPoint(x: PGeo.center.x - 40, y: PGeo.center.y))
        sim.handEnded(CGPoint(x: PGeo.center.x - 40, y: PGeo.center.y), tap: true)
        sim.handBegan(CGPoint(x: PGeo.center.x + 40, y: PGeo.center.y))
        sim.handEnded(CGPoint(x: PGeo.center.x + 40, y: PGeo.center.y), tap: true)
        sim.selectTopping(.olive)
        sim.handBegan(CGPoint(x: PGeo.center.x, y: PGeo.center.y - 40))
        sim.handEnded(CGPoint(x: PGeo.center.x, y: PGeo.center.y - 40), tap: true)
        sim.handBegan(CGPoint(x: PGeo.center.x, y: PGeo.center.y + 40))
        sim.handEnded(CGPoint(x: PGeo.center.x, y: PGeo.center.y + 40), tap: true)
        XCTAssertTrue(sim.ready(.prep))

        // Stage 3a: Brisk 3.5s wood-fired oven
        sim.go(.bake)
        XCTAssertTrue(sim.inOven)
        run(sim, seconds: PGeo.bakeTime + 0.7)
        XCTAssertEqual(sim.bake, 1, accuracy: 0.001)
        XCTAssertTrue(sim.ready(.bake))

        // Stage 3b: Pull out -> direct swipe slice -> serve stretchy slice
        sim.pullFromOven()
        XCTAssertEqual(sim.stage, .slice)
        XCTAssertFalse(sim.inOven)
        swipe(sim, from: CGPoint(x: PGeo.center.x - 160, y: PGeo.center.y), to: CGPoint(x: PGeo.center.x + 160, y: PGeo.center.y), frames: 8)
        XCTAssertEqual(sim.cuts.count, 1)
        let firstSlice = sim.slices[0]
        let mid = (firstSlice.0 + firstSlice.1) / 2
        let tapPt = CGPoint(x: PGeo.center.x + CGFloat(cos(mid)) * 90, y: PGeo.center.y + CGFloat(sin(mid)) * 90)
        sim.handBegan(tapPt)
        sim.handEnded(tapPt, tap: true)
        XCTAssertNotNil(sim.lifted)
        XCTAssertFalse(sim.lifted?.strings.isEmpty ?? true)
        XCTAssertEqual(sim.stars, 3)
        XCTAssertEqual(Coins.shared.balance, Coins.reward(stars: 3))
    }

    func testFastRollingPinExpansionViaTapsAndSwipes() {
        // 3 easy taps expand ball -> full crust with zero grind
        let tapSim = freshSim()
        let c = PGeo.center
        for _ in 0..<3 {
            tapSim.handBegan(c)
            run(tapSim, seconds: 0.06)
            tapSim.handEnded(c, tap: true)
            run(tapSim, seconds: 0.12)
        }
        XCTAssertFalse(tapSim.ball)
        XCTAssertGreaterThanOrEqual(tapSim.rollProgress, 0.99)
        XCTAssertTrue(tapSim.ready(.dough))
        run(tapSim, seconds: 0.5)
        XCTAssertGreaterThan(tapSim.meanR, 195)

        // 2 quick swipes across the dough expand smoothly without snap-back
        let swipeSim = freshSim()
        swipe(swipeSim, from: CGPoint(x: c.x - 95, y: c.y), to: CGPoint(x: c.x + 95, y: c.y), frames: 8)
        let afterFirst = swipeSim.rollProgress
        XCTAssertFalse(swipeSim.ball)
        XCTAssertGreaterThan(afterFirst, 0.45)
        swipe(swipeSim, from: CGPoint(x: c.x, y: c.y - 95), to: CGPoint(x: c.x, y: c.y + 95), frames: 8)
        XCTAssertGreaterThanOrEqual(swipeSim.rollProgress, 0.85)
        XCTAssertTrue(swipeSim.ready(.dough))
        run(swipeSim, seconds: 0.6)
        XCTAssertGreaterThan(swipeSim.meanR, 190)
    }

    func testAllFourCrustShapesMorphSmoothly() {
        XCTAssertEqual(CrustShape.allCases, [.round, .heart, .star, .kitty])
        let sim = freshSim()
        for shape in CrustShape.allCases {
            sim.setCrustShape(shape)
            run(sim, seconds: 0.6)
            XCTAssertFalse(sim.ball)
            XCTAssertEqual(sim.crustShape, shape)
            XCTAssertLessThanOrEqual(sim.r.max() ?? 0, PGeo.maxR + 14)
            XCTAssertGreaterThan(sim.r.min() ?? 0, 70)
        }

        // Verify distinct silhouettes
        sim.setCrustShape(.kitty)
        run(sim, seconds: 0.6)
        XCTAssertGreaterThan(sim.edge(-.pi / 2 - 0.62), sim.edge(-.pi / 2) + 18, "kitty ears must rise above forehead")

        sim.setCrustShape(.heart)
        run(sim, seconds: 0.6)
        XCTAssertGreaterThan(sim.edge(-.pi / 2 - 0.55), sim.edge(-.pi / 2) + 20, "heart lobes must rise above center cleft")

        sim.setCrustShape(.star)
        run(sim, seconds: 0.6)
        XCTAssertGreaterThan(sim.edge(-.pi / 2), sim.edge(-.pi / 2 + .pi / 5) + 28, "star tips must extend beyond valleys")
    }

    func testOptionalAirTossLandsExpanded() {
        let sim = freshSim()
        sim.triggerToss()
        XCTAssertNotNil(sim.tossStart)
        run(sim, seconds: 1.4)
        XCTAssertNil(sim.tossStart)
        XCTAssertFalse(sim.ball)
        XCTAssertEqual(sim.rollProgress, 1, accuracy: 0.001)
        XCTAssertTrue(sim.ready(.dough))
    }

    func testFastDragSaucePaintingRegressionCoatsAtHighSpeed() {
        XCTAssertEqual(SauceKind.allCases, [.tomato, .garlicWhite, .goguma])
        let sim = freshSim()
        sim.demoDisc(216)
        sim.go(.prep)
        sim.selectSauce(.tomato)

        // Ultra-fast drag (~6600 pt/s across 3 frames) — previously poured ZERO sauce due to speedFactor cutoff!
        let start = CGPoint(x: PGeo.center.x - 165, y: PGeo.center.y)
        let end = CGPoint(x: PGeo.center.x + 165, y: PGeo.center.y)
        swipe(sim, from: start, to: end, frames: 3)
        XCTAssertGreaterThan(sim.totalSauce, 60, "high-speed drag must paint continuous lush sauce")
        XCTAssertGreaterThan(sim.coverage(sim.sauce, above: 0.14), 0.25)

        // All 3 sauces + 1-tap Swirl-Fill
        sim.swirlFillSauce(.garlicWhite)
        XCTAssertGreaterThan(sim.sauceCoverage, 0.85)
        XCTAssertTrue(sim.saucePalette.contains(SauceKind.garlicWhite.paletteID))

        sim.swirlFillSauce(.goguma)
        XCTAssertGreaterThan(sim.sauceCoverage, 0.85)
        XCTAssertTrue(sim.saucePalette.contains(SauceKind.goguma.paletteID))
    }

    func testSpreadingSauceConservesMass() {
        let sim = freshSim()
        sim.demoDisc(216)
        let c = PGeo.center
        sim.pour(at: c, amount: 60)
        let total = sim.totalSauce
        XCTAssertGreaterThan(total, 0)
        var p = c
        for k in 0..<240 {
            let a = Double(k) * 0.12
            let rr = 20 + CGFloat(k) / 240 * 155
            let q = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            sim.flowSauce()
            sim.spread(at: q, by: CGPoint(x: q.x - p.x, y: q.y - p.y))
            p = q
        }
        XCTAssertEqual(sim.totalSauce, total, accuracy: total * 0.01)
    }

    func testCheeseCoatsQuicklyInTwoSwipesAndSupportsBothKinds() {
        XCTAssertEqual(CheeseKind.allCases, [.mozzarella, .cornCheese])
        let sim = freshSim()
        sim.demoDisc(216)
        sim.go(.prep)
        sim.selectCheese(.cornCheese)
        XCTAssertEqual(sim.cheeseKind, .cornCheese)

        // Two quick swipes coat >60% without needing 6 seconds of grinding
        swipe(sim, from: CGPoint(x: PGeo.center.x - 160, y: PGeo.center.y - 68),
              to: CGPoint(x: PGeo.center.x + 160, y: PGeo.center.y - 68), frames: 12)
        swipe(sim, from: CGPoint(x: PGeo.center.x - 160, y: PGeo.center.y + 68),
              to: CGPoint(x: PGeo.center.x + 160, y: PGeo.center.y + 68), frames: 12)
        run(sim, seconds: 0.6)
        XCTAssertGreaterThan(sim.landed, 120)
        XCTAssertGreaterThan(sim.cheeseCoverage, 0.60, "2 quick cheese swipes must coat >60%")

        // 1-tap sprinkle burst also covers generously
        let burstSim = freshSim()
        burstSim.demoDisc(216)
        burstSim.go(.prep)
        burstSim.sprinkleBurstCheese(.mozzarella)
        run(burstSim, seconds: 0.6)
        XCTAssertGreaterThan(burstSim.landed, 100)
        XCTAssertGreaterThan(burstSim.cheeseCoverage, 0.55)
    }

    func testOneTapToppingStampingNeverDropsSelection() {
        let sim = freshSim()
        sim.demoDisc(216)
        sim.go(.prep)
        sim.selectTopping(.goguma)
        XCTAssertEqual(sim.prepTab, .toppings)
        XCTAssertEqual(sim.selectedTopping, .goguma)

        let spots = [
            CGPoint(x: PGeo.center.x - 60, y: PGeo.center.y),
            CGPoint(x: PGeo.center.x, y: PGeo.center.y + 50),
            CGPoint(x: PGeo.center.x + 65, y: PGeo.center.y - 45)
        ]
        for pt in spots {
            sim.handBegan(pt)
            sim.handEnded(pt, tap: true)
            XCTAssertEqual(sim.selectedTopping, .goguma, "stamping must never drop selected topping")
        }
        XCTAssertEqual(sim.toppings.count, 3)
        XCTAssertTrue(sim.toppings.allSatisfy { $0.kind == .goguma })
    }

    func testBriskOvenBakeAndEarlyPullOut() {
        XCTAssertEqual(PGeo.bakeTime, 3.5, accuracy: 0.0001)
        let sim = freshSim()
        sim.demoDisc(216)
        sim.demoSauce(.tomato)
        sim.demoCheese(160)
        sim.go(.bake)
        XCTAssertTrue(sim.inOven)

        run(sim, seconds: PGeo.bakeTime + 0.7)
        XCTAssertEqual(sim.bake, 1, accuracy: 0.0001)
        XCTAssertEqual(sim.melt, 1, accuracy: 0.0001)
        XCTAssertTrue(sim.ready(.bake))

        // Early pull-out once bake >= 0.45 by tapping the pizza directly in the oven
        let early = freshSim()
        early.demoDisc(216)
        early.demoSauce(.tomato)
        early.go(.bake)
        run(early, seconds: 2.1)
        XCTAssertGreaterThanOrEqual(early.bake, 0.45)
        XCTAssertTrue(early.canPullFromOven)
        early.handBegan(PGeo.ovenCenter)
        XCTAssertEqual(early.stage, .slice)
        XCTAssertFalse(early.inOven)

        // Stoking accelerates baking
        let stoked = freshSim()
        stoked.demoDisc(216)
        stoked.go(.bake)
        run(stoked, seconds: 0.4)
        stoked.stoke()
        let plain = freshSim()
        plain.demoDisc(216)
        plain.go(.bake)
        run(plain, seconds: 0.4)
        run(stoked, seconds: 1.0)
        run(plain, seconds: 1.0)
        XCTAssertGreaterThan(stoked.bake, plain.bake + 0.08)
    }

    func testDirectSwipeSlicingNeverFeedsUncutPie() {
        Coins.shared.resetForTests(balance: 0)
        defer { Coins.shared.resetForTests() }

        let sim = freshSim()
        sim.demoDisc(216)
        sim.demoSauce(.tomato)
        sim.demoCheese(180)
        sim.bake = 1
        sim.go(.slice)
        XCTAssertTrue(sim.cuts.isEmpty)
        XCTAssertFalse(sim.canServe)

        // Tapping an uncut pie or calling serveSlice directly MUST NOT feed it!
        sim.handBegan(PGeo.center)
        sim.handEnded(PGeo.center, tap: true)
        XCTAssertNil(sim.lifted, "must never feed an uncut pie")
        XCTAssertNil(sim.stars)
        XCTAssertEqual(Coins.shared.balance, 0)
        XCTAssertGreaterThanOrEqual(sim.cutterNudgeAt, 0)

        sim.serveSlice(at: PGeo.center)
        XCTAssertNil(sim.lifted, "serveSlice must refuse uncut pie")

        // Short swipe (<90pt) does not cut or feed
        swipe(sim, from: CGPoint(x: PGeo.center.x - 25, y: PGeo.center.y), to: CGPoint(x: PGeo.center.x + 25, y: PGeo.center.y), frames: 4)
        XCTAssertTrue(sim.cuts.isEmpty)
        XCTAssertNil(sim.lifted)

        // Direct finger swipe (>=90pt across pizza) cleanly cuts into 2 slices without feeding!
        swipe(sim, from: CGPoint(x: PGeo.center.x - 160, y: PGeo.center.y + 12),
              to: CGPoint(x: PGeo.center.x + 160, y: PGeo.center.y - 8), frames: 8)
        XCTAssertEqual(sim.cuts.count, 1)
        XCTAssertEqual(sim.slices.count, 2)
        XCTAssertNil(sim.lifted)
        XCTAssertTrue(sim.canServe)

        // Duplicate angle rejected; 1-tap quickSlice adds another cut cleanly
        XCTAssertFalse(sim.addCut(sim.cuts[0]))
        XCTAssertTrue(sim.quickSlice())
        XCTAssertEqual(sim.cuts.count, 2)
        XCTAssertEqual(sim.slices.count, 4)
    }

    func testServingSlicesAwardsCoinsOnceAndStretchesCheese() {
        Coins.shared.resetForTests(balance: 0)
        defer { Coins.shared.resetForTests() }

        let sim = freshSim()
        sim.demoDisc(216)
        sim.demoSauce(.tomato)
        sim.demoCheese(180)
        sim.bake = 1
        sim.go(.slice)
        sim.addCut(0)
        sim.addCut(.pi / 2)
        for k in 0..<2 {
            sim.place(.pepperoni, at: CGPoint(x: PGeo.center.x + CGFloat(k) * 35, y: PGeo.center.y), from: nil)
            sim.place(.olive, at: CGPoint(x: PGeo.center.x - CGFloat(k + 1) * 35, y: PGeo.center.y), from: nil)
        }

        let allSlices = sim.slices
        let firstMid = (allSlices[0].0 + allSlices[0].1) / 2
        sim.serveSlice(at: CGPoint(x: PGeo.center.x + CGFloat(cos(firstMid)) * 100, y: PGeo.center.y + CGFloat(sin(firstMid)) * 100))
        XCTAssertNotNil(sim.lifted)
        XCTAssertGreaterThanOrEqual(sim.lifted?.strings.count ?? 0, 6, "baked cheesy slice must pull stretchy strings")
        XCTAssertEqual(sim.stars, 3)
        XCTAssertTrue(sim.paidThisPizza)
        let expectedPay = Coins.reward(stars: 3)
        XCTAssertEqual(Coins.shared.balance, expectedPay)

        run(sim, seconds: LiftedSlice.duration + 0.15)
        for s in allSlices.dropFirst() {
            let mid = (s.0 + s.1) / 2
            sim.serveSlice(at: CGPoint(x: PGeo.center.x + CGFloat(cos(mid)) * 100, y: PGeo.center.y + CGFloat(sin(mid)) * 100))
            run(sim, seconds: LiftedSlice.duration + 0.15)
        }
        XCTAssertTrue(sim.allEaten)
        XCTAssertEqual(Coins.shared.balance, expectedPay, "subsequent slices must never double-pay")

        run(sim, seconds: 3.1)
        XCTAssertTrue(sim.ball)
        XCTAssertEqual(sim.stage, .dough)
        XCTAssertNil(sim.stars)
        XCTAssertFalse(sim.paidThisPizza)
    }

    func testOrderStarsAreGentle() {
        let o = PizzaOrder(customer: 0, wants: [.basil])
        XCTAssertEqual(o.stars([]), 1)
        let two = (0..<2).map { PizzaTopping(kind: .basil, x: 0, y: 0, rot: 0, scale: 1, seed: $0, born: 0, from: nil) }
        XCTAssertEqual(o.stars(two), 3)
        for seed in 0..<50 {
            let r = PizzaOrder.random(customer: 1, seed: seed)
            XCTAssertTrue((1...2).contains(r.wants.count))
            XCTAssertEqual(Set(r.wants).count, r.wants.count)
        }
    }

    func testEveryStageCanBeVisitedInAnyOrder() {
        let sim = freshSim()
        for s in PizzaStep.allCases.reversed() {
            sim.go(s)
            run(sim, seconds: 0.2)
        }
        XCTAssertEqual(sim.stage, .dough)
        XCTAssertFalse(sim.inOven)
        XCTAssertFalse(sim.ball)
    }

    func testPizzaFindsDefinesSixUniqueStickersWiredToEntry() {
        let stickers = PizzaFind.stickers
        XCTAssertEqual(PizzaGame.entry.id, "pizza")
        XCTAssertEqual(stickers.count, 6)
        XCTAssertEqual(Set(stickers.map { $0.id }).count, 6)
        XCTAssertEqual(PizzaGame.entry.stickers.map { $0.id }, PizzaFind.allCases.map { $0.rawValue })
    }

    func testSoundsAreBundled() {
        XCTAssertEqual(PizzaSFX.allCases.count, 20)
        for s in PizzaSFX.allCases { XCTAssertNotNil(PizzaSound.url(for: s), s.rawValue) }
    }

    func testKoreanToppingsAllTenPresentAndMatchOrders() {
        XCTAssertEqual(ToppingKind.allCases.count, 10)
        XCTAssertTrue(ToppingKind.allCases.contains(.goguma))
        XCTAssertTrue(ToppingKind.allCases.contains(.cornCheese))

        let sim = freshSim()
        sim.demoDisc(216)
        sim.go(.prep)
        sim.order = PizzaOrder(customer: 0, wants: [.goguma, .cornCheese])
        for k in 0..<2 {
            sim.place(.goguma, at: CGPoint(x: PGeo.center.x + CGFloat(k) * 36, y: PGeo.center.y), from: nil)
            sim.place(.cornCheese, at: CGPoint(x: PGeo.center.x - CGFloat(k + 1) * 36, y: PGeo.center.y), from: nil)
        }
        XCTAssertTrue(sim.ready(.prep))
        XCTAssertEqual(sim.order.stars(sim.toppings), 3)
    }

    func testRawEmptyDoughRefusesServeAndNudgesOven() {
        Coins.shared.resetForTests(balance: 0)
        defer { Coins.shared.resetForTests() }

        let sim = freshSim()
        sim.demoDisc(216)
        sim.go(.slice)
        sim.addCut(0)
        XCTAssertTrue(sim.isUnbakedEmptyDough)

        let s = sim.slices[0]
        let mid = (s.0 + s.1) / 2
        let pt = CGPoint(x: PGeo.center.x + CGFloat(cos(mid)) * 90, y: PGeo.center.y + CGFloat(sin(mid)) * 90)
        sim.serveSlice(at: pt)
        XCTAssertNil(sim.lifted, "bare raw dough must not be served")
        XCTAssertNil(sim.stars)
        XCTAssertEqual(Coins.shared.balance, 0)
        XCTAssertGreaterThanOrEqual(sim.ovenNudgeAt, 0)

        sim.bake = 0.35
        XCTAssertFalse(sim.isUnbakedEmptyDough)
        sim.serveSlice(at: pt)
        XCTAssertNotNil(sim.lifted, "baked sliced pizza serves normally")
    }

    func testPizzaTreasureHooksRespondToOwnership() {
        Coins.shared.resetForTests(balance: 60)
        defer { Coins.shared.resetForTests() }

        XCTAssertEqual(PizzaPainter.goldOvenTreasureID, "pizza/goldOven")
        XCTAssertEqual(PizzaPainter.starCutterTreasureID, "pizza/starCutter")
        XCTAssertFalse(PizzaPainter.hasGoldOven)
        XCTAssertFalse(PizzaPainter.hasStarCutter)

        XCTAssertTrue(Coins.shared.buy("pizza/goldOven", price: 12))
        XCTAssertTrue(PizzaPainter.hasGoldOven)
        XCTAssertFalse(PizzaPainter.hasStarCutter)

        XCTAssertTrue(Coins.shared.buy("pizza/starCutter", price: 10))
        XCTAssertTrue(PizzaPainter.hasStarCutter)
    }
}
