import XCTest
@testable import Glimmie

final class FingerLiftTests: XCTestCase {
    func testFullLiftAwayFromTheTop() {
        let p = FingerLift.point(CGPoint(x: 400, y: 600), width: 1024)
        XCTAssertEqual(p.x, 400, accuracy: 0.001)
        XCTAssertEqual(p.y, 600 - FingerLift.tool, accuracy: 0.001)
    }

    func testNearTheTopItShrinksButStillFollowsTheFinger() {
        var last = -CGFloat.infinity
        for y in stride(from: CGFloat(0), through: 400, by: 5) {
            let p = FingerLift.point(CGPoint(x: 200, y: y), width: 1024)
            XCTAssertGreaterThan(p.y, last, "lifted point moves the same way as the finger at y \(y)")
            XCTAssertLessThan(p.y, y, "still above the finger at y \(y)")
            last = p.y
        }
        // at the very top it leans toward the middle instead
        XCTAssertGreaterThan(FingerLift.point(CGPoint(x: 100, y: 40), width: 1024).x, 100)
        XCTAssertLessThan(FingerLift.point(CGPoint(x: 900, y: 40), width: 1024).x, 900)
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
        let f = FingerLift.finger(for: foot, bottom: 834, width: 1024)
        XCTAssertLessThanOrEqual(f.y, 834, "her finger stays on the screen")
        let back = FingerLift.point(f, bottom: 834, width: 1024)
        XCTAssertEqual(back.x, foot.x, accuracy: 0.5)
        XCTAssertEqual(back.y, foot.y, accuracy: 0.5)
        XCTAssertGreaterThan(f.x, foot.x, "the tip sits to the left of her finger down there")
        // it still moves the same way as her finger, up and down and side to side
        var lastY = -CGFloat.infinity
        for y in stride(from: CGFloat(500), through: 834, by: 4) {
            let p = FingerLift.point(CGPoint(x: 500, y: y), bottom: 834, width: 1024)
            XCTAssertGreaterThan(p.y, lastY)
            lastY = p.y
        }
        var lastX = -CGFloat.infinity
        for x in stride(from: CGFloat(0), through: 1024, by: 4) {
            let p = FingerLift.point(CGPoint(x: x, y: 830), bottom: 834, width: 1024)
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
