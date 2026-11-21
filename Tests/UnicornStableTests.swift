import XCTest
@testable import Glimmie

final class UnicornStableTests: XCTestCase {
    func testJumpingPuddlesCollectsAllSixStars() throws {
        var ride = MeadowRide()
        for _ in 0..<6 {
            let jump = ride.needsJump
            XCTAssertFalse(ride.move(jump: jump))
        }
        let stop = try XCTUnwrap(ride.stop)
        XCTAssertEqual(stop.stars, 6)
        XCTAssertEqual(stop.puddles, 0)
        XCTAssertFalse(ride.move(jump: true))
        XCTAssertEqual(ride.step, 6)
    }

    func testPuddlesNeverBlockTheRouteAndVisitorsCycle() throws {
        var ride = MeadowRide()
        for expected in MeadowRide.route {
            for _ in 0..<6 { ride.move(jump: false) }
            let stop = try XCTUnwrap(ride.stop)
            XCTAssertEqual(stop.visitor, expected)
            XCTAssertEqual(stop.stars, 3)
            XCTAssertEqual(stop.puddles, 3)
            ride.continueRide()
            XCTAssertNil(ride.stop)
            XCTAssertEqual(ride.stars, 0)
        }
        XCTAssertEqual(ride.stretch, 0)
    }

    func testCustomizedUnicornRoundTripsAndHasAStickerPage() throws {
        let look = UnicornLook(coat: 0xFFE3EF, mane: 0x91D5E1, horn: 0xFFC858, braided: true, gear: .wings)
        let data = try JSONEncoder().encode(look)
        XCTAssertEqual(try JSONDecoder().decode(UnicornLook.self, from: data), look)
        XCTAssertEqual(UnicornGame.entry.stickers.map(\.id), MeadowVisitor.allCases.map(\.rawValue))
    }
}
