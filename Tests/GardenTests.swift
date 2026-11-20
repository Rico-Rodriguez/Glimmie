import XCTest
@testable import Glimmie

final class GardenTests: XCTestCase {
    private func freshSim() -> GardenSim {
        let sim = GardenSim(save: nil)
        sim.demo = true
        sim.weeds = []
        sim.butterflies = []
        return sim
    }

    private func run(_ sim: GardenSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { sim.step(dt: 1.0 / 60) }
    }

    func testDiggingMakesAHoleAndKeepsTheSoil() {
        let sim = freshSim()
        let before = sim.totalSoil
        let x = GGeo.plotX[3]
        XCTAssertFalse(sim.hasHole(plot: 3))
        sim.pickUp(.shovel, at: CGPoint(x: x, y: GGeo.soilY - 60))
        for k in 0..<40 {
            sim.carry(to: CGPoint(x: x + CGFloat(k % 2) * 4, y: GGeo.soilY + CGFloat(min(k, 30))))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertGreaterThan(sim.load, 100)
        XCTAssertTrue(sim.hasHole(plot: 3))
        sim.release(home: CGPoint(x: 150, y: 776))
        run(sim, seconds: 4)
        XCTAssertEqual(sim.totalSoil, before, accuracy: before * 0.01)
    }

    func testSeedsInAHolePlantIt() {
        let sim = freshSim()
        sim.carveHole(plot: 1)
        XCTAssertTrue(sim.hasHole(plot: 1))
        sim.pickUp(.seeds(.daisy), at: CGPoint(x: GGeo.plotX[1] - 36, y: 400))
        run(sim, seconds: 3)
        XCTAssertEqual(sim.plots[1].plant?.kind, .daisy)
        run(sim, seconds: 1.5)
        XCTAssertLessThan(sim.depth(plot: 1), 8)
    }

    func testPlantsGrowOnlyInDampSoil() {
        let sim = freshSim()
        sim.plots[5].plant = Plant(kind: .tulip, growth: 0.3)
        for i in 0..<GGeo.columns { sim.wet[i] = 0 }
        run(sim, seconds: 5)
        XCTAssertEqual(sim.plots[5].plant?.growth ?? 0, 0.3, accuracy: 0.001)
        XCTAssertGreaterThan(sim.plots[5].dry, 1.5)
        for i in 0..<GGeo.columns { sim.wet[i] = 1 }
        run(sim, seconds: 5)
        XCTAssertGreaterThan(sim.plots[5].plant?.growth ?? 0, 0.4)
    }

    func testWateringSoaksTheSoil() {
        let sim = freshSim()
        for i in 0..<GGeo.columns { sim.wet[i] = 0 }
        sim.pickUp(.can, at: CGPoint(x: 560, y: 380))
        run(sim, seconds: 3)
        XCTAssertGreaterThan(sim.flow, 0.5)
        let wettest = sim.wet.max() ?? 0
        XCTAssertGreaterThan(wettest, 0.3)
    }

    func testPullingAWeed() {
        let sim = freshSim()
        sim.weeds = [GWeed(x: 360, growth: 1, seed: 1)]
        let base = sim.surface(360)
        sim.handBegan(CGPoint(x: 360, y: base - 20))
        for k in 1...20 { sim.handMoved(CGPoint(x: 360, y: base - 20 - CGFloat(k) * 8)) }
        XCTAssertTrue(sim.weeds.isEmpty)
    }

    func testPickingTomatoesFillsTheBasket() {
        let sim = freshSim()
        sim.plots[2].plant = Plant(kind: .tomato, growth: 1, left: 4)
        let x = GGeo.plotX[2]
        let tap = CGPoint(x: x, y: sim.surface(x) - 100)
        sim.handBegan(tap)
        sim.handEnded(tap, tap: true)
        XCTAssertEqual(sim.plots[2].plant?.left, 3)
        run(sim, seconds: 2)
        XCTAssertEqual(sim.basket.last, "tomato:0")
    }

    func testRainWetsTheBed() {
        let sim = freshSim()
        for i in 0..<GGeo.columns { sim.wet[i] = 0 }
        sim.setWeather(.rain)
        run(sim, seconds: 6)
        let avg = sim.wet.reduce(0, +) / CGFloat(GGeo.columns)
        XCTAssertGreaterThan(avg, 0.1)
    }

    func testSaveRoundTrip() throws {
        let sim = freshSim()
        sim.showcase()
        let s = sim.makeSave()
        let back = try JSONDecoder().decode(GardenSave.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
        let again = GardenSim(save: back)
        XCTAssertEqual(again.plots.map { $0.plant }, sim.plots.map { $0.plant })
        XCTAssertEqual(again.decor.count, sim.decor.count)
    }

    func testEverySoundIsBundled() {
        for s in GardenSFX.allCases { XCTAssertNotNil(GameFiles.url(s.rawValue, "wav", game: "Garden"), s.rawValue) }
    }
}
