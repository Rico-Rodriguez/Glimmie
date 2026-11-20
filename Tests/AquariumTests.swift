import XCTest
@testable import Glimmie

final class AquariumTests: XCTestCase {
    private func freshSim() -> AquariumSim {
        let sim = AquariumSim(save: nil)
        sim.demo = true
        sim.fish = []
        sim.food = []
        sim.bubbles = []
        sim.decor = []
        sim.pump = false
        return sim
    }

    private func run(_ sim: AquariumSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { sim.step(dt: 1.0 / 60) }
    }

    func testFoodFloatsThenSinksAndFishEatIt() {
        let sim = freshSim()
        sim.addFlake(at: CGPoint(x: 300, y: 60), v: .zero)
        run(sim, seconds: 0.5)
        XCTAssertEqual(sim.food.first?.state, .floating, "a flake lands on the water and floats a moment")
        run(sim, seconds: 3)
        XCTAssertEqual(sim.food.first?.state, .sinking)
        run(sim, seconds: 20)
        XCTAssertEqual(sim.food.first?.state, .settled, "uneaten food ends up on the sand")

        let hungry = freshSim()
        hungry.spawn(.goldfish, variant: 0, at: CGPoint(x: 500, y: 400))
        for k in 0..<4 { hungry.addFlake(at: CGPoint(x: 420 + CGFloat(k) * 40, y: 80), v: .zero) }
        // appetite comes back (1 per 9 s), so look at its lowest point, not the end
        var lowest = hungry.fish[0].appetite
        for _ in 0..<(20 * 60) {
            hungry.step(dt: 1.0 / 60)
            lowest = min(lowest, hungry.fish[0].appetite)
        }
        XCTAssertLessThan(hungry.food.count, 4, "the fish swims up and eats")
        XCTAssertLessThan(lowest, 5)
    }

    func testDecorationsSinkThroughWaterAndRestOnTheSand() {
        let sim = freshSim()
        let weedY = 220 + AquaDecorKind.seaweed.size.height * 0.5
        let rock = sim.addDecor(.rock, x: 400, falling: true, y: 220)
        let weed = sim.addDecor(.seaweed, x: 700, falling: true, y: weedY)
        run(sim, seconds: 0.6)
        XCTAssertGreaterThan(sim.decor[rock].y - 220, (sim.decor[weed].y - weedY) * 1.5, "heavy things sink faster than plants")
        run(sim, seconds: 8)
        for d in sim.decor {
            XCTAssertFalse(d.falling)
            XCTAssertEqual(d.y, AGeo.sand(d.x), accuracy: 0.5)
        }
    }

    func testTheSpongeCleansTheGlass() {
        let sim = freshSim()
        for i in sim.algae.indices { sim.algae[i] = 1 }
        let before = sim.dirtiness
        sim.pickUp(.sponge, at: CGPoint(x: 300, y: 400))
        for k in 0..<240 {
            let x = 200 + CGFloat(k % 40) * 10
            sim.carry(to: CGPoint(x: x, y: 380 + CGFloat(k / 40) * 12))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertLessThan(sim.dirtiness, before - 0.05)
        XCTAssertLessThan(sim.algae[10 * AGeo.algaeCols + 10], 0.3, "the rubbed patch is clean")
        XCTAssertGreaterThan(sim.algae[2 * AGeo.algaeCols + 38], 0.9, "glass she didn't rub is still green")
    }

    func testAlgaeGrowsBackSlowly() {
        let sim = freshSim()
        for i in sim.algae.indices { sim.algae[i] = 0 }
        sim.snail.p = CGPoint(x: -500, y: -500)
        run(sim, seconds: 10)
        XCTAssertGreaterThan(sim.dirtiness, 0)
        XCTAssertLessThan(sim.dirtiness, 0.1)
    }

    func testBubblesRiseAndPopAtTheSurface() {
        let sim = freshSim()
        sim.addBubble(CGPoint(x: 500, y: 600), r: 5)
        sim.addBubble(CGPoint(x: 300, y: 600), r: 2)
        run(sim, seconds: 1)
        XCTAssertEqual(sim.bubbles.count, 2)
        let big = sim.bubbles.first { abs($0.p.x - 500) < 40 }!
        let small = sim.bubbles.first { abs($0.p.x - 300) < 40 }!
        XCTAssertLessThan(big.p.y, small.p.y, "bigger bubbles rise faster")
        run(sim, seconds: 10)
        XCTAssertTrue(sim.bubbles.isEmpty)
    }

    func testFishStayInTheWater() {
        let sim = freshSim()
        for k in FishKind.allCases { sim.addFish(k, x: 500, y: 60) }
        for s in 0..<30 {
            if s % 5 == 0 { sim.handBegan(CGPoint(x: 200 + CGFloat(s) * 20, y: 400)); sim.handEnded(CGPoint(x: 200 + CGFloat(s) * 20, y: 400), tap: true) }
            run(sim, seconds: 1)
            for f in sim.fish {
                XCTAssertGreaterThan(f.p.x, AGeo.left)
                XCTAssertLessThan(f.p.x, AGeo.right)
                XCTAssertGreaterThan(f.p.y, AGeo.waterY)
                XCTAssertLessThan(f.p.y, AGeo.sand(f.p.x))
            }
        }
    }

    func testTheNetCatchesAFishAndLiftingItOutSendsItHome() {
        let sim = freshSim()
        sim.spawn(.goldfish, variant: 0, at: CGPoint(x: 500, y: 400))
        sim.fish[0].restUntil = 100
        sim.pickUp(.net, at: CGPoint(x: 380, y: 400))
        for k in 0..<30 {
            sim.carry(to: CGPoint(x: 380 + CGFloat(k) * 6, y: 400))
            sim.step(dt: 1.0 / 60)
            if sim.caught != nil { break }
        }
        XCTAssertNotNil(sim.caught)
        sim.carry(to: CGPoint(x: 500, y: 760))
        run(sim, seconds: 0.5)
        sim.release(home: CGPoint(x: 512, y: 772))
        XCTAssertTrue(sim.fish.isEmpty)
    }

    func testABagOfTetrasIsASchool() {
        let sim = freshSim()
        sim.addFish(.tetra, x: 400, y: 60)
        XCTAssertEqual(sim.fish.count, FishKind.tetra.group)
        XCTAssertEqual(sim.fish.filter { $0.kind == .tetra }.count, 5)
    }

    func testSaveRoundTrip() {
        let sim = freshSim()
        sim.addFish(.betta, x: 300, y: 300)
        sim.addDecor(.castle, x: 300)
        sim.addDecor(.ship, x: 700)
        sim.lightsOn = false
        let data = try! JSONEncoder().encode(sim.makeSave())
        let back = AquariumSim(save: try! JSONDecoder().decode(AquaSave.self, from: data))
        XCTAssertEqual(back.fish.map(\.kind), [.betta])
        XCTAssertEqual(back.decor.map(\.kind), [.castle, .ship])
        XCTAssertFalse(back.lightsOn)
        XCTAssertEqual(back.algae.count, AGeo.algaeCols * AGeo.algaeRows)
    }
}
