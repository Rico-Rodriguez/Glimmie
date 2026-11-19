import XCTest
@testable import Glimmie

/// Her progress must survive every update. These tests pin the save format.
final class SaveDataTests: XCTestCase {
    /// A save exactly as builds up to v1.0.23 wrote it (no "version" key).
    static let v1Save = Data("""
    {"madeAvatar":true,"avatar":{"skin":3,"hairStyle":2,"hairColor":5,"eyes":4},
     "outfit":{"dress":{"item":"dress_gown","color":6},"hat":{"item":"hat_crown","color":0}},
     "stars":4,"wishesDone":17,"owned":[0,3,5],"secrets":["fairy_queen"],"eggWaiting":false}
    """.utf8)

    /// Every field set to something other than its default, so the round trip covers all of them.
    /// When you add a field to SaveData or Avatar, give it a non-default value here.
    static let everyField = SaveData(
        version: 7, madeAvatar: true,
        avatar: Avatar(skin: 4, hairStyle: 0, hairColor: 7, eyes: 3),
        outfit: ["wings": Worn(item: "wings_fairy", color: 2)],
        stars: 2, wishesDone: 9, owned: [0, 1, 2, 3], secrets: ["star_fairy", "party_bunny"], eggWaiting: true,
        adventure: AdventureSave(stop: 14, backdrops: ["sea", "stars"], backdrop: "stars", buddy: 3, best: ["memory": 28]))

    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "glimmie.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    // MARK: Decoding

    func testLoadsAVersion1Save() throws {
        let s = try JSONDecoder().decode(SaveData.self, from: Self.v1Save)
        XCTAssertEqual(s.version, 1)
        XCTAssertTrue(s.madeAvatar)
        XCTAssertEqual(s.avatar, Avatar(skin: 3, hairStyle: 2, hairColor: 5, eyes: 4))
        XCTAssertEqual(s.outfit, ["dress": Worn(item: "dress_gown", color: 6), "hat": Worn(item: "hat_crown", color: 0)])
        XCTAssertEqual(s.stars, 4)
        XCTAssertEqual(s.wishesDone, 17)
        XCTAssertEqual(s.owned, [0, 3, 5])
        XCTAssertEqual(s.secrets, ["fairy_queen"])
        XCTAssertFalse(s.eggWaiting)
        XCTAssertEqual(s.adventure, AdventureSave(), "a save from before the Sparkle Path starts at the first stop")
    }

    func testABadAdventureFieldOnlyResetsThatField() throws {
        let json = #"{"stars":2,"adventure":{"stop":"far","backdrops":["sea",3,"snow"],"backdrop":"snow","buddy":2}}"#
        let s = try JSONDecoder().decode(SaveData.self, from: Data(json.utf8))
        XCTAssertEqual(s.stars, 2)
        XCTAssertEqual(s.adventure.stop, 0)
        XCTAssertEqual(s.adventure.backdrops, ["sea", "snow"])
        XCTAssertEqual(s.adventure.backdrop, "snow")
        XCTAssertEqual(s.adventure.buddy, 2)
    }

    func testMissingFieldsGetTheirDefaults() throws {
        let s = try JSONDecoder().decode(SaveData.self, from: Data(#"{"stars":3,"avatar":{"skin":2}}"#.utf8))
        XCTAssertEqual(s.stars, 3)
        XCTAssertEqual(s.avatar.skin, 2)
        XCTAssertEqual(s.avatar.hairStyle, Avatar().hairStyle)
        XCTAssertEqual(s.outfit, SaveData().outfit)
        XCTAssertEqual(s.owned, SaveData().owned)
        XCTAssertFalse(s.madeAvatar)
    }

    func testABadFieldOnlyResetsThatField() throws {
        let json = #"{"stars":"five","wishesDone":12,"owned":[0,"x",4],"secrets":["garden_girl",7],"#
            + #""outfit":{"dress":{"color":2},"hat":{"item":"hat_bow","color":"red"}}}"#
        let s = try JSONDecoder().decode(SaveData.self, from: Data(json.utf8))
        XCTAssertEqual(s.stars, 0)
        XCTAssertEqual(s.wishesDone, 12)
        XCTAssertEqual(s.owned, [0, 4])
        XCTAssertEqual(s.secrets, ["garden_girl"])
        XCTAssertEqual(s.outfit, ["hat": Worn(item: "hat_bow", color: 0)])
    }

    func testRoundTripKeepsEveryField() throws {
        let data = try JSONEncoder().encode(Self.everyField)
        XCTAssertEqual(try JSONDecoder().decode(SaveData.self, from: data), Self.everyField)
    }

    /// Fails when a field is added without a non-default value in `everyField`,
    /// which would let a forgotten `init(from:)` line slip through the round trip.
    func testEveryFieldFixtureCoversAllFields() {
        let pairs = [(Mirror(reflecting: SaveData()), Mirror(reflecting: Self.everyField), "SaveData"),
                     (Mirror(reflecting: Avatar()), Mirror(reflecting: Self.everyField.avatar), "Avatar"),
                     (Mirror(reflecting: AdventureSave()), Mirror(reflecting: Self.everyField.adventure), "AdventureSave")]
        for (base, fixture, name) in pairs {
            XCTAssertEqual(base.children.count, fixture.children.count)
            for (d, f) in zip(base.children, fixture.children) {
                XCTAssertNotEqual(String(describing: d.value), String(describing: f.value),
                                  "Give \(name).\(d.label ?? "?") a non-default value in everyField")
            }
        }
    }

    // MARK: Store

    func testAnOlderSaveIsBackedUpBeforeUpgrading() {
        defaults.set(Self.v1Save, forKey: SaveStore.key)
        XCTAssertEqual(SaveStore(defaults: defaults).load().wishesDone, 17)
        XCTAssertEqual(defaults.data(forKey: SaveStore.backupKey + ".v1"), Self.v1Save)
    }

    func testAnUnreadableSaveIsKept() {
        let junk = Data("not json".utf8)
        defaults.set(junk, forKey: SaveStore.key)
        XCTAssertEqual(SaveStore(defaults: defaults).load(), SaveData())
        XCTAssertEqual(defaults.data(forKey: SaveStore.backupKey + ".unreadable"), junk)
    }

    func testSavingKeepsFieldsFromANewerBuild() throws {
        defaults.set(Data(#"{"version":3,"stars":1,"closet":{"rooms":2}}"#.utf8), forKey: SaveStore.key)
        let store = SaveStore(defaults: defaults)
        var s = store.load()
        s.stars = 4
        store.save(s)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: SaveStore.key))) as? [String: Any])
        XCTAssertEqual(saved["stars"] as? Int, 4)
        XCTAssertEqual(saved["version"] as? Int, 3)
        XCTAssertEqual((saved["closet"] as? [String: Any])?["rooms"] as? Int, 2)
    }

    func testMergeDropsKnownFieldsTheNewSaveLeftOut() throws {
        let merged = SaveStore.merge(Data(#"{"a":5}"#.utf8), over: Data(#"{"a":1,"b":2,"x":9}"#.utf8), known: ["a", "b"])
        XCTAssertEqual(try XCTUnwrap(JSONSerialization.jsonObject(with: merged) as? [String: Int]), ["a": 5, "x": 9])
    }

    // MARK: Game state

    func testGameStateSavesAndLoadsEverything() {
        let g = GameState(defaults: defaults)
        g.madeAvatar = true
        g.avatar = Avatar(skin: 0, hairStyle: 2, hairColor: 3, eyes: 1)
        g.outfit = [.hat: Worn(item: "hat_star", color: 0), .dress: Worn(item: "dress_tutu", color: 4)]
        g.stars = 3
        g.wishesDone = 8
        g.owned = [0, 2]
        g.secrets = ["garden_girl"]
        g.eggWaiting = true
        g.adventure = AdventureSave(stop: 7, backdrops: ["castle"], backdrop: "castle", buddy: 2, best: ["catchStars": 19])

        let again = GameState(defaults: defaults)
        XCTAssertTrue(again.madeAvatar)
        XCTAssertEqual(again.avatar, g.avatar)
        XCTAssertEqual(again.outfit, g.outfit)
        XCTAssertEqual(again.stars, 3)
        XCTAssertEqual(again.wishesDone, 8)
        XCTAssertEqual(again.owned, [0, 2])
        XCTAssertEqual(again.secrets, ["garden_girl"])
        XCTAssertTrue(again.eggWaiting)
        XCTAssertEqual(again.adventure, g.adventure)
    }

    // MARK: Sparkle Path

    func testStarsFillTheJarAndBecomeAnEgg() {
        let g = GameState(defaults: defaults)
        g.addStars(3)
        XCTAssertEqual(g.stars, 3)
        XCTAssertFalse(g.eggWaiting)
        g.addStars(3)
        XCTAssertTrue(g.eggWaiting)
        XCTAssertEqual(g.stars, 1, "extra stars carry over")
        g.addStars(3)
        XCTAssertEqual(g.stars, GameState.jarSize - 1, "while an egg waits the jar never overflows")
    }

    func testBestScoresOnlyGoUp() {
        let g = GameState(defaults: defaults)
        XCTAssertTrue(g.record("memory", score: 20))
        XCTAssertFalse(g.record("memory", score: 12))
        XCTAssertEqual(g.adventure.best["memory"], 20)
    }

    func testBuddyIsAlwaysAnOwnedGlimmie() {
        let g = GameState(defaults: defaults)
        g.owned = [0, 3]
        g.adventure.buddy = 5
        XCTAssertEqual(g.buddy, 3)
        g.adventure.buddy = 0
        XCTAssertEqual(g.buddy, 0)
    }

    func testPathHasChestsEveryFourthStopAndEveryGameEachWorld() {
        for stop in 0..<(Adventure.stopsPerWorld * 8) {
            XCTAssertEqual(Adventure.kind(at: stop) == .chest, stop % 4 == 3, "stop \(stop)")
        }
        XCTAssertEqual(Adventure.kind(at: 0), .catchStars, "the first game is the easiest to understand")
        for w in 0..<8 {
            let kinds = Set((0..<Adventure.stopsPerWorld).map { Adventure.kind(at: w * Adventure.stopsPerWorld + $0) })
            XCTAssertEqual(kinds, Set(StopKind.allCases), "world \(w) has every kind of stop")
        }
        XCTAssertTrue(Adventure.isWorldEnd(11))
        XCTAssertFalse(Adventure.isWorldEnd(7))
        XCTAssertEqual(Adventure.spots.count, Adventure.stopsPerWorld)
    }

    func testUnknownBackdropsFromANewerBuildAreKept() throws {
        defaults.set(Data(#"{"madeAvatar":true,"adventure":{"stop":4,"backdrops":["sea","sea","moonbase"],"backdrop":"moonbase"}}"#.utf8),
                     forKey: SaveStore.key)
        let g = GameState(defaults: defaults)
        XCTAssertEqual(g.adventure.backdrops, ["sea", "moonbase"])
        XCTAssertNil(Backdrops.find(g.adventure.backdrop), "the stage shows the classic pink for a backdrop it doesn't know")
        g.stars = 1
        let saved = try JSONDecoder().decode(SaveData.self, from: XCTUnwrap(defaults.data(forKey: SaveStore.key)))
        XCTAssertEqual(saved.adventure.backdrops, ["sea", "moonbase"])
    }

    func testGameStateLoadsAVersion1Save() {
        defaults.set(Self.v1Save, forKey: SaveStore.key)
        let g = GameState(defaults: defaults)
        XCTAssertEqual(g.avatar, Avatar(skin: 3, hairStyle: 2, hairColor: 5, eyes: 4))
        XCTAssertEqual(g.outfit, [.dress: Worn(item: "dress_gown", color: 6), .hat: Worn(item: "hat_crown", color: 0)])
        XCTAssertEqual(g.owned, [0, 3, 5])
        XCTAssertEqual(g.stars, 4)
    }

    func testGameStateClampsBadValues() {
        let bad = #"{"madeAvatar":true,"avatar":{"skin":40,"hairStyle":-2,"hairColor":99,"eyes":5},"#
            + #""outfit":{"dress":{"item":"dress_gown","color":12},"hat":{"item":"dress_tutu","color":0},"#
            + #""shoes":{"item":"shoes_rocket","color":1},"cape":{"item":"hat_bow","color":0}},"#
            + #""stars":5,"wishesDone":-3,"owned":[0,0,-1,42]}"#
        defaults.set(Data(bad.utf8), forKey: SaveStore.key)
        let g = GameState(defaults: defaults)
        XCTAssertEqual(g.avatar, Avatar(skin: Palette.skin.count - 1, hairStyle: 0,
                                        hairColor: Palette.hair.count - 1, eyes: Palette.eyes.count - 1))
        XCTAssertEqual(g.outfit, [.dress: Worn(item: "dress_gown", color: Palette.clothes.count - 1)])
        XCTAssertEqual(g.stars, 0)
        XCTAssertTrue(g.eggWaiting, "a full jar on launch becomes the egg")
        XCTAssertEqual(g.wishesDone, 0)
        XCTAssertEqual(g.owned, [0])
        XCTAssertEqual(g.nextGlimmie, 1)
    }

    func testGlimmiesFromANewerBuildSurviveButStayHidden() throws {
        defaults.set(Data(#"{"madeAvatar":true,"owned":[0,1,12]}"#.utf8), forKey: SaveStore.key)
        let g = GameState(defaults: defaults)
        XCTAssertEqual(g.owned, [0, 1])
        let wish = Wish.make(level: 0, glimmies: g.owned, avoid: g.outfit)
        XCTAssertTrue(Glimmies.all.indices.contains(wish.glimmie))
        g.stars = 1
        let saved = try JSONDecoder().decode(SaveData.self, from: XCTUnwrap(defaults.data(forKey: SaveStore.key)))
        XCTAssertEqual(saved.owned, [0, 1, 12])
    }

    func testResetStartsOverAndKeepsABackup() {
        let g = GameState(defaults: defaults)
        g.madeAvatar = true
        g.owned = [0, 1, 2]
        g.resetAll()
        XCTAssertNotNil(defaults.data(forKey: SaveStore.backupKey + ".before-reset"))
        let again = GameState(defaults: defaults)
        XCTAssertFalse(again.madeAvatar)
        XCTAssertEqual(again.owned, [0])
    }
}
