import XCTest
@testable import Glimmie

final class DrawerLayoutTests: XCTestCase {
    /// Grid area on an 11-inch iPad in landscape, under the title.
    private let ipad11 = CGSize(width: 1194, height: 690)

    func testNineGamesFitOnOneScreen() {
        let layout = DrawerLayout.best(count: 9, in: ipad11)
        XCTAssertGreaterThanOrEqual(layout.tile, DrawerLayout.minFitTile)
        let rows = (9 + layout.columns - 1) / layout.columns
        let height = CGFloat(rows) * (layout.tile + DrawerLayout.labelHeight)
            + CGFloat(rows - 1) * DrawerLayout.rowSpacing + DrawerLayout.verticalPadding * 2
        XCTAssertLessThanOrEqual(height, ipad11.height)
    }

    func testManyGamesKeepBigTilesAndScroll() {
        let layout = DrawerLayout.best(count: 14, in: ipad11)
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
