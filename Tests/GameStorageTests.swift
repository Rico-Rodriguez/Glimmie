import SwiftUI
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

    func testSaveAsyncRoundTripAndSerialOrdering() {
        struct Box: Codable, Equatable { var n: Int; var s: String }
        let game = "tests-async-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(at: GameStorage.folder(game)) }

        GameStorage.saveAsync(Box(n: 1, s: "first"), game: game, file: "async.json")
        GameStorage.saveAsync(Box(n: 2, s: "second"), game: game, file: "async.json")
        GameStorage.flushAsyncSaves()

        XCTAssertEqual(GameStorage.load(Box.self, game: game, file: "async.json"), Box(n: 2, s: "second"))
    }

    func testDeferredCoinAndStickerHelpersDeliverOnMainQueue() {
        Coins.shared.resetForTests(balance: 0)
        StickerBook.shared.resetForTests()

        let exp = expectation(description: "deferred rewards delivered")
        Coins.shared.earnDeferred(3, game: "bakery")
        StickerBook.shared.findDeferred(game: "sample", id: "deferred")
        DispatchQueue.main.async {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(Coins.shared.balance, 3)
        XCTAssertTrue(StickerBook.shared.has(game: "sample", id: "deferred"))
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

    func testGameFilesSoundResolvesBundledAudioAndNilWhenMissing() {
        let url = GameFiles.sound("bloop", game: "Aquarium")
        XCTAssertNotNil(url)
        XCTAssertTrue(["caf", "wav"].contains(url?.pathExtension ?? ""))
        XCTAssertNil(GameFiles.sound("missing-sound-asset", game: "Aquarium"))
    }

    func testEverySharedSFXShipsWithBundledAudio() {
        for sfx in SFX.allCases {
            XCTAssertNotNil(Sound.url(for: sfx), sfx.rawValue)
        }
    }

    func testStickerBookConsumeUnseenSnapshotsBeforeClearing() {
        let book = StickerBook.shared
        book.resetForTests()
        XCTAssertTrue(book.find(game: "garden", id: "frog"))
        XCTAssertTrue(book.find(game: "garden", id: "bunny"))
        XCTAssertTrue(book.find(game: "aquarium", id: "crab"))
        XCTAssertEqual(book.unseenKeys(game: "garden"), ["garden/frog", "garden/bunny"])

        let snapshot = book.consumeUnseen(game: "garden")
        XCTAssertEqual(snapshot, ["garden/frog", "garden/bunny"])
        XCTAssertFalse(book.hasUnseen(game: "garden"))
        XCTAssertTrue(book.unseenKeys(game: "garden").isEmpty)
        XCTAssertTrue(book.hasUnseen(game: "aquarium"))
        XCTAssertTrue(book.consumeUnseen(game: "garden").isEmpty)
    }

    func testStickerBookPageCompletionAndToastTiming() throws {
        let book = StickerBook.shared
        book.resetForTests()
        let stickers = [
            Sticker(id: "one") { _, _ in },
            Sticker(id: "two") { _, _ in },
        ]
        XCTAssertFalse(book.isPageComplete(game: "sample", stickers: []))
        XCTAssertFalse(book.isPageComplete(game: "sample", stickers: stickers))
        XCTAssertFalse(book.isToastAnimating(for: "sample"))
        XCTAssertFalse(book.isLandingBumpActive(for: "sample"))

        XCTAssertTrue(book.find(game: "sample", id: "one"))
        let foundAt = try XCTUnwrap(book.lastFind?.at)
        XCTAssertTrue(book.isToastAnimating(for: "sample", at: foundAt))
        XCTAssertFalse(book.isToastAnimating(for: "other", at: foundAt))
        XCTAssertFalse(book.isToastAnimating(for: "sample", at: foundAt.addingTimeInterval(StickerToast.flight + 0.01)))
        XCTAssertTrue(book.isLandingBumpActive(for: "sample", at: foundAt.addingTimeInterval(StickerToast.flight + 0.2)))
        XCTAssertFalse(book.isLandingBumpActive(for: "sample", at: foundAt.addingTimeInterval(StickerBook.landingWindow + 0.01)))
        XCTAssertEqual(book.progress(game: "sample", stickers: stickers), StickerBook.PageProgress(found: 1, total: 2))
        XCTAssertFalse(book.isPageComplete(game: "sample", stickers: stickers))

        XCTAssertTrue(book.find(game: "sample", id: "two"))
        XCTAssertEqual(book.progress(game: "sample", stickers: stickers), StickerBook.PageProgress(found: 2, total: 2))
        XCTAssertTrue(book.isPageComplete(game: "sample", stickers: stickers))
    }
}
