import XCTest
@testable import Glimmie

final class GameStorageTests: XCTestCase {
    func testEveryGameHasAUniqueId() {
        let ids = GameRegistry.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertFalse(ids.isEmpty)
    }

    func testSaveAndLoadRoundTrip() {
        struct Box: Codable, Equatable { var n: Int; var s: String }
        let game = "tests-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(at: GameStorage.folder(game)) }
        XCTAssertNil(GameStorage.load(Box.self, game: game, file: "box.json"))
        GameStorage.save(Box(n: 3, s: "hi"), game: game, file: "box.json")
        XCTAssertEqual(GameStorage.load(Box.self, game: game, file: "box.json"), Box(n: 3, s: "hi"))
    }
}
