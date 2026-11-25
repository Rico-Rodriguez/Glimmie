import SwiftUI

// MARK: - Play coins
//
// One coin purse for the whole app. Shop customers pay her in play coins when she serves them (Bakery, Ice Cream,
// Pizza, and any new shop), and she spends them in the treasure shop on the home screen on extras. Coins only
// ever add things: every tray, tool and item that was free stays free, nothing is locked behind coins, nothing is
// bought with real money, and there are no timers. Nothing to read: the coins themselves fly into the purse.
//
// How a game uses it:
//   • Pay her: `Coins.shared.earn(Coins.reward(stars: s), game: "bakery", from: customerPoint)`
//     `from` is in the game's 1024 x 834 design space (where the customer stands); the coins hop out of there.
//   • Show the purse: put `CoinCounter(game: "bakery")` in the game's top bar, and add `.coinPurse(game: "bakery")`
//     to the 1024 x 834 view that holds both the customer and the counter. The coins then fly from the customer
//     into the counter with a chime each, and the count goes up as each one lands.
//   • Buying (the treasure shop, or a new game's own shop): `Coins.shared.buy("game/item", price: 12)` returns
//     false when she hasn't enough; `Coins.shared.owns("game/item")` tells a game to show a bought extra.
//
// Saves live in their own folder (`coins`), so a game never touches another game's saves.

final class Coins: ObservableObject {
    static let shared = Coins()
    static let folder = "coins"

    private struct Save: Codable {
        var balance: Int
        var owned: [String]
        var earned: Int
    }

    /// One payment on its way to the purse (for the flying coins).
    struct Payment {
        let game: String
        let amount: Int
        /// Where the coins hop out from, in the game's 1024 x 834 design space.
        let from: CGPoint
        let at: Date
    }

    /// Coins in the purse right now (including any still flying in).
    @Published private(set) var balance: Int
    /// Ids ("<game>/<item>") of the extras she has bought.
    @Published private(set) var owned: Set<String>
    /// Every coin she has ever been paid.
    @Published private(set) var earned: Int
    /// The latest payment, for the coins that fly into the counter.
    @Published private(set) var lastPay: Payment?
    @Published private(set) var isAnimatingPayment = false
    /// Screenshots and demos don't keep their coins.
    var demo = false

    private var settleWorkItem: DispatchWorkItem?

    private init() {
        let s = GameStorage.load(Save.self, game: Coins.folder, file: "purse.json")
        balance = s?.balance ?? 0
        let savedItems = Set(s?.owned ?? [])
        owned = savedItems.filter { !GameStorage.isRetiredGameRecord($0) }
        earned = s?.earned ?? 0
        demo = ProcessInfo.processInfo.arguments.contains("-coinsDemo")
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-coinsDemo"),
           i + 1 < ProcessInfo.processInfo.arguments.count,
           let n = Int(ProcessInfo.processInfo.arguments[i + 1]) {
            balance = n
        }
        if owned != savedItems { save() }
    }

    /// A shop's pay for one served order: every customer pays, a happier one pays a little more (3 to 5 coins).
    static func reward(stars: Int) -> Int { 2 + max(1, min(3, stars)) }

    // MARK: Earning

    /// The flight of one coin: hops out at `hop(i)` seconds after the payment and lands in the purse at `land(i)`.
    static func hop(_ i: Int) -> Double { Double(i) * 0.16 }
    static let flight = 0.75
    static let bumpDuration = 0.3
    static func land(_ i: Int) -> Double { hop(i) + flight }

    static func showerDuration(amount: Int) -> Double {
        guard amount > 0 else { return 0 }
        return land(amount - 1) + 0.1
    }

    static func counterDuration(amount: Int) -> Double {
        guard amount > 0 else { return 0 }
        return land(amount - 1) + bumpDuration + 0.05
    }

    /// She was paid `n` coins in `game`. The coins hop out of `from` and fly into that game's `CoinCounter`.
    func earn(_ n: Int, game: String, from: CGPoint = CGPoint(x: 512, y: 400)) {
        guard n > 0 else { return }
        balance += n
        earned += n
        let payment = Payment(game: game, amount: n, from: from, at: Date())
        lastPay = payment
        isAnimatingPayment = true
        settleWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.lastPay?.at == payment.at else { return }
            self.isAnimatingPayment = false
        }
        settleWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Coins.counterDuration(amount: n), execute: work)
        Sound.shared.play(.till, volume: 0.55)
        for i in 0..<n {
            DispatchQueue.main.asyncAfter(deadline: .now() + Coins.land(i)) {
                Sound.shared.play(.coin, volume: 0.6)
                if i == n - 1 { Sound.shared.tap() }
            }
        }
        save()
    }

    /// Defers `earn(_:game:from:)` to the next main run-loop turn for callers running inside SwiftUI render passes.
    func earnDeferred(_ n: Int, game: String, from: CGPoint = CGPoint(x: 512, y: 400)) {
        guard n > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.earn(n, game: game, from: from)
        }
    }

    /// Coins still in the air for this game (the counter shows them only once they land).
    func flying(game: String?, at now: Date = Date()) -> Int {
        guard let p = lastPay, p.game == game || game == nil else { return 0 }
        let a = now.timeIntervalSince(p.at)
        guard a >= 0 else { return 0 }
        return (0..<p.amount).filter { a < Coins.land($0) }.count
    }

    func isAnimating(game: String?, at now: Date = Date()) -> Bool {
        guard isAnimatingPayment, let p = lastPay, game == nil || p.game == game else { return false }
        let a = now.timeIntervalSince(p.at)
        return a >= 0 && a < Coins.counterDuration(amount: p.amount)
    }

    func isShowerAnimating(game: String, at now: Date = Date()) -> Bool {
        guard isAnimatingPayment, let p = lastPay, p.game == game else { return false }
        let a = now.timeIntervalSince(p.at)
        return a >= 0 && a < Coins.showerDuration(amount: p.amount)
    }

    // MARK: Spending

    func owns(_ id: String) -> Bool { owned.contains(id) }

    func canAfford(_ price: Int) -> Bool { balance >= price }

    /// Buys an extra once. Returns true if she has it now (bought just now or before), false if she hasn't enough.
    @discardableResult
    func buy(_ id: String, price: Int) -> Bool {
        if owned.contains(id) { return true }
        guard spend(price) else { return false }
        owned.insert(id)
        save()
        return true
    }

    /// Takes coins out of the purse (for things a game uses up). False, and nothing taken, if she hasn't enough.
    @discardableResult
    func spend(_ price: Int) -> Bool {
        guard price >= 0, balance >= price else { return false }
        balance -= price
        Sound.shared.play(.till, volume: 0.6)
        save()
        return true
    }

    private func save() {
        guard !demo else { return }
        GameStorage.saveAsync(Save(balance: balance, owned: owned.sorted(), earned: earned), game: Coins.folder, file: "purse.json")
    }

    #if DEBUG
    /// Tests only: an empty purse that never saves.
    func resetForTests(balance: Int = 0) {
        settleWorkItem?.cancel()
        settleWorkItem = nil
        isAnimatingPayment = false
        demo = true
        self.balance = balance
        owned = []
        earned = 0
        lastPay = nil
    }
    #endif
}

// MARK: - One coin

/// A gold play coin with a star on it, drawn to fill its frame.
struct CoinIcon: View {
    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(Color(hex: 0xE9A81E))
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFF1A6), Color(hex: 0xFFCF3A)],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: d * 0.6))
                    .padding(d * 0.09)
                Image(systemName: "star.fill")
                    .font(.system(size: d * 0.42, weight: .black))
                    .foregroundStyle(Color(hex: 0xF2B526))
                    .shadow(color: .white.opacity(0.8), radius: 0, x: -d * 0.02, y: -d * 0.02)
            }
            .frame(width: d, height: d)
            .frame(width: g.size.width, height: g.size.height)
        }
        .shadow(color: Color(hex: 0x9A6A00).opacity(0.35), radius: 1.5, y: 1.5)
    }
}

// MARK: - The purse in a game's top bar

/// A white pill with a coin and how many coins she has. It bounces each time a flying coin lands in it.
struct CoinCounter: View {
    /// The game it sits in (its payments fly into it); nil on the home screen.
    var game: String?
    var height: CGFloat = 72
    /// Tap to open the treasure shop (home screen); nil in games.
    var action: (() -> Void)?
    @ObservedObject private var coins = Coins.shared

    init(game: String? = nil, height: CGFloat = 72, action: (() -> Void)? = nil) {
        self.game = game
        self.height = height
        self.action = action
    }

    var body: some View {
        let animating = coins.isAnimating(game: game)
        let pill = TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animating)) { tl in
            let shown = coins.balance - (animating ? coins.flying(game: game, at: tl.date) : 0)
            let bump = animating ? landBump(tl.date) : 0
            HStack(spacing: height * 0.12) {
                CoinIcon()
                    .frame(width: height * 0.72, height: height * 0.72)
                    .rotation3DEffect(.degrees(bump * 180), axis: (x: 0, y: 1, z: 0))
                Text("\(shown)")
                    .font(.system(size: height * 0.42, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: 0xB9770E))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.leading, height * 0.12)
            .padding(.trailing, height * 0.3)
            .frame(height: height)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(Color(hex: 0xFFD45A), lineWidth: 5))
            .shadow(color: Theme.ink.opacity(0.22), radius: 6, y: 4)
            .scaleEffect(1 + 0.18 * CGFloat(sin(bump * .pi)))
        }
        .background(
            GeometryReader { g in
                Color.clear.preference(key: CoinTargetKey.self,
                                       value: CGPoint(x: g.frame(in: .named(CoinSpace.name)).minX + height * 0.48,
                                                      y: g.frame(in: .named(CoinSpace.name)).midY))
            }
        )
        if let action {
            Button {
                Sound.shared.play(.coin, volume: 0.6)
                Sound.shared.tap()
                action()
            } label: { pill }
            .buttonStyle(Squish())
        } else {
            pill.allowsHitTesting(false)
        }
    }

    /// 0...1 over the 0.3 s after each coin of this game's latest payment lands.
    private func landBump(_ now: Date) -> Double {
        guard let p = coins.lastPay, game == nil || p.game == game else { return 0 }
        let a = now.timeIntervalSince(p.at)
        for i in 0..<p.amount {
            let k = (a - Coins.land(i)) / Coins.bumpDuration
            if k >= 0 && k < 1 { return k }
        }
        return 0
    }
}

enum CoinSpace { static let name = "coins" }

struct CoinTargetKey: PreferenceKey {
    static var defaultValue: CGPoint? = nil
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        if let n = nextValue() { value = n }
    }
}

extension View {
    /// Put on the 1024 x 834 view that holds a game's customer and its `CoinCounter`: coins she earns in `game`
    /// hop out of the customer and fly into the counter.
    func coinPurse(game: String) -> some View { modifier(CoinShowerLayer(game: game)) }
}

private struct CoinShowerLayer: ViewModifier {
    let game: String
    @State private var target = CGPoint(x: 880, y: 60)

    func body(content: Content) -> some View {
        content
            .overlay(CoinShower(game: game, target: target).allowsHitTesting(false))
            .coordinateSpace(name: CoinSpace.name)
            .onPreferenceChange(CoinTargetKey.self) { p in
                if let p { target = p }
            }
    }
}

// MARK: - Coins flying into the purse

/// The coins of the latest payment in `game`: each pops out of the customer with a little spin, arcs up and
/// lands in the counter at `target`.
struct CoinShower: View {
    let game: String
    let target: CGPoint
    @ObservedObject private var coins = Coins.shared

    init(game: String, target: CGPoint) {
        self.game = game
        self.target = target
    }

    var body: some View {
        let animating = coins.isShowerAnimating(game: game)
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !animating)) { tl in
            ZStack {
                if animating, let p = coins.lastPay, p.game == game {
                    let a = tl.date.timeIntervalSince(p.at)
                    if a >= 0 && a < Coins.showerDuration(amount: p.amount) {
                        ForEach(0..<p.amount, id: \.self) { i in
                            coin(i, of: p, age: a)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private func coin(_ i: Int, of p: Payment, age a: Double) -> some View {
        let u = (a - Coins.hop(i)) / Coins.flight
        if u >= 0 && u < 1 {
            let e = CGFloat(u * u * (3 - 2 * u))
            // a little fan of coins: each starts a bit to the side of the customer's paw
            let side = CGFloat(i - (p.amount - 1) / 2) * 26
            let sx = p.from.x + side, sy = p.from.y
            let x = sx + (target.x - sx) * e
            let y = sy + (target.y - sy) * e - 170 * sin(e * .pi)
            let pop = CGFloat(min(1, u / 0.15))
            CoinIcon()
                .frame(width: 54, height: 54)
                .rotation3DEffect(.degrees(u * 720), axis: (x: 0, y: 1, z: 0))
                .scaleEffect(pop * (1.15 - 0.45 * e))
                .position(x: x, y: y)
        }
    }

    typealias Payment = Coins.Payment
}
