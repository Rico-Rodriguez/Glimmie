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
}
