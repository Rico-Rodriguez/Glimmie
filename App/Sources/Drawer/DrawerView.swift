import SwiftUI

/// The home screen: a toy drawer with one big tile per game, laid out in rows and columns.
struct DrawerView: View {
    let open: (String) -> Void
    @State private var book = false
    @State private var shop = DrawerView.launchShop

    var body: some View {
        ZStack {
            DrawerBackground()
            VStack(spacing: 0) {
                Title()
                    .padding(.top, 14)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        // the sticker book: every game's surprises in one place
                        HStack(spacing: 16) {
                            TreasureShopButton { withAnimation(.easeOut(duration: 0.2)) { shop = true } }
                            if !StickerBook.pages.isEmpty {
                                StickerBookButton(size: 64) { withAnimation(.easeOut(duration: 0.2)) { book = true } }
                            }
                        }
                        .padding(.trailing, DrawerLayout.sidePadding)
                        .padding(.top, 10)
                    }
                GeometryReader { geo in
                    let layout = DrawerLayout.best(count: GameRegistry.all.count, in: geo.size)
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(layout.tile), spacing: DrawerLayout.columnSpacing),
                                                 count: layout.columns),
                                  spacing: DrawerLayout.rowSpacing) {
                            ForEach(GameRegistry.all) { game in
                                GameTile(game: game, size: layout.tile) {
                                    Sound.shared.play(.pop)
                                    Sound.shared.tap()
                                    open(game.id)
                                }
                            }
                        }
                        .padding(.vertical, DrawerLayout.verticalPadding)
                        .frame(width: geo.size.width)
                        .frame(minHeight: geo.size.height)
                    }
                    .bounceOnlyWhenScrolling()
                }
            }
            if book {
                StickerBookView { withAnimation(.easeOut(duration: 0.2)) { book = false } }
                    .transition(.opacity)
                    .zIndex(2)
            }
            if shop {
                TreasureShopView { withAnimation(.easeOut(duration: 0.2)) { shop = false } }
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
    }

    /// `-treasureShop` on launch opens the treasure shop (for screenshots).
    static var launchShop: Bool { ProcessInfo.processInfo.arguments.contains("-treasureShop") }
}

/// Picks how many columns the drawer grid uses and how big each tile is.
/// Every game should be on screen at once, like a table of tiles: it picks the biggest tiles that
/// show them all without scrolling. Only when there are so many games that the tiles would get too
/// small to tap does the grid scroll up and down.
struct DrawerLayout: Equatable {
    let columns: Int
    let tile: CGFloat

    static let columnSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 16
    static let sidePadding: CGFloat = 32
    static let verticalPadding: CGFloat = 12
    /// Room under each tile for its name.
    static let labelHeight: CGFloat = 40
    static let maxTile: CGFloat = 260
    /// Smallest tile we accept to fit everything on one screen.
    static let minFitTile: CGFloat = 140
    /// Tile size to aim for once the grid has to scroll.
    static let scrollTile: CGFloat = 160

    static func tileWidth(columns: Int, width: CGFloat) -> CGFloat {
        (width - sidePadding * 2 - columnSpacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    static func best(count: Int, in size: CGSize) -> DrawerLayout {
        let n = max(1, count)
        var bestFit: DrawerLayout?
        for cols in 1...n {
            let rows = (n + cols - 1) / cols
            let byHeight = (size.height - verticalPadding * 2 - rowSpacing * CGFloat(rows - 1)) / CGFloat(rows) - labelHeight
            let tile = min(tileWidth(columns: cols, width: size.width), byHeight, maxTile)
            if tile >= minFitTile, tile > (bestFit?.tile ?? 0) {
                bestFit = DrawerLayout(columns: cols, tile: tile)
            }
        }
        if let bestFit { return bestFit }
        // Too many to fit: the most columns that keep tiles at least `scrollTile` wide.
        var cols = 1
        while cols < n, tileWidth(columns: cols + 1, width: size.width) >= scrollTile { cols += 1 }
        let tile = max(120, min(tileWidth(columns: cols, width: size.width), maxTile))
        return DrawerLayout(columns: cols, tile: tile)
    }
}

private extension View {
    @ViewBuilder func bounceOnlyWhenScrolling() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}

private struct TreasureShopButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Sound.shared.play(.coin, volume: 0.6)
            Sound.shared.tap()
            action()
        } label: {
            HStack(spacing: -14) {
                CoinCounter(height: 64)
                ZStack {
                    Circle()
                        .fill(Theme.pink)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(.white, lineWidth: 3.5))
                .shadow(color: Theme.ink.opacity(0.24), radius: 5, y: 3)
            }
        }
        .buttonStyle(Squish())
        .accessibilityLabel("Treasure Shop")
    }
}

private struct Title: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles").foregroundStyle(Theme.lemon)
            Text("Glimmie")
                .foregroundStyle(Theme.ink)
            Image(systemName: "sparkles").foregroundStyle(Theme.lemon)
        }
        .font(.system(size: 40, weight: .heavy, design: .rounded))
        .shadow(color: .white, radius: 0, x: 0, y: 3)
    }
}

private struct GameTile: View {
    let game: GameEntry
    /// Width and height of the square picture, in points.
    let size: CGFloat
    let tap: () -> Void
    @State private var bob = false

    /// Game icons are drawn for a 300 pt tile, so the picture is built at that size and scaled.
    private static let designSize: CGFloat = 300

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 56, style: .continuous)
                        .fill(game.tint.gradient)
                    game.icon()
                        .padding(26)
                }
                .frame(width: Self.designSize, height: Self.designSize)
                .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 56, style: .continuous).stroke(.white, lineWidth: 10))
                .scaleEffect(size / Self.designSize)
                .frame(width: size, height: size)
                .shadow(color: Theme.ink.opacity(0.22), radius: 12, y: 8)
                .offset(y: bob ? -3 : 2)

                Text(game.title)
                    .font(.system(size: min(28, max(20, size * 0.12)), weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: size + DrawerLayout.columnSpacing - 4)
            }
        }
        .buttonStyle(Squish())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                .delay(Double(abs(game.id.hashValue % 7)) * 0.15)) { bob = true }
        }
    }
}

/// Soft cream with pastel polka dots.
struct DrawerBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF1F6), Color(hex: 0xF3ECFF)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let colors = [Theme.blush, Color(hex: 0xE4DBFF), Color(hex: 0xD8F3EA), Color(hex: 0xFFF0C4)]
            let step: CGFloat = 70
            var row = 0
            var y: CGFloat = 20
            while y < size.height + step {
                var x: CGFloat = row % 2 == 0 ? 20 : 20 + step / 2
                var i = row
                while x < size.width + step {
                    let r: CGFloat = 9
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(colors[i % colors.count]))
                    x += step
                    i += 1
                }
                y += step * 0.866
                row += 1
            }
        }
        .ignoresSafeArea()
    }
}
