import UIKit
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

    func testIllustratedScenesAndAnimatedPortraitAreBundled() throws {
        let unicorn = try XCTUnwrap(UnicornIllustration.source("unicorn"))
        for name in ["contented", "nibble"] {
            let reaction = try XCTUnwrap(UnicornIllustration.source(name), name)
            XCTAssertEqual(reaction.size, unicorn.size, name)
        }
        for name in ["stable", "meadow"] {
            XCTAssertNotNil(UnicornIllustration.source(name), name)
        }
        let otherCoat = try XCTUnwrap(UnicornIllustration.sprite("unicorn", look: UnicornLook(coat: 0xADDCC6)))
        XCTAssertEqual(otherCoat.size, unicorn.size)
        XCTAssertNotEqual(otherCoat.pngData(), unicorn.pngData())
    }
}
