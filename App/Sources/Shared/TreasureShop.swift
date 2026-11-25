import SwiftUI

// MARK: - The treasure shop
//
// Opened from the coin purse on the home screen. Each extra sits on a shelf with its price on a tag (a coin and a
// number) and the game it goes to as a little tile in its corner. A pictorial row of game tiles at the top filters
// the shelf (or shows all 30). Tap one she can afford and the till rings, the coins leave the purse and it gets a
// green tick. One she can't afford yet just wiggles its tag. Bought ones stay ticked. Nothing to read.

struct TreasureShopView: View {
    private enum ShopFilter: Hashable {
        case all
        case game(String)
    }

    let close: () -> Void
    @State private var shown = false
    @State private var filter: ShopFilter = .all
    @State private var poke: [String: Date] = [:]
    @State private var bought: [String: Date] = [:]
    @State private var ownedIDs: Set<String> = Coins.shared.owned
    @State private var balance: Int = Coins.shared.balance

    private let columns = 3
    private let cellHeight: CGFloat = 204
    private static let gamesByID = Dictionary(uniqueKeysWithValues: GameRegistry.all.map { ($0.id, $0) })

    private var displayedTreasures: [Treasure] {
        switch filter {
        case .all:
            return Treasures.all
        case .game(let id):
            return Treasures.items(for: id)
        }
    }

    private func hasUnbought(for gameID: String) -> Bool {
        Treasures.items(for: gameID).contains { !ownedIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: shut)
            DesignCanvas {
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(Theme.pink)
                        Spacer()
                        CoinCounter(game: "shop", height: 64)
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 22)

                    filterStrip

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            Color.clear
                                .frame(height: 0)
                                .id("shelf-top")
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columns),
                                spacing: 18
                            ) {
                                ForEach(displayedTreasures) { item in
                                    cell(item)
                                }
                            }
                            .padding(.horizontal, 34)
                            .padding(.top, 6)
                            .padding(.bottom, 24)
                        }
                        .onChange(of: filter) { _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("shelf-top", anchor: .top)
                            }
                        }
                    }
                }
                .frame(width: 900, height: 660)
                .background(
                    LinearGradient(colors: [Color(hex: 0xFFF6E0), Theme.cream], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                .shadow(color: Theme.ink.opacity(0.35), radius: 20, y: 10)
                .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous).stroke(.white, lineWidth: 8))
                .overlay(alignment: .topTrailing) {
                    Button(action: shut) {
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 66, height: 66)
                            .background(Circle().fill(Theme.pink))
                            .overlay(Circle().stroke(.white, lineWidth: 5))
                            .shadow(color: Theme.ink.opacity(0.25), radius: 5, y: 3)
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel("Close")
                    .offset(x: 18, y: -18)
                }
                .scaleEffect(shown ? 1 : 0.85)
                .opacity(shown ? 1 : 0)
            }
        }
        .onAppear {
            ownedIDs = Coins.shared.owned
            balance = Coins.shared.balance
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { shown = true }
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 11) {
                allFilterPill
                ForEach(GameRegistry.all) { game in
                    gameFilterPill(game)
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 8)
        }
    }

    private var allFilterPill: some View {
        let selected = filter == .all
        return Button {
            select(.all)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFFA2CA), Color(hex: 0xFFDF76)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.18), radius: 2, y: 1)
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white, lineWidth: selected ? 4 : 3)
            )
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(Color(hex: 0xFF7CA8), lineWidth: 4)
                        .padding(-4)
                }
            }
            .shadow(color: Theme.ink.opacity(selected ? 0.28 : 0.16), radius: selected ? 6 : 3, y: selected ? 3 : 2)
            .scaleEffect(selected ? 1.07 : 0.96)
            .opacity(selected ? 1 : 0.88)
        }
        .buttonStyle(Squish())
        .accessibilityLabel("All")
    }

    private func gameFilterPill(_ game: GameEntry) -> some View {
        let selected = filter == .game(game.id)
        let unbought = hasUnbought(for: game.id)
        return Button {
            select(.game(game.id))
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(game.tint.gradient)
                game.icon()
                    .padding(5)
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white, lineWidth: selected ? 4 : 3)
            )
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(Color(hex: 0xFF7CA8), lineWidth: 4)
                        .padding(-4)
                }
            }
            .overlay(alignment: .topTrailing) {
                if unbought {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xFFD45A), Theme.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 15, height: 15)
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .shadow(color: Theme.ink.opacity(0.2), radius: 2, y: 1)
                        .offset(x: 4, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: Theme.ink.opacity(selected ? 0.28 : 0.16), radius: selected ? 6 : 3, y: selected ? 3 : 2)
            .scaleEffect(selected ? 1.07 : 0.96)
            .opacity(selected ? 1 : 0.88)
        }
        .buttonStyle(Squish())
        .accessibilityLabel(game.title)
    }

    private func select(_ next: ShopFilter) {
        Sound.shared.tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            filter = next
        }
    }

    private func shut() {
        Sound.shared.play(.whoosh, volume: 0.5)
        close()
    }

    private func triggerPoke(_ id: String) {
        let now = Date()
        poke[id] = now
        // Remove after the 0.6s wiggle settles so the cell's TimelineView returns to 0Hz.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if poke[id] == now { poke.removeValue(forKey: id) }
        }
    }

    private func triggerBought(_ id: String) {
        let now = Date()
        bought[id] = now
        // Remove after the 0.5s pop + 0.8s SparkleBurst finish so the TimelineView returns to 0Hz.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if bought[id] == now { bought.removeValue(forKey: id) }
        }
    }

    private func tap(_ item: Treasure) {
        let coins = Coins.shared
        Sound.shared.tap()
        if ownedIDs.contains(item.id) || coins.owns(item.id) {
            Sound.shared.play(.pop, volume: 0.6)
            triggerPoke(item.id)
        } else if coins.buy(item.id, price: item.price) {
            Sound.shared.play(.fanfare, volume: 0.55)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) {
                ownedIDs.insert(item.id)
                balance = coins.balance
            }
            triggerBought(item.id)
        } else {
            // not enough coins yet: the price tag wiggles
            Sound.shared.play(.tap, volume: 0.5)
            triggerPoke(item.id)
        }
    }

    private func cell(_ item: Treasure) -> some View {
        let owned = ownedIDs.contains(item.id)
        let afford = balance >= item.price
        let animating = poke[item.id] != nil || bought[item.id] != nil
        let gameEntry = Self.gamesByID[item.game]
        return Button { tap(item) } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !animating)) { tl in
                let a = poke[item.id].map { tl.date.timeIntervalSince($0) } ?? 10
                let jig = a < 0.6 ? sin(a * 30) * 0.15 * (1 - a / 0.6) : 0
                let b = bought[item.id].map { tl.date.timeIntervalSince($0) } ?? 10
                let pop = b < 0.5 ? 0.18 * sin(b / 0.5 * .pi) : 0
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(owned ? Theme.mint : (afford ? Color(hex: 0xFFD45A) : Theme.blush), lineWidth: 5)
                        )
                        .shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 4)
                    TreasureArtView(item: item)
                        .padding(.horizontal, 26)
                        .padding(.top, 16)
                        .padding(.bottom, 50)
                        .rotationEffect(.radians(owned ? jig : 0))
                    if b < 1 { SparkleBurst(colors: [Theme.lemon, Theme.pink, .white], count: 14, radius: 120) }
                    if let g = gameEntry {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(g.tint.gradient)
                            g.icon().padding(5)
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white, lineWidth: 3))
                        .shadow(color: Theme.ink.opacity(0.2), radius: 3, y: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(10)
                    }
                    Group {
                        if owned {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 46, weight: .bold))
                                .foregroundStyle(.white, Color(hex: 0x3CC48A))
                                .shadow(color: Theme.ink.opacity(0.2), radius: 2, y: 1)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            HStack(spacing: 6) {
                                CoinIcon().frame(width: 34, height: 34)
                                Text("\(item.price)")
                                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color(hex: 0xB9770E))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Capsule().fill(afford ? Color(hex: 0xFFF3C4) : Color(hex: 0xF4EEF6)))
                            .overlay(Capsule().stroke(afford ? Color(hex: 0xFFD45A) : Theme.ink.opacity(0.12), lineWidth: 3))
                            .rotationEffect(.radians(owned ? 0 : jig))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 10)
                }
                .frame(height: cellHeight)
                .scaleEffect(CGFloat(1 + pop))
            }
        }
        .buttonStyle(Squish())
    }
}
