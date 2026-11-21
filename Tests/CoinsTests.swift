import XCTest
@testable import Glimmie

final class CoinsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Coins.shared.resetForTests()
    }

    func testEveryCustomerPaysAndHappierOnesPayMore() {
        XCTAssertEqual(Coins.reward(stars: 1), 3)
        XCTAssertEqual(Coins.reward(stars: 2), 4)
        XCTAssertEqual(Coins.reward(stars: 3), 5)
        XCTAssertEqual(Coins.reward(stars: 0), 3, "even a mixed-up order pays")
        XCTAssertEqual(Coins.reward(stars: 9), 5)
    }

    func testEarningFillsThePurse() {
        let c = Coins.shared
        c.earn(4, game: "bakery")
        c.earn(5, game: "pizza")
        XCTAssertEqual(c.balance, 9)
        XCTAssertEqual(c.earned, 9)
        XCTAssertEqual(c.lastPay?.game, "pizza")
        c.earn(0, game: "pizza")
        XCTAssertEqual(c.balance, 9)
    }

    func testCoinsCountOnlyOnceTheyLand() {
        let c = Coins.shared
        c.earn(3, game: "icecream")
        let at = c.lastPay!.at
        XCTAssertEqual(c.flying(game: "icecream", at: at), 3)
        XCTAssertEqual(c.flying(game: "bakery", at: at), 0, "another game's purse doesn't wait for them")
        XCTAssertEqual(c.flying(game: "icecream", at: at.addingTimeInterval(Coins.land(0) + 0.01)), 2)
        XCTAssertEqual(c.flying(game: "icecream", at: at.addingTimeInterval(Coins.land(2) + 0.01)), 0)
    }

    func testBuyingTakesCoinsOnceAndNeverGoesBelowZero() {
        let c = Coins.shared
        c.earn(10, game: "bakery")
        XCTAssertFalse(c.buy("shop/crown", price: 12))
        XCTAssertEqual(c.balance, 10)
        XCTAssertFalse(c.owns("shop/crown"))
        XCTAssertTrue(c.buy("shop/bow", price: 6))
        XCTAssertTrue(c.owns("shop/bow"))
        XCTAssertEqual(c.balance, 4)
        XCTAssertTrue(c.buy("shop/bow", price: 6), "buying it again keeps it and costs nothing")
        XCTAssertEqual(c.balance, 4)
        XCTAssertFalse(c.spend(5))
        XCTAssertTrue(c.spend(4))
        XCTAssertEqual(c.balance, 0)
    }

    func testTheCoinSoundsShip() {
        for name in ["coin", "till"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "wav"), name)
        }
    }

    func testTheFreeTraysStayWhole() {
        XCTAssertEqual(DecorKind.available.count, 8, "all the free garden decorations, no extras")
        XCTAssertEqual(AquaDecorKind.available.count, 12, "all the free tank decorations, no extras")
        XCTAssertEqual(UnicornGear.available, [.none, .bow, .saddle])
        XCTAssertFalse(DressUpArt.shared.category("hat")?.availableItems.contains("h_moonband") ?? true)
    }

    func testEveryTreasureShowsUpInItsGameOnceBought() {
        let gameIDs = Set(GameRegistry.all.map(\.id))
        var inGames = Set(DecorKind.allCases.compactMap(\.treasure) + AquaDecorKind.allCases.compactMap(\.treasure))
        inGames.formUnion(UnicornGear.allCases.compactMap(\.treasureID))
        inGames.formUnion(ArtCategory.treasureItems.values)
        XCTAssertEqual(Set(Treasures.all.map(\.id)).count, Treasures.all.count)
        for t in Treasures.all {
            XCTAssertTrue(gameIDs.contains(t.game), t.id)
            XCTAssertTrue(t.id.hasPrefix(t.game + "/"), t.id)
            XCTAssertTrue(inGames.contains(t.id), "\(t.id) has a place in its game")
            XCTAssertGreaterThan(t.price, 0)
        }
        Coins.shared.resetForTests(balance: 100)
        XCTAssertTrue(Coins.shared.buy("garden/unicorn", price: 15))
        XCTAssertTrue(Coins.shared.buy("aquarium/coral", price: 12))
        XCTAssertEqual(DecorKind.available.count, 9)
        XCTAssertEqual(DecorKind.available.last, .unicorn)
        XCTAssertEqual(AquaDecorKind.available.count, 13)
        XCTAssertEqual(AquaDecorKind.available.last, .rainbowCoral)
        XCTAssertTrue(Coins.shared.buy("unicornstable/crown", price: 8))
        XCTAssertTrue(Coins.shared.buy("unicornstable/wings", price: 12))
        XCTAssertEqual(UnicornGear.available, [.none, .bow, .saddle, .crown, .wings])
        XCTAssertTrue(Coins.shared.buy("dressup/h_moonband", price: 10))
        XCTAssertEqual(DressUpArt.shared.items["h_moonband"]?.category, "hat")
        XCTAssertTrue(DressUpArt.shared.category("hat")?.availableItems.contains("h_moonband") ?? false)
    }
}
