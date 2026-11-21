import SwiftUI

// MARK: - The treasure shop
//
// Opened from the coin purse on the home screen. Each extra sits on a shelf with its price on a tag (a coin and a
// number) and the game it goes to as a little tile in its corner. Tap one she can afford and the till rings, the
// coins leave the purse and it gets a green tick: it's now in that game's tray. One she can't afford yet just
// wiggles its tag. Bought ones stay ticked. Nothing to read.

struct TreasureShopView: View {
    let close: () -> Void
    @State private var shown = false
    @State private var poke: [String: Date] = [:]
    @State private var bought: [String: Date] = [:]
    /// Redraws after a purchase (Coins isn't observable).
    @State private var tick = 0

    private let columns = 3
    private var cellHeight: CGFloat {
        let rows = max(1, (Treasures.all.count + columns - 1) / columns)
        return min(248, (526 - CGFloat(rows - 1) * 20) / CGFloat(rows))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: shut)
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.pink)
                    Spacer()
                    CoinCounter(game: "shop", height: 72)
                }
                .padding(.horizontal, 34)
                .padding(.top, 26)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columns), spacing: 20) {
                    ForEach(Treasures.all) { item in
                        cell(item)
                    }
                }
                .padding(.horizontal, 34)
                Spacer(minLength: 0)
            }
            .id(tick)
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
                .offset(x: 18, y: -18)
            }
            .scaleEffect(shown ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { shown = true }
        }
    }

    private func shut() {
        Sound.shared.play(.whoosh, volume: 0.5)
        close()
    }

    private func tap(_ item: Treasure) {
        let coins = Coins.shared
        Sound.shared.tap()
        if coins.owns(item.id) {
            Sound.shared.play(.pop, volume: 0.6)
            poke[item.id] = Date()
        } else if coins.buy(item.id, price: item.price) {
            Sound.shared.play(.fanfare, volume: 0.55)
            bought[item.id] = Date()
            tick += 1
        } else {
            // not enough coins yet: the price tag wiggles
            Sound.shared.play(.tap, volume: 0.5)
            poke[item.id] = Date()
        }
    }

    private func cell(_ item: Treasure) -> some View {
        let owned = item.owned
        let afford = Coins.shared.canAfford(item.price)
        return Button { tap(item) } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
                let a = poke[item.id].map { tl.date.timeIntervalSince($0) } ?? 10
                let jig = a < 0.6 ? sin(a * 30) * 0.15 * (1 - a / 0.6) : 0
                let b = bought[item.id].map { tl.date.timeIntervalSince($0) } ?? 10
                let pop = b < 0.5 ? 0.18 * sin(b / 0.5 * .pi) : 0
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(owned ? Theme.mint : (afford ? Color(hex: 0xFFD45A) : Theme.blush), lineWidth: 5))
                        .shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 4)
                    TreasureArtView(item: item)
                        .padding(.horizontal, 26)
                        .padding(.top, 18)
                        .padding(.bottom, 52)
                        .rotationEffect(.radians(owned ? jig : 0))
                    if b < 1 { SparkleBurst(colors: [Theme.lemon, Theme.pink, .white], count: 14, radius: 120) }
                    // which game it goes to
                    if let g = GameRegistry.all.first(where: { $0.id == item.game }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(g.tint.gradient)
                            g.icon().padding(5)
                        }
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white, lineWidth: 3))
                        .shadow(color: Theme.ink.opacity(0.2), radius: 3, y: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(10)
                    }
                    // the price tag, or a tick once it's hers
                    Group {
                        if owned {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 46, weight: .bold))
                                .foregroundStyle(.white, Color(hex: 0x3CC48A))
                                .shadow(color: Theme.ink.opacity(0.2), radius: 2, y: 1)
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
