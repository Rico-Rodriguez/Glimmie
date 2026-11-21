import XCTest
@testable import Glimmie

final class FingerLiftTests: XCTestCase {
    func testAToolWorksAheadOfHerFingerUpAndToTheLeft() {
        XCTAssertGreaterThan(FingerLift.tool, 60, "the working end is a handle's length from her finger")
        let p = FingerLift.point(CGPoint(x: 400, y: 600), lift: FingerLift.tool, bottom: 834, width: 1024)
        XCTAssertEqual(p.y, 600 - FingerLift.tool, accuracy: 0.001)
        XCTAssertEqual(p.x, 400 - FingerLift.leanSide * FingerLift.tool, accuracy: 0.001, "away from her hand")
        // near the left edge it leans to the right instead
        XCTAssertGreaterThan(FingerLift.point(CGPoint(x: 10, y: 600), lift: FingerLift.tool, bottom: 834, width: 1024).x, 10)
        // a tool that works right at her finger (lift 0) stays there
        XCTAssertEqual(FingerLift.point(CGPoint(x: 400, y: 600), lift: 0), CGPoint(x: 400, y: 600))
        XCTAssertGreaterThan(FingerLift.spread, 1.2, "what a tool does reaches past her fingertip")
    }

    func testAHeldToolTurnsSoItsHandleRunsBackToHerFinger() {
        // a net drawn hoop at the top, handle down: held up and to the left, it leans over to the left
        let finger = CGPoint(x: 500, y: 600)
        let hoop = FingerLift.point(finger, lift: FingerLift.tool, width: 1024)
        let a = FingerLift.turn(tip: .zero, center: CGPoint(x: 0, y: 80), finger: finger, lifted: hoop)
        XCTAssertLessThan(a, -0.2)
        XCTAssertGreaterThan(a, -0.7)
        let h = FingerLift.handle(tip: hoop, finger: finger, length: 150)
        XCTAssertGreaterThan(h.dir.dx, 0, "the handle goes down and to the right, to her finger")
        XCTAssertGreaterThan(h.dir.dy, 0)
    }

    func testAToolAtHerFingertipIsHeldHandleTowardHerHand() {
        // a tool drawn tip-up only leans a little to the left
        let a = FingerLift.turn(tip: CGPoint(x: 70, y: 10), center: CGPoint(x: 70, y: 70),
                                finger: CGPoint(x: 300, y: 300), lifted: CGPoint(x: 300, y: 300))
        XCTAssertLessThan(a, 0)
        XCTAssertGreaterThan(a, -0.5)
        // the handle goes down and to the right, toward her hand
        let h = FingerLift.handle(tip: CGPoint(x: 300, y: 300), finger: CGPoint(x: 300, y: 300), length: 150)
        XCTAssertGreaterThan(h.dir.dy, 0.8)
        XCTAssertGreaterThan(h.dir.dx, 0)
        XCTAssertEqual(h.length, 150)
        XCTAssertEqual(hypot(h.dir.dx, h.dir.dy), 1, accuracy: 0.001)
    }

    func testFullLiftAwayFromTheTop() {
        let p = FingerLift.point(CGPoint(x: 400, y: 600), lift: FingerLift.pour, width: 1024)
        XCTAssertEqual(p.x, 400 - FingerLift.leanSide * FingerLift.pour, accuracy: 0.001)
        XCTAssertEqual(p.y, 600 - FingerLift.pour, accuracy: 0.001)
    }

    func testNearTheTopItShrinksButStillFollowsTheFinger() {
        var last = -CGFloat.infinity
        for y in stride(from: CGFloat(0), through: 400, by: 5) {
            let p = FingerLift.point(CGPoint(x: 200, y: y), lift: FingerLift.pour, width: 1024)
            XCTAssertGreaterThan(p.y, last, "lifted point moves the same way as the finger at y \(y)")
            XCTAssertLessThan(p.y, y, "still above the finger at y \(y)")
            last = p.y
        }
        // at the very top it leans toward the middle instead
        XCTAssertGreaterThan(FingerLift.point(CGPoint(x: 100, y: 40), lift: FingerLift.pour, width: 1024).x, 100)
        XCTAssertLessThan(FingerLift.point(CGPoint(x: 900, y: 40), lift: FingerLift.pour, width: 1024).x, 900)
    }

    func testFingerForIsTheInverse() {
        for target in [CGPoint(x: 300, y: 500), CGPoint(x: 120, y: 30), CGPoint(x: 900, y: 90)] {
            let f = FingerLift.finger(for: target, lift: FingerLift.item, width: 1024)
            let back = FingerLift.point(f, lift: FingerLift.item, width: 1024)
            XCTAssertEqual(back.x, target.x, accuracy: 0.5)
            XCTAssertEqual(back.y, target.y, accuracy: 0.5)
        }
    }

    func testNearTheBottomItTurnsSidewaysSoLowSpotsCanBeReached() {
        // a patient's feet sit about 70 pt above the bottom of the screen
        let foot = CGPoint(x: 450, y: 764)
        let f = FingerLift.finger(for: foot, lift: FingerLift.pour, bottom: 834, width: 1024)
        XCTAssertLessThanOrEqual(f.y, 834, "her finger stays on the screen")
        let back = FingerLift.point(f, lift: FingerLift.pour, bottom: 834, width: 1024)
        XCTAssertEqual(back.x, foot.x, accuracy: 0.5)
        XCTAssertEqual(back.y, foot.y, accuracy: 0.5)
        XCTAssertGreaterThan(f.x, foot.x, "the tip sits to the left of her finger down there")
        // it still moves the same way as her finger, up and down and side to side
        var lastY = -CGFloat.infinity
        for y in stride(from: CGFloat(500), through: 834, by: 4) {
            let p = FingerLift.point(CGPoint(x: 500, y: y), lift: FingerLift.pour, bottom: 834, width: 1024)
            XCTAssertGreaterThan(p.y, lastY)
            lastY = p.y
        }
        var lastX = -CGFloat.infinity
        for x in stride(from: CGFloat(0), through: 1024, by: 4) {
            let p = FingerLift.point(CGPoint(x: x, y: 830), lift: FingerLift.pour, bottom: 834, width: 1024)
            XCTAssertGreaterThan(p.x, lastX)
            lastX = p.x
        }
    }

    func testToolsTurnSoTheHandlePointsAtTheFinger() {
        // tweezers drawn tip-down turn half way round when the tip is straight above her finger
        let a = FingerLift.turn(tip: CGPoint(x: 70, y: 130), center: CGPoint(x: 70, y: 70),
                                finger: CGPoint(x: 0, y: 120), lifted: .zero)
        XCTAssertEqual(abs(a), .pi, accuracy: 0.001)
        // a tool drawn tip-up doesn't turn
        XCTAssertEqual(FingerLift.turn(tip: CGPoint(x: 70, y: 10), center: CGPoint(x: 70, y: 70),
                                       finger: CGPoint(x: 0, y: 120), lifted: .zero), 0, accuracy: 0.001)
        // a sponge works with its middle: no turn
        XCTAssertEqual(FingerLift.turn(tip: CGPoint(x: 72, y: 76), center: CGPoint(x: 70, y: 70),
                                       finger: CGPoint(x: 0, y: 120), lifted: .zero), 0)
    }

    func testEaseGlidesToTheTarget() {
        var o = CGSize.zero
        for _ in 0..<30 { o = FingerLift.ease(o, toward: CGSize(width: 0, height: -100)) }
        XCTAssertEqual(o.height, -100, accuracy: 0.1)
    }
}
