import XCTest
@testable import Glimmie

final class SpaTests: XCTestCase {
    private func fresh() -> SpaSim {
        let sim = SpaSim(look: .starter)
        sim.quiet = true
        return sim
    }

    private func run(_ sim: SpaSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { sim.step(dt: 1.0 / 60) }
    }

    func testTheTapFillsTheTubAndThePlugDrainsIt() {
        let sim = fresh()
        XCTAssertEqual(sim.vol, 0)
        sim.toggleTap()
        run(sim, seconds: 6)
        XCTAssertGreaterThan(sim.vol, 60)
        run(sim, seconds: 20)
        XCTAssertEqual(sim.vol, SGeo.maxDepth, accuracy: 0.5)
        sim.toggleTap()
        sim.togglePlug()
        run(sim, seconds: 30)
        XCTAssertEqual(sim.vol, 0)
    }

    func testWavesKeepTheWaterLevelAndSettle() {
        let sim = fresh()
        sim.vol = 150
        sim.disturb(400, 3000, width: 20)
        run(sim, seconds: 0.5)
        XCTAssertGreaterThan(sim.h.map(abs).max() ?? 0, 0.5)
        let mean = sim.h.reduce(0, +) / CGFloat(sim.h.count)
        XCTAssertEqual(mean, 0, accuracy: 0.01)
        run(sim, seconds: 20)
        XCTAssertLessThan(sim.h.map(abs).max() ?? 0, 2)
    }

    func testBubbleBathFoamsOnlyWhenChurned() {
        let sim = fresh()
        sim.vol = 160
        sim.soap = 60
        run(sim, seconds: 3)
        XCTAssertLessThan(sim.totalFoam, 0.5)
        sim.tapOn = true
        run(sim, seconds: 4)
        XCTAssertGreaterThan(sim.totalFoam, 3)
    }

    func testADuckFloatsAtTheSurface() {
        let sim = fresh()
        sim.vol = 160
        let id = sim.spawnThing(.toy(.duck), at: CGPoint(x: 600, y: 300), held: false)
        run(sim, seconds: 8)
        guard let i = sim.thingIndex(id) else { return XCTFail("duck gone") }
        let d = sim.things[i]
        let surf = sim.surfaceY(d.p.x)
        XCTAssertLessThan(d.p.y - d.half.height, surf, "the duck's top is above water")
        XCTAssertGreaterThan(d.p.y + d.half.height, surf, "the duck's bottom is in the water")
    }

    func testABathBombFizzesAwayAndColorsTheWater() {
        let sim = fresh()
        sim.vol = 160
        _ = sim.spawnThing(.bomb(.ocean), at: CGPoint(x: 600, y: 400), held: false)
        run(sim, seconds: 16)
        XCTAssertTrue(sim.things.filter { $0.isBomb }.isEmpty)
        XCTAssertGreaterThan(sim.tintA.max() ?? 0, 0.1)
    }

    func testFaceMaskPaintsAndTheSpongeWipesIt() {
        let sim = fresh()
        sim.paintMask(at: CGPoint(x: 300, y: 300), kind: .clay, amount: 1)
        XCTAssertGreaterThan(sim.maskCoverage, 0.01)
        let before = sim.maskCoverage
        sim.wipeMask(at: CGPoint(x: 300, y: 300), radius: 60, amount: 1)
        XCTAssertLessThan(sim.maskCoverage, before * 0.5)
    }

    func testCucumbersCloseHerEyes() {
        let sim = fresh()
        XCTAssertTrue(sim.placeCucumber(at: SGeo.fromDoll(SGeo.eyes[0])))
        XCTAssertTrue(sim.placeCucumber(at: SGeo.fromDoll(SGeo.eyes[1])))
        XCTAssertEqual(sim.expression(), .blink)
        sim.removeCucumber(0)
        XCTAssertFalse(sim.cucumbers[0])
    }

    func testTheTowelDriesHer() {
        let sim = fresh()
        for k in 0..<6 { sim.addBead(CGPoint(x: 260 + CGFloat(k) * 12, y: 330)) }
        XCTAssertFalse(sim.beads.isEmpty)
        let target = SGeo.fromDoll(CGPoint(x: 290, y: 330))
        sim.pickUp(.towel, finger: target, lifted: target)
        for k in 0..<60 {
            sim.carry(finger: target, lifted: CGPoint(x: target.x + (k % 2 == 0 ? 30 : -30), y: target.y))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertTrue(sim.beads.isEmpty)
    }

    func testFingerWipesTheMirror() {
        let sim = fresh()
        for k in sim.fog.indices { sim.fog[k] = 0.9 }
        let c = CGPoint(x: SGeo.mirror.midX, y: SGeo.mirror.midY)
        sim.handBegan(c)
        XCTAssertEqual(sim.hand, .wipe)
        sim.handMoved(CGPoint(x: c.x + 40, y: c.y), dt: 1.0 / 60)
        sim.handEnded(CGPoint(x: c.x + 40, y: c.y), tap: false)
        XCTAssertLessThan(sim.fog.min() ?? 1, 0.1)
    }
}
