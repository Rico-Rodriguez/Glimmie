import XCTest
@testable import Glimmie

final class BakeryTests: XCTestCase {
    let art = BakeryArt.shared

    func testArtLoads() {
        XCTAssertGreaterThan(art.sprites.count, 100)
        XCTAssertEqual(art.tiers.count, 3)
        for name in ["plate", "liner", "cupcake_top", "scoop", "sauce", "bowl_back", "bowl_front", "batter", "oven", "pan", "counter"] {
            XCTAssertNotNil(art.sprites[name], name)
        }
        for c in BakeryPalette.customers { XCTAssertNotNil(art.sprites["cust_\(c)"], c) }
        for c in BakeryPalette.cones { XCTAssertNotNil(art.sprites["cone_\(c)"], c) }
        for s in BakeryPalette.frostStyles { for k in 1...3 { XCTAssertNotNil(art.sprites["frost_\(s)\(k)"], s) } }
        for i in 0..<3 { XCTAssertNotNil(art.sprites["cake_body\(i)"]); XCTAssertNotNil(art.sprites["cake_frost\(i)"]) }
        for f in BakeryPalette.flavors { XCTAssertNotNil(art.sprites[f.icon], f.icon) }
        for e in ["eyes_open", "eyes_blink", "eyes_happy", "eyes_star", "mouth_smile", "mouth_open", "mouth_chew"] {
            XCTAssertNotNil(art.sprites[e], e)
        }
    }

    func testEveryTrayToppingHasArt() {
        var count = 0
        for tray in BakeryPalette.trays {
            XCTAssertNotNil(art.sprites[tray.icon], tray.icon)
            for item in tray.items {
                let name = item.hasPrefix("*") ? "bit_" + item.dropFirst() : "top_" + item
                XCTAssertNotNil(art.sprites[name], name)
                count += 1
            }
        }
        XCTAssertGreaterThanOrEqual(count, 40)
    }

    func testEveryPathParses() {
        for (name, shapes) in art.sprites {
            for s in shapes { XCTAssertFalse(s.path.isEmpty, name) }
        }
    }

    func testFrostSamplesCoverEveryTier() {
        for n in 1...3 { XCTAssertGreaterThan(FrostStepView.makeSamples(tiers: n).count, 40 * n) }
    }

    func testTreatRoundTrip() throws {
        for k in TreatKind.allCases {
            let t = Treat.sample(k, seed: 3)
            let back = try JSONDecoder().decode(Treat.self, from: JSONEncoder().encode(t))
            XCTAssertEqual(back, t)
        }
    }

    func testRandomSpotsLandOnTheTreat() {
        for k in TreatKind.allCases {
            var t = Treat.sample(k, seed: 1)
            for tiers in 1...3 {
                t.tiers = tiers
                for _ in 0..<50 {
                    let p = TreatPainter.randomSpot(on: t)
                    XCTAssert(p.x > 80 && p.x < 520 && p.y > 40 && p.y < 560, "\(k) \(p)")
                }
            }
        }
    }

    func testSoundsAreBundled() {
        for s in BakeSFX.allCases { XCTAssertNotNil(GameFiles.url(s.rawValue, "wav", game: "Bakery"), s.rawValue) }
    }
    // MARK: Realistic kitchen

    func testStirringMixesTheBowl() {
        let sim = BowlSim()
        sim.prefill([.milk, .eggs, .flour, .sugar, .butter, .flavor], flavor: 2)
        sim.setTarget(BakeryPalette.flavors[2].color)
        XCTAssertLessThan(sim.progress, 0.1)
        XCTAssertEqual(sim.poolRadius(Date()), 1, accuracy: 0.001)
        var t = Date()
        var steps = 0
        var moved: CGFloat = 0
        while sim.progress < 0.96 && steps < 3000 {
            let a = Double(steps) * 0.12
            moved += sim.stir(to: CGPoint(x: cos(a) * 0.5, y: sin(a) * 0.5), at: t)
            t = t.addingTimeInterval(1.0 / 60)
            steps += 1
        }
        XCTAssertGreaterThanOrEqual(sim.progress, 0.96)
        // about as much stirring as a few big circles: never more than the safety stop in the view
        XCTAssertLessThan(moved, 16)
    }

    func testPouringQueuesOneAfterAnother() {
        let sim = BowlSim()
        let a = sim.pour(.flour, from: CGPoint(x: 600, y: 0))
        let b = sim.pour(.milk, from: CGPoint(x: 600, y: 0))
        XCTAssertGreaterThanOrEqual(b.start.timeIntervalSince(a.start), a.pourEnd - 0.01)
        XCTAssertGreaterThan(sim.blobs.count, 4)
    }

    func testLiquidStreamFallsAndBreaks() throws {
        let m = CGPoint(x: 100, y: 0)
        XCTAssertNil(LiquidStream(mouth: m, floorY: 200, vx: 0, width: 10, v0: 0, age: 0, stopped: nil, phase: 0))
        let s = try XCTUnwrap(LiquidStream(mouth: m, floorY: 200, vx: 0, width: 10, v0: 0, age: 2, stopped: nil, phase: 0))
        XCTAssertTrue(s.reachesFloor)
        XCTAssertLessThan(s.widths.last ?? 99, s.widths.first ?? 0)
        // long after the pour stopped, the stream has fallen away
        XCTAssertNil(LiquidStream(mouth: m, floorY: 200, vx: 0, width: 10, v0: 0, age: 5, stopped: 3, phase: 0))
    }

    func testPourFlowFillsWhileHeld() {
        let f = PourFlow()
        let t0 = Date()
        f.press(t0)
        XCTAssertEqual(f.level(t0.addingTimeInterval(PourFlow.delay)), 0, accuracy: 0.001)
        f.release(t0.addingTimeInterval(PourFlow.delay + 1.2))
        let mid = f.level(t0.addingTimeInterval(10))
        XCTAssertEqual(Double(mid), 1.2 / PourFlow.fullTime, accuracy: 0.01)
        f.press(t0.addingTimeInterval(11))
        XCTAssertEqual(f.level(t0.addingTimeInterval(11 + PourFlow.delay + PourFlow.fullTime)), 1, accuracy: 0.001)
        XCTAssertTrue(f.flowing(at: t0.addingTimeInterval(0.5)))
        XCTAssertFalse(f.flowing(at: t0.addingTimeInterval(5)))
    }

    func testOldSavesWithoutSpatulaMarksStillLoad() throws {
        var t = Treat.sample(.cake, seed: 4)
        t.swoosh = [[100, 200, 120, 210, 140, 205]]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(t)) as! [String: Any]
        XCTAssertNotNil(json["swoosh"])
        json.removeValue(forKey: "swoosh")
        let old = try JSONDecoder().decode(Treat.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.swoosh)
        XCTAssertEqual(t.swooshPoints.first?.count, 3)
        XCTAssertEqual(t.swooshPoints.first?.last, CGPoint(x: 140, y: 205))
    }

    func testPipingGoesAllTheWayAround() {
        for style in BakeryPalette.frostStyles {
            for stage in 1...3 {
                let start = Piping.nozzle(style: style, stage: stage, f: 0)
                let half = Piping.nozzle(style: style, stage: stage, f: 0.5)
                XCTAssertLessThan(start.x, 300, style)
                XCTAssertGreaterThan(half.x, 300, style)
                XCTAssertFalse(Piping.wedge(style: style, stage: stage, f: 0.3).isEmpty)
                let r = Piping.ring(style: style, stage: stage)
                XCTAssertTrue(Piping.wedge(style: style, stage: stage, f: 1).contains(CGPoint(x: 300, y: r.cy - 20)), style)
            }
        }
    }

    // MARK: Orders

    func testTheOrderedTreatGetsThreeStars() {
        for seed in 0..<40 {
            let o = BakeryOrder.random(customer: seed % BakeryPalette.customers.count, seed: seed)
            XCTAssertEqual(o.matchCount(o.picture), 4, "\(o)")
            XCTAssertEqual(o.stars(for: o.picture), 3)
            XCTAssertNotNil(BakeryArt.shared.sprites[o.topping], o.topping)
            XCTAssertGreaterThanOrEqual(o.frosting, 2)
        }
    }

    func testStarsAreGentle() {
        var o = BakeryOrder.random(customer: 0, seed: 3)
        o.kind = .cake
        o.flavor = 1
        o.frosting = 4
        o.topping = "top_star"
        var t = Treat(kind: .iceCream)
        XCTAssertEqual(o.stars(for: t), 1, "a different treat still gets a star")
        t = Treat(kind: .cake)
        t.flavor = 1
        XCTAssertEqual(o.stars(for: t), 2)
        t.frosting = 4
        XCTAssertEqual(o.stars(for: t), 2)
        t.toppings = [PlacedTopping(sprite: "top_star", x: 300, y: 380)]
        XCTAssertEqual(o.stars(for: t), 3)
        // ice cream: the cone and any scoop of the flavor count
        o.kind = .iceCream
        o.cone = "sugar"
        var ic = Treat(kind: .iceCream)
        ic.cone = "sugar"
        ic.scoops = [3, 1]
        ic.toppings = t.toppings
        XCTAssertEqual(o.matchCount(ic), 4)
    }

    // MARK: Hands-on ingredients

    func testHoldingMilkOverTheBowlPoursUntilFull() {
        let sim = BowlSim()
        let hands = HandsOnBowl()
        hands.sim = sim
        var t = Date()
        hands.grab(.milk, at: CGPoint(x: 300, y: 0), now: t)
        XCTAssertTrue(hands.overBowl())
        var full: [Ingredient] = []
        var n = 0
        while full.isEmpty && n < 600 {
            t = t.addingTimeInterval(1.0 / 60)
            full = hands.step(t)
            n += 1
        }
        XCTAssertEqual(full, [.milk])
        XCTAssertLessThan(Double(n) / 60, 3, "a couple of seconds of pouring fills it")
        XCTAssertNil(hands.holding)
        XCTAssertGreaterThan(sim.poolRadius(t.addingTimeInterval(2)), 0.8)
    }

    func testNothingPoursAwayFromTheBowl() {
        let hands = HandsOnBowl()
        var t = Date()
        hands.grab(.flour, at: CGPoint(x: 560, y: 0), now: t)
        XCTAssertFalse(hands.overBowl())
        for _ in 0..<120 { t = t.addingTimeInterval(1.0 / 60); _ = hands.step(t) }
        XCTAssertEqual(hands.progress(.flour), 0)
        XCTAssertTrue(hands.grains.isEmpty)
    }

    func testShakingTheFlourPoursFaster() {
        func seconds(shake: Bool) -> Double {
            let hands = HandsOnBowl()
            hands.sim = BowlSim()
            var t = Date()
            hands.grab(.flour, at: CGPoint(x: 300, y: 0), now: t)
            var n = 0
            while hands.holding != nil && n < 900 {
                t = t.addingTimeInterval(1.0 / 60)
                if shake { hands.move(to: CGPoint(x: 300 + CGFloat(sin(Double(n) * 0.8)) * 30, y: 0), now: t) }
                _ = hands.step(t)
                n += 1
            }
            return Double(n) / 60
        }
        XCTAssertLessThan(seconds(shake: true), seconds(shake: false))
    }

    func testEggsCrackOnTheRim() {
        let sim = BowlSim()
        let hands = HandsOnBowl()
        hands.sim = sim
        let t = Date()
        let x: CGFloat = 200
        let rest = HandsOnBowl.rimY(x) - 26
        // her finger is below the egg: `lift` under where the egg goes
        let up = HandsOnBowl.lift
        for egg in 0..<HandsOnBowl.eggs {
            hands.grab(.eggs, at: CGPoint(x: x, y: rest - 50 + up), now: t)
            // the egg can't go through the rim: pushing down knocks it, lifting and pushing again breaks it
            XCTAssertEqual(hands.move(to: CGPoint(x: x, y: rest + 30 + up), now: t), .knock)
            XCTAssertEqual(hands.hand.y, rest, accuracy: 0.01)
            XCTAssertEqual(hands.move(to: CGPoint(x: x, y: rest + 40 + up), now: t), .none, "one knock per push")
            hands.move(to: CGPoint(x: x, y: rest - 40 + up), now: t)
            XCTAssertEqual(hands.move(to: CGPoint(x: x, y: rest + 30 + up), now: t), .crack)
            XCTAssertEqual(hands.eggsCracked, egg + 1)
            XCTAssertNil(hands.holding)
        }
        XCTAssertTrue(hands.finished.contains(.eggs))
        XCTAssertEqual(sim.blobs.filter { $0.yolk }.count, 2)
    }

    func testAnEggLetGoOnTheRimWaitsForTaps() {
        let hands = HandsOnBowl()
        hands.sim = BowlSim()
        let t = Date()
        hands.grab(.eggs, at: CGPoint(x: 230, y: HandsOnBowl.rimY(230) - 30 + HandsOnBowl.lift), now: t)
        XCTAssertTrue(hands.release(now: t))
        XCTAssertTrue(hands.parked)
        XCTAssertTrue(hands.touchesParkedEgg(hands.hand))
        XCTAssertEqual(hands.knock(t), .knock)
        XCTAssertEqual(hands.knock(t), .crack)
        XCTAssertEqual(hands.eggsCracked, 1)
    }

    func testButterDropsInWhenLetGoOverTheBowl() {
        let sim = BowlSim()
        let hands = HandsOnBowl()
        hands.sim = sim
        let t = Date()
        hands.grab(.butter, at: CGPoint(x: 520, y: 100), now: t)
        XCTAssertFalse(hands.release(now: t), "let go beside the bowl: it goes back")
        hands.grab(.butter, at: CGPoint(x: 210, y: 20), now: t)
        XCTAssertTrue(hands.release(now: t))
        XCTAssertTrue(hands.finished.contains(.butter))
        XCTAssertEqual(sim.blobs.filter { $0.cube }.count, 1)
    }
}
