import XCTest
@testable import Glimmie

final class TactileGamesTests: XCTestCase {
    func testWaterNeedsAConnectedChannelAndAPlugStopsTheSupply() {
        let spring = GardenSpring()
        spring.prepare(nil)
        let root = CGPoint(x:288,y:617)
        for _ in 0..<90 { spring.advance(1/45) }
        XCTAssertFalse(spring.irrigates(x:root.x,y:root.y))
        _ = spring.stroke(spring.center(GardenSpring.inlet))
        _ = spring.stroke(root)
        for _ in 0..<360 { spring.advance(1/45) }
        XCTAssertTrue(spring.irrigates(x:root.x,y:root.y))
        spring.previous = nil
        spring.filling = true
        _ = spring.stroke(root)
        XCTAssertFalse(spring.dug.contains(Int((root.y-550)/8)*112+Int((root.x-64)/8)))
    }

    func testSculptedTuftKeepsItsRootAndRinsesAway() throws {
        let foam = FoamSculpture()
        let root = CGPoint(x:218,y:215)
        foam.begin(root)
        foam.move(CGPoint(x:168,y:84))
        for _ in 0..<120 { foam.advance(1/60) }
        foam.held=nil
        XCTAssertEqual(foam.tufts.first?.root,root)
        let before = try XCTUnwrap(foam.tufts.first?.tip)
        foam.shake()
        for _ in 0..<120 { foam.advance(1/60) }
        XCTAssertGreaterThan(try XCTUnwrap(foam.tufts.first?.tip.y),before.y+25)
        foam.moveRinse(at:root)
        XCTAssertTrue(foam.tufts.isEmpty)
    }

    func testCaveRoofFallsWhenASupportMovesAndSurvivesReload() throws {
        let tank=AquariumSim(save:nil)
        tank.demo=true
        let left=tank.addDecor(.pillar,x:380)
        _=tank.addDecor(.pillar,x:488)
        let roof=tank.addDecor(.slate,x:434,falling:true,y:430)
        for _ in 0..<420 { tank.step(dt:1/60) }
        XCTAssertLessThan(tank.decor[roof].y,AGeo.sand(434)-40)
        XCTAssertFalse(tank.eelSpine.isEmpty)
        let restored=AquariumSim(save:tank.makeSave())
        let piece=try XCTUnwrap(restored.decor.first(where: { $0.kind == .slate }))
        XCTAssertEqual(piece.y,tank.decor[roof].y,accuracy:2)
        tank.decor[left].x=190
        for _ in 0..<300 { tank.step(dt:1/60) }
        XCTAssertEqual(tank.decor[roof].y,AGeo.sand(434),accuracy:2)
        XCTAssertTrue(tank.eelSpine.isEmpty)
    }

    func testBerryBeanLaunchRingsBellAndStoneCancelsLift() {
        let bench=SpellBench(saved:[])
        bench.brewed=[.berry,.bean]
        bench.coat(0)
        bench.grab = .toy(0)
        bench.end(bench.toys[0].p,fling:.zero)
        for _ in 0..<100 { bench.advance(1/60) }
        XCTAssertGreaterThan(bench.bellAt,-1)
        bench.brewed=[.berry,.stone]
        bench.coat(0)
        XCTAssertFalse(bench.toys[0].floating)
        XCTAssertFalse(bench.toys[0].heavy)
        for _ in 0..<240 { bench.advance(1/60) }
        XCTAssertEqual(bench.toys[0].p.y,SpellBench.floor-bench.toys[0].radius,accuracy:1)
    }
}
