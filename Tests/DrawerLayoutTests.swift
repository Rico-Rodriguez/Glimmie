import XCTest
@testable import Glimmie

final class DrawerLayoutTests: XCTestCase {
    /// Grid area on an 11-inch iPad in landscape, under the title.
    private let ipad11 = CGSize(width: 1194, height: 760)
    /// Grid area on an iPad mini in landscape, under the title.
    private let mini = CGSize(width: 1133, height: 680)

    /// Every game in the drawer today is on one screen, with no scrolling, even on the smallest iPad.
    func testAllGamesFitOnOneScreen() {
        for size in [ipad11, mini] {
            let n = GameRegistry.all.count
            let layout = DrawerLayout.best(count: n, in: size)
            XCTAssertGreaterThanOrEqual(layout.tile, DrawerLayout.minFitTile, "\(size)")
            let rows = (n + layout.columns - 1) / layout.columns
            let height = CGFloat(rows) * (layout.tile + DrawerLayout.labelHeight)
                + CGFloat(rows - 1) * DrawerLayout.rowSpacing + DrawerLayout.verticalPadding * 2
            XCTAssertLessThanOrEqual(height, size.height, "\(size)")
        }
    }

    func testNineGamesFitOnOneScreen() {
        let layout = DrawerLayout.best(count: 9, in: ipad11)
        XCTAssertGreaterThanOrEqual(layout.tile, DrawerLayout.minFitTile)
        let rows = (9 + layout.columns - 1) / layout.columns
        let height = CGFloat(rows) * (layout.tile + DrawerLayout.labelHeight)
            + CGFloat(rows - 1) * DrawerLayout.rowSpacing + DrawerLayout.verticalPadding * 2
        XCTAssertLessThanOrEqual(height, ipad11.height)
    }

    func testManyGamesKeepBigTilesAndScroll() {
        let layout = DrawerLayout.best(count: 24, in: ipad11)
        XCTAssertGreaterThanOrEqual(layout.tile, DrawerLayout.scrollTile)
        XCTAssertGreaterThan(layout.columns, 1)
    }

    func testGridFitsTheWidth() {
        for size in [ipad11, CGSize(width: 834, height: 1050), CGSize(width: 1366, height: 880), CGSize(width: 700, height: 600)] {
            for count in [1, 4, 9, 12, 20] {
                let l = DrawerLayout.best(count: count, in: size)
                let width = CGFloat(l.columns) * l.tile + CGFloat(l.columns - 1) * DrawerLayout.columnSpacing
                XCTAssertLessThanOrEqual(width, size.width, "\(count) games in \(size)")
                XCTAssertLessThanOrEqual(l.tile, DrawerLayout.maxTile)
            }
        }
    }

    func testBalancedCenteredRowsForTwelveAndThirteenTiles() {
        XCTAssertEqual(DrawerLayout.rows(count: 0, columns: 4), [])
        XCTAssertEqual(DrawerLayout.rows(count: 11, columns: 4), [4, 4, 3])
        XCTAssertEqual(DrawerLayout.rows(count: 12, columns: 4), [4, 4, 4])
        XCTAssertEqual(DrawerLayout.rows(count: 13, columns: 5), [5, 4, 4])
        XCTAssertEqual(DrawerLayout.rows(count: 13, columns: 4), [4, 3, 3, 3])

        let split12 = DrawerLayout.split(Array(0..<12), columns: 4)
        XCTAssertEqual(split12.map(\.count), [4, 4, 4])
        XCTAssertEqual(split12.flatMap { $0 }, Array(0..<12))

        let split13 = DrawerLayout.split(Array(0..<13), columns: 5)
        XCTAssertEqual(split13.map(\.count), [5, 4, 4])
        XCTAssertEqual(split13.flatMap { $0 }, Array(0..<13))
    }

    func testTwelveAndThirteenTilesFitBalancedOnIPadSizes() {
        for count in [12, 13] {
            for size in [ipad11, mini] {
                let layout = DrawerLayout.best(count: count, in: size)
                let rows = DrawerLayout.rows(count: count, columns: layout.columns)
                XCTAssertEqual(rows.reduce(0, +), count)
                XCTAssertLessThanOrEqual((rows.max() ?? 0) - (rows.min() ?? 0), 1)
                XCTAssertLessThanOrEqual(rows.max() ?? 0, layout.columns)
                XCTAssertGreaterThanOrEqual(layout.tile, DrawerLayout.minFitTile, "\(count) in \(size)")
                let height = CGFloat(rows.count) * (layout.tile + DrawerLayout.labelHeight)
                    + CGFloat(rows.count - 1) * DrawerLayout.rowSpacing + DrawerLayout.verticalPadding * 2
                XCTAssertLessThanOrEqual(height, size.height, "\(count) in \(size)")
            }
        }
    }
}
