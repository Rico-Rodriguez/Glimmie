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

    func testEaseGlidesToTheTarget() {
        var o = CGSize.zero
        for _ in 0..<30 { o = FingerLift.ease(o, toward: CGSize(width: 0, height: -100)) }
        XCTAssertEqual(o.height, -100, accuracy: 0.1)
    }
}
