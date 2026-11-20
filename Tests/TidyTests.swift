import XCTest
@testable import Glimmie

final class TidyTests: XCTestCase {
    func testLevels() {
        let all = TidyLevels.all
        XCTAssertEqual(all.count, 24)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertEqual(Set(all.map(\.scene)), Set(TidyScene.allCases))
        for l in all {
            XCTAssertGreaterThanOrEqual(l.slots.count, 4, l.id)
            XCTAssertLessThanOrEqual(l.slots.count, 16, l.id)
            for s in l.slots {
                let sz = s.kind.size
                let w = abs(cos(s.rot)) * sz.width + abs(sin(s.rot)) * sz.height
                let h = abs(sin(s.rot)) * sz.width + abs(cos(s.rot)) * sz.height
                XCTAssertGreaterThanOrEqual(s.pos.x - w / 2, 0, "\(l.id) \(s.kind)")
                XCTAssertLessThanOrEqual(s.pos.x + w / 2, TidyScene.size.width, "\(l.id) \(s.kind)")
                XCTAssertGreaterThanOrEqual(s.pos.y - h / 2, -4, "\(l.id) \(s.kind)")
                XCTAssertLessThanOrEqual(s.pos.y + h / 2, TidyScene.size.height + 4, "\(l.id) \(s.kind)")
            }
        }
    }

    func testEveryKindHasASize() {
        for k in TidyKind.allCases {
            XCTAssertGreaterThan(k.size.width, 10, k.rawValue)
            XCTAssertGreaterThan(k.size.height, 10, k.rawValue)
        }
    }

    /// Stacks never lock: filling open slots one at a time always fills every slot.
    func testEveryLevelCanBeFinished() {
        for l in TidyLevels.all {
            let w = TidyWorld(level: l)
            for _ in 0..<l.slots.count { w.placeSome(1) }
            XCTAssertTrue(w.filled.allSatisfy { $0 != nil }, l.id)
        }
    }

    func testStrictSlotsOnlyTakeTheirColor() {
        let w = TidyWorld(level: TidyLevels.bookshelf1)
        let red = w.bodies.first { $0.kind == .book && $0.color == 0 }!
        let slots = TidyLevels.bookshelf1.slots
        for (i, s) in slots.enumerated() where s.kind == .book {
            XCTAssertEqual(w.fits(red, i), s.color == 0)
        }
    }

    func testStacksFillFromTheBottom() {
        let w = TidyWorld(level: TidyLevels.cupboard1)
        let plates = TidyLevels.cupboard1.slots.indices.filter { TidyLevels.cupboard1.slots[$0].kind == .plate }
        let open = plates.filter { w.isOpen($0) }
        XCTAssertEqual(open.count, 1)
        XCTAssertEqual(open.first, plates.max { TidyLevels.cupboard1.slots[$0].pos.y < TidyLevels.cupboard1.slots[$1].pos.y })
    }

    /// The pile lands from the box, settles on the floor and stays on screen.
    func testPileSettles() {
        for l in TidyLevels.all {
            let w = TidyWorld(level: l)
            w.size = CGSize(width: 1194, height: 834)
            w.simulate(seconds: 7)
            var speed: CGFloat = 0
            for b in w.bodies {
                XCTAssertEqual(b.state, .loose, l.id)
                XCTAssertTrue(b.pos.x.isFinite && b.pos.y.isFinite, l.id)
                XCTAssertGreaterThan(b.pos.x, -5, "\(l.id) \(b.kind)")
                XCTAssertLessThan(b.pos.x, w.size.width + 5, "\(l.id) \(b.kind)")
                XCTAssertLessThan(b.pos.y, w.floorY + 2, "\(l.id) \(b.kind)")
                XCTAssertGreaterThan(b.pos.y, 200, "\(l.id) \(b.kind) should be on the floor")
                speed += b.vel.len
            }
            XCTAssertLessThan(speed / CGFloat(w.bodies.count), 60, "\(l.id) pile still moving")
        }
    }

    /// Dragging every item to its spot finishes the level.
    func testDraggingEverythingFinishesTheLevel() {
        for l in [TidyLevels.fridge1, TidyLevels.cupboard2, TidyLevels.socks2, TidyLevels.pantry2] {
            let w = TidyWorld(level: l)
            w.simulate(seconds: 5)
            var tries = 0
            while !w.bodies.allSatisfy({ $0.state == .placed }) && tries < 120 {
                tries += 1
                guard let b = w.bodies.first(where: { $0.state == .loose }) else { w.simulate(seconds: 0.3); continue }
                w.touchDown(b.pos.pt)
                guard let h = w.held else { w.simulate(seconds: 0.2); continue }
                let held = w.bodies[h]
                guard let s = w.eligible(for: held).first else { w.touchUp(held.pos.pt); continue }
                let target = w.slotPos(s).pt
                w.touchMoved(target)
                w.simulate(seconds: 0.4)
                w.touchUp(target)
                w.simulate(seconds: 0.8)
            }
            XCTAssertTrue(w.bodies.allSatisfy { $0.state == .placed }, l.id)
            w.simulate(seconds: 0.6)
            XCTAssertTrue(w.isDone, l.id)
        }
    }

    func testThrownItemsFallBackToTheFloor() {
        let w = TidyWorld(level: TidyLevels.toys1)
        w.simulate(seconds: 5)
        let b = w.bodies[0]
        w.touchDown(b.pos.pt)
        guard let h = w.held else { return XCTFail("nothing picked up") }
        w.touchMoved(CGPoint(x: 500, y: 60))
        w.simulate(seconds: 0.3)
        w.touchMoved(CGPoint(x: 900, y: 40))
        w.simulate(seconds: 0.05)
        w.touchUp(CGPoint(x: 900, y: 40))
        XCTAssertEqual(w.bodies[h].state, .loose)
        w.simulate(seconds: 4)
        XCTAssertGreaterThan(w.bodies[h].pos.y, 600)
    }

    func testProgressRoundTrip() throws {
        let s = TidyStore.Save(done: ["fridge1", "socks2"], music: false)
        let back = try JSONDecoder().decode(TidyStore.Save.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.done, s.done)
        XCTAssertEqual(back.music, false)
    }
}
