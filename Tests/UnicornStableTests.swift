import CoreGraphics
import XCTest
@testable import Glimmie

final class UnicornStableTests: XCTestCase {
    func testDirtySpotsNeedSoapAndThenRinsing() {
        var care = StableCare()
        XCTAssertFalse(care.use(.rinse, at: .shoulder))
        XCTAssertTrue(care.use(.sponge, at: .shoulder))
        XCTAssertFalse(care.dirt.contains(.shoulder))
        XCTAssertTrue(care.soap.contains(.shoulder))
        XCTAssertFalse(care.use(.sponge, at: .shoulder))
        for spot in CareSpot.coat where spot != .shoulder { XCTAssertTrue(care.use(.sponge, at: spot)) }
        XCTAssertFalse(care.washed)
        for spot in CareSpot.coat { XCTAssertTrue(care.use(.rinse, at: spot)) }
        XCTAssertTrue(care.washed)
    }

    func testCareCompletesOnceAllThreeNeedsAreMetAndPersists() throws {
        var care = StableCare()
        XCTAssertFalse(care.use(.feed, at: .tail))
        for spot in CareSpot.hair { XCTAssertTrue(care.use(.brush, at: spot)) }
        XCTAssertFalse(care.use(.brush, at: .mane))
        for spot in CareSpot.coat {
            XCTAssertTrue(care.use(.sponge, at: spot))
            XCTAssertTrue(care.use(.rinse, at: spot))
        }
        XCTAssertTrue(care.use(.feed, at: .muzzle))
        XCTAssertFalse(care.complete)
        XCTAssertTrue(care.use(.feed, at: .muzzle))
        XCTAssertFalse(care.use(.feed, at: .muzzle))
        XCTAssertTrue(care.complete)
        XCTAssertEqual(try JSONDecoder().decode(StableCare.self, from: JSONEncoder().encode(care)), care)
    }

    func testCustomizedUnicornRoundTripsAndHasAStickerPage() throws {
        let look = UnicornLook(coat: 0xFFE3EF, mane: 0x91D5E1, horn: 0xFFC858, braided: true, gear: .wings)
        let data = try JSONEncoder().encode(look)
        XCTAssertEqual(try JSONDecoder().decode(UnicornLook.self, from: data), look)
        XCTAssertEqual(UnicornGame.entry.stickers.map(\.id), MeadowVisitor.allCases.map(\.rawValue))
    }

    func testSharedUnicornRigAndCarePropsAreBundled() throws {
        let art = PetArt.shared
        let foal = try XCTUnwrap(art.animals["unicorn"])
        for part in UnicornPart.allCases {
            XCTAssertFalse(try XCTUnwrap(art.unicornRig[part.rawValue], part.rawValue).isEmpty)
        }
        for prop in ["brush", "sponge", "shower", "carrot"] {
            XCTAssertFalse(try XCTUnwrap(art.props[prop], prop).isEmpty)
        }
        for mouth in ["wide", "yum", "grin"] { XCTAssertNotNil(foal.mouths[mouth], mouth) }
    }

    func testNibblingMovesTheHeadAndProjectsTheMuzzleWithIt() {
        let pose = UnicornPose.frame(time: 2, age: 0.15, motion: .nibble)
        XCTAssertEqual(pose.mouth, "wide")
        XCTAssertNotEqual(pose.transform(.head), .identity)
        XCTAssertEqual(pose.transform(.torso), .identity)
        XCTAssertEqual(pose.transform(.foreLeft), .identity)
        XCTAssertGreaterThan(UnicornRig.point(.muzzle, pose: pose).y, UnicornRig.point(.muzzle).y)
        let frame = CGRect(x: 200, y: 90, width: 640, height: 550)
        let muzzle = UnicornRig.point(.muzzle, pose: pose)
        let back = UnicornRig.unproject(UnicornRig.project(muzzle, into: frame), from: frame)
        XCTAssertEqual(back.x, muzzle.x, accuracy: 0.01)
        XCTAssertEqual(back.y, muzzle.y, accuracy: 0.01)
    }

    func testWalkingAlternatesHoovesAndHonorsReduceMotion() {
        let walk = UnicornPose.frame(time: 2, age: 0.4, motion: .stroll)
        XCTAssertNotEqual(walk.transform(.foreLeft), walk.transform(.foreRight))
        XCTAssertNotEqual(walk.transform(.hindLeft), walk.transform(.hindRight))
        XCTAssertEqual(walk.transform(.torso), .identity)
        let reduced = UnicornPose.frame(time: 2, age: 0.4, motion: .stroll, reduceMotion: true)
        XCTAssertEqual(reduced.transform(.head), .identity)
        XCTAssertEqual(reduced.transform(.tail), .identity)
        XCTAssertEqual(reduced.transform(.foreLeft), .identity)
    }
}
