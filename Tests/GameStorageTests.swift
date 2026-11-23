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

    func testRemovingRetiredSavesOnlyTouchesTheRetiredGame() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let retained = root.appendingPathComponent("dressup", isDirectory: true)
        let retired = root.appendingPathComponent("unicornstable", isDirectory: true)
        for folder in [retained, retired] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("saved".utf8).write(to: folder.appendingPathComponent("state.json"))
        }
        GameStorage.removeRetiredGameSaves(in: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: retired.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: retained.appendingPathComponent("state.json").path))
        XCTAssertTrue(GameStorage.isRetiredGameRecord("unicornstable/crown"))
        XCTAssertFalse(GameStorage.isRetiredGameRecord("garden/unicorn"))
    }
}
