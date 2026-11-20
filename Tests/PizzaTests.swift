import XCTest
@testable import Glimmie

final class PizzaTests: XCTestCase {
    private func freshSim() -> PizzaSim {
        let sim = PizzaSim(load: false)
        sim.demo = true
        sim.order = PizzaOrder(customer: 0, wants: [.pepperoni, .olive])
        return sim
    }

    private func run(_ sim: PizzaSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { sim.step(dt: 1.0 / 60) }
    }

    func testKneadingSmoothsTheBallThenItFlattens() {
        let sim = freshSim()
        let c = PGeo.center
        let rough = sim.lumps.map { abs($0) }.max() ?? 0
        for _ in 0..<PGeo.knead {
            sim.handBegan(c)
            run(sim, seconds: 0.1)
            sim.handEnded(c, tap: true)
            run(sim, seconds: 0.1)
        }
        XCTAssertEqual(sim.kneads, PGeo.knead)
        XCTAssertLessThan(sim.lumps.map { abs($0) }.max() ?? 1, rough * 0.4)
        XCTAssertTrue(sim.ball)
        sim.handBegan(c)
        XCTAssertFalse(sim.ball)
        run(sim, seconds: 1)
        XCTAssertGreaterThan(sim.meanR, 115)
    }

    func testStretchingGrowsTheDoughAndItSpringsBackALittle() {
        let sim = freshSim()
        sim.flatten()
        run(sim, seconds: 1.5)
        let before = sim.meanR
        // push outward in eight directions, from the middle to past the edge
        for k in 0..<8 {
            let a = Double(k) / 8 * 2 * .pi
            let u = CGPoint(x: CGFloat(cos(a)), y: CGFloat(sin(a)))
            var p = CGPoint(x: PGeo.center.x + u.x * 60, y: PGeo.center.y + u.y * 60)
            sim.handBegan(p)
            for _ in 0..<20 {
                p = CGPoint(x: p.x + u.x * 6, y: p.y + u.y * 6)
                sim.handMoved(p, dt: 1.0 / 60)
                sim.step(dt: 1.0 / 60)
            }
            sim.handEnded(p, tap: false)
        }
        let stretched = sim.meanR
        run(sim, seconds: 2)
        let settled = sim.meanR
        XCTAssertGreaterThan(settled, before + 15)
        XCTAssertLessThan(settled, stretched + 3)
        XCTAssertLessThanOrEqual(sim.r.max() ?? 0, PGeo.maxR + 6)
    }

    func testATossLandsBiggerAndRounder() {
        let sim = freshSim()
        sim.flatten()
        run(sim, seconds: 1.5)
        let before = sim.meanR
        sim.tossStart = sim.time
        run(sim, seconds: 2)
        XCTAssertNil(sim.tossStart)
        XCTAssertGreaterThan(sim.meanR, before + 8)
    }

    func testSpreadingSauceKeepsItAndCoversThePizza() {
        let sim = freshSim()
        sim.demoDisc(220)
        let c = PGeo.center
        sim.pour(at: c, amount: 30)
        let total = sim.totalSauce
        XCTAssertGreaterThan(total, 0)
        var p = c
        for k in 0..<600 {
            let a = Double(k) * 0.09
            let rr = 20 + CGFloat(k) / 600 * 170
            let q = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            sim.spread(at: q, by: CGPoint(x: q.x - p.x, y: q.y - p.y))
            p = q
        }
        XCTAssertEqual(sim.totalSauce, total, accuracy: total * 0.01)
        XCTAssertGreaterThan(sim.coverage(sim.sauce, above: 0.05), 0.25)
    }

    func testCheeseLandsOnTheDoughAndMeltsInTheOven() {
        let sim = freshSim()
        sim.demoDisc(220)
        sim.holdTool(.cheese, at: PGeo.center)
        run(sim, seconds: 3)
        sim.release()
        run(sim, seconds: 1)
        XCTAssertGreaterThan(sim.landed, 40)
        XCTAssertGreaterThan(sim.cheese.reduce(0, +), 1)
        sim.go(.bake)
        XCTAssertTrue(sim.inOven)
        run(sim, seconds: PGeo.bakeTime + 2)
        XCTAssertEqual(sim.bake, 1, accuracy: 0.0001)
        XCTAssertEqual(sim.melt, 1, accuracy: 0.0001)
        XCTAssertTrue(sim.ready(.bake))
    }

    func testCutsAcrossTheMiddleMakeSlices() {
        let sim = freshSim()
        sim.demoDisc(220)
        XCTAssertEqual(sim.slices.count, 1)
        // a cut that misses the middle doesn't count
        sim.stroke = [CGPoint(x: PGeo.center.x - 200, y: PGeo.center.y + 170), CGPoint(x: PGeo.center.x + 200, y: PGeo.center.y + 170)]
        sim.finishCut()
        XCTAssertTrue(sim.cuts.isEmpty)
        sim.stroke = [CGPoint(x: PGeo.center.x - 200, y: PGeo.center.y + 10), CGPoint(x: PGeo.center.x + 200, y: PGeo.center.y - 6)]
        sim.finishCut()
        XCTAssertEqual(sim.cuts.count, 1)
        // the same cut again isn't a new one
        XCTAssertFalse(sim.addCut(.pi))
        XCTAssertTrue(sim.addCut(.pi / 2))
        XCTAssertEqual(sim.slices.count, 4)
    }

    func testServingASliceGivesStarsAndAllSlicesFinishThePizza() {
        let sim = freshSim()
        sim.demoDisc(220)
        sim.go(.slice)
        sim.addCut(0)
        sim.addCut(.pi / 2)
        for k in 0..<2 { sim.place(.pepperoni, at: CGPoint(x: PGeo.center.x + CGFloat(k) * 40, y: PGeo.center.y), from: nil) }
        for s in sim.slices {
            let mid = (s.0 + s.1) / 2
            sim.serveSlice(at: CGPoint(x: PGeo.center.x + CGFloat(cos(mid)) * 100, y: PGeo.center.y + CGFloat(sin(mid)) * 100))
            run(sim, seconds: LiftedSlice.duration + 0.2)
        }
        XCTAssertEqual(sim.stars, 2) // pepperoni yes, olives no
        XCTAssertTrue(sim.allEaten)
        run(sim, seconds: 3)
        XCTAssertTrue(sim.ball) // a fresh pizza
        XCTAssertNil(sim.stars)
    }

    func testOrderStarsAreGentle() {
        let o = PizzaOrder(customer: 0, wants: [.basil])
        XCTAssertEqual(o.stars([]), 1)
        let two = (0..<2).map { PlacedTopping(kind: .basil, x: 0, y: 0, rot: 0, scale: 1, seed: $0, born: 0, from: nil) }
        XCTAssertEqual(o.stars(two), 3)
        for seed in 0..<50 {
            let r = PizzaOrder.random(customer: 1, seed: seed)
            XCTAssertTrue((1...2).contains(r.wants.count))
            XCTAssertEqual(Set(r.wants).count, r.wants.count)
        }
    }

    func testEveryStepCanBeVisitedInAnyOrder() {
        let sim = freshSim()
        for s in PizzaStep.allCases.reversed() { sim.go(s); run(sim, seconds: 0.2) }
        XCTAssertEqual(sim.stage, .dough)
        XCTAssertFalse(sim.inOven)
        XCTAssertFalse(sim.ball)
    }
}
