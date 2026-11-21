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

    // MARK: Surprises for the sticker book

    func testABunnyVisitsRipeCarrotsAndLeavesWhenTheyArePulled() {
        let sim = freshSim()
        sim.decor = []
        sim.plots[1].plant = Plant(kind: .carrot, growth: 1, left: 1, variant: 0)
        sim.nextVisit = 0
        run(sim, seconds: 12)
        guard let bunny = sim.visitors.first(where: { $0.kind == .bunny }) else { return XCTFail("no bunny came") }
        XCTAssertEqual(bunny.state, .staying)
        XCTAssertTrue((160...864).contains(bunny.p.x), "the bunny sits where she can see it")
        sim.plots[1].plant = nil
        run(sim, seconds: 12)
        XCTAssertFalse(sim.visitors.contains { $0.kind == .bunny })
    }

    func testNobodyVisitsWhenThereIsNothingForThem() {
        let sim = freshSim()
        sim.decor = []
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.nextVisit = 0
        run(sim, seconds: 10)
        XCTAssertTrue(sim.visitors.isEmpty)
    }

    func testAnOwlSitsOnTheFenceAtNight() {
        let sim = freshSim()
        sim.decor = []
        for i in sim.plots.indices { sim.plots[i].plant = nil }
        sim.setWeather(.night)
        sim.settleWeather()
        sim.nextVisit = 0
        run(sim, seconds: 1)
        sim.nextVisit = 0
        run(sim, seconds: 12)
        let owl = sim.visitors.first { $0.kind == .owl }
        XCTAssertNotNil(owl)
        XCTAssertEqual(owl?.p.y ?? 0, 428, accuracy: 1)
    }

    func testSpecialPlantsLookDifferent() {
        let plain = Plant(kind: .tomato, growth: 1, left: 1, variant: 2)
        let gold = Plant(kind: .tomato, growth: 1, left: 1, variant: Plant.specialVariant + 2)
        XCTAssertFalse(plain.isSpecial)
        XCTAssertTrue(gold.isSpecial)
        XCTAssertNil(plain.specialTint)
        XCTAssertEqual(gold.kind.bloom(gold.variant), PlantKind.tomato.specialColor)
        for k in PlantKind.allCases where k != .pumpkin {
            XCTAssertNotEqual(k.specialColor, k.bloom(0), k.rawValue)
        }
        for _ in 0..<200 {
            let v = GardenSim.rollVariant()
            XCTAssertTrue((0..<6).contains(v % Plant.specialVariant))
        }
    }

    func testEverySurpriseHasASticker() {
        let entry = GameRegistry.all.first { $0.id == GardenSim.gameID }
        XCTAssertEqual(entry?.stickers.map(\.id), GardenFind.allCases.map(\.rawValue))
        for k in PlantKind.allCases { XCTAssertEqual(GardenFind.special(k).plant, k) }
        for v in GVisitorKind.allCases { XCTAssertEqual(GardenFind(rawValue: v.rawValue)?.visitor, v) }
    }

    func testTheStickerBookCountsAFindOnce() {
        let book = StickerBook.shared
        book.demo = true
        let id = "test-\(UUID().uuidString)"
        XCTAssertTrue(book.find(game: "testgame", id: id))
        XCTAssertFalse(book.find(game: "testgame", id: id))
        XCTAssertTrue(book.has(game: "testgame", id: id))
        XCTAssertTrue(book.hasUnseen(game: "testgame"))
        book.markSeen(game: "testgame")
        XCTAssertFalse(book.hasUnseen(game: "testgame"))
    }
}
