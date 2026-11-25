import SwiftUI

// MARK: - The customer's order
//
// Every customer orders one exact treat: a kind (cake, cupcake, bungeoppang), a flavor, a frosting color
// and one topping. The order is a picture card that stays on screen the whole time she bakes, so nothing
// has to be remembered. Each part of the card gets a green tick as soon as the treat matches it, the
// matching choices in the kitchen wear a little heart badge, and when she serves it the customer gives
// 1 to 3 stars. It stays gentle: every treat is eaten happily and earns at least one star.

struct BakeryOrder: Equatable {
    var customer: Int
    var kind: TreatKind
    var flavor: Int
    var frosting: Int
    var cone: String
    var topping: String

    /// Toppings a customer may ask for: big, easy-to-tell-apart pictures.
    static let toppings = ["top_strawberry", "top_cherry", "top_heart", "top_star", "top_banana", "top_blueberry",
                           "top_flower", "top_macaron", "top_donut", "top_candle", "top_crown", "top_butterfly",
                           "top_cookie", "top_kiwi", "top_orange", "top_rainbow"]

    /// The four parts of an order, in the order they're shown on the card.
    enum Part: CaseIterable { case kind, flavor, color, topping }

    static func random(customer: Int, seed: Int = Int.random(in: 0..<1_000_000)) -> BakeryOrder {
        var r = SeededRandom(seed)
        let kinds = TreatKind.kitchenCases
        let kind = kinds[r.int(kinds.count)]
        // frosting colors 0 and 1 are white and cream: hard to tell apart on a white card, so orders skip them
        return BakeryOrder(customer: customer, kind: kind,
                           flavor: r.int(BakeryPalette.flavors.count),
                           frosting: 2 + r.int(BakeryPalette.frostings.count - 2),
                           cone: BakeryPalette.cones[r.int(BakeryPalette.cones.count)],
                           topping: toppings[r.int(toppings.count)])
    }

    var customerName: String { BakeryPalette.customers[max(0, min(BakeryPalette.customers.count - 1, customer))] }

    /// Does the treat match this part of the order?
    func matches(_ p: Part, _ t: Treat) -> Bool {
        switch p {
        case .kind: return t.kind == kind
        case .flavor: return t.kind == .iceCream ? t.scoops.contains(flavor) : t.flavor == flavor
        case .color:
            if t.kind == .iceCream { return t.cone == cone }
            if t.kind == .cupcake && t.frostStage == 0 { return false }
            return t.frosting == frosting
        case .topping: return t.toppings.contains { $0.sprite == topping }
        }
    }

    func matchCount(_ t: Treat) -> Int { Part.allCases.filter { matches($0, t) }.count }

    /// Gentle stars: 3 for the exact order, 2 for most of it, and always at least 1.
    func stars(for t: Treat) -> Int {
        let n = matchCount(t)
        return n == 4 ? 3 : n >= 2 ? 2 : 1
    }

    /// The treat the customer dreams of (the picture in the wish bubble).
    var picture: Treat {
        var t = Treat(kind: kind)
        t.flavor = flavor
        t.frosting = frosting
        t.liner = (flavor + 3) % BakeryPalette.liners.count
        switch kind {
        case .cake:
            t.tiers = 1 + flavor % 2
            if topping == "top_strawberry" { t.freshCreamCrown = true }
            let top = BakeryArt.shared.tiers[t.tiers - 1]
            t.toppings = [PlacedTopping(sprite: topping, x: 300, y: Double(top.t - 26), scale: 1.35)]
        case .cupcake:
            t.frostStyle = BakeryPalette.frostStyles[flavor % BakeryPalette.frostStyles.count]
            t.frostStage = 3
            t.toppings = [PlacedTopping(sprite: topping, x: 300, y: 200, scale: 1.25)]
        case .bungeoppang:
            t.filling = flavor % BungeoppangFilling.allCases.count
            t.toppings = [PlacedTopping(sprite: topping, x: 300, y: 315, scale: 1.2)]
        case .iceCream:
            t.cone = cone
            t.scoops = [flavor, flavor]
            let top = BakeryArt.shared.scoopY0 - BakeryArt.shared.scoopDY
            t.toppings = [PlacedTopping(sprite: topping, x: 300, y: Double(top - 92), scale: 1.25)]
        }
        return t
    }
}

// MARK: - Passing the order down to every kitchen step

private struct BakeryOrderKey: EnvironmentKey {
    static let defaultValue: BakeryOrder? = nil
}

extension EnvironmentValues {
    /// The order being made, so pickers can badge the choice the customer wants.
    var bakeryOrder: BakeryOrder? {
        get { self[BakeryOrderKey.self] }
        set { self[BakeryOrderKey.self] = newValue }
    }
}

/// A little heart badge on the choice the customer asked for.
struct WantedBadge: ViewModifier {
    let on: Bool
    var size: CGFloat = 34
    var out: CGFloat = 6
    @State private var bob = false

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if on {
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color(hex: 0xF45C9A)))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 2)
                    .scaleEffect(bob ? 1.12 : 0.92)
                    .offset(x: out, y: -out)
                    .allowsHitTesting(false)
                    .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { bob = true } }
                    .transition(.scale)
            }
        }
    }
}

extension View {
    func wanted(_ on: Bool, size: CGFloat = 34, out: CGFloat = 6) -> some View { modifier(WantedBadge(on: on, size: size, out: out)) }
}

// MARK: - The order card

/// One picture per part of the order, each ticked once the treat matches it.
struct OrderParts: View {
    let order: BakeryOrder
    /// The treat to tick against (nil: no ticks yet).
    var treat: Treat?
    /// Parts that are known to be chosen (a flavor isn't "chosen" before she picks one).
    var known: Set<BakeryOrder.Part> = Set(BakeryOrder.Part.allCases)
    var item: CGFloat = 66

    var body: some View {
        HStack(spacing: item * 0.16) {
            ForEach(BakeryOrder.Part.allCases, id: \.self) { p in
                picture(p)
                    .frame(width: item, height: item)
                    .background(Circle().fill(Color(hex: 0xFFF7F2)))
                    .overlay(Circle().stroke(ticked(p) ? Color(hex: 0x6CCB8B) : Theme.blush, lineWidth: ticked(p) ? 5 : 3))
                    .overlay(alignment: .bottomTrailing) {
                        if ticked(p) {
                            Image(systemName: "checkmark")
                                .font(.system(size: item * 0.24, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: item * 0.42, height: item * 0.42)
                                .background(Circle().fill(Color(hex: 0x4FBF72)))
                                .overlay(Circle().stroke(.white, lineWidth: 3))
                                .offset(x: 6, y: 4)
                                .transition(.scale(scale: 0.2).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: ticked(p))
            }
        }
    }

    private func ticked(_ p: BakeryOrder.Part) -> Bool {
        guard let t = treat, known.contains(p) else { return false }
        return order.matches(p, t)
    }

    @ViewBuilder private func picture(_ p: BakeryOrder.Part) -> some View {
        switch p {
        case .kind:
            let seed = order.kind == .cake ? 4 : order.kind == .cupcake ? 7 : order.kind == .bungeoppang ? 9 : 12
            TreatView(treat: Treat.sample(order.kind, seed: seed), plate: false)
                .padding(item * 0.1)
        case .flavor:
            FlavorJar(sprite: order.kind == .iceCream ? "tub" : "bottle", flavor: order.flavor)
                .padding(item * 0.08)
        case .color:
            if order.kind == .iceCream {
                Sprite("cone_\(order.cone)", color: TreatPainter.liner(0), box: CGRect(x: 180, y: 386, width: 240, height: 214))
                    .padding(item * 0.12)
            } else {
                Sprite("top_cream", color: BakeryPalette.frostings[order.frosting], box: Box.topping)
                    .padding(item * 0.12)
            }
        case .topping:
            Sprite(order.topping, color: BakeryPalette.candy[0], box: Box.topping)
                .padding(item * 0.12)
        }
    }
}

/// The order ticket pinned in the kitchen: who ordered, and the four parts with their ticks.
struct OrderCard: View {
    let order: BakeryOrder
    let treat: Treat
    var known: Set<BakeryOrder.Part> = Set(BakeryOrder.Part.allCases)

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Sprite("cust_\(order.customerName)", box: Box.customer)
                Sprite("eyes_open", box: Box.customer)
                Sprite("mouth_smile", box: Box.customer)
            }
            .frame(width: 70, height: 77)
            OrderParts(order: order, treat: treat, known: known, item: 62)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.pink, lineWidth: 5))
        .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
        .allowsHitTesting(false)
    }
}

/// Three stars that pop in one after another; `filled` of them shine.
struct StarRating: View {
    let filled: Int
    var size: CGFloat = 76
    @State private var shown = 0

    var body: some View {
        HStack(spacing: size * 0.12) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(i < filled ? Color(hex: 0xFFC94A) : Color(hex: 0xEDE4F0))
                    .overlay(
                        Image(systemName: "star")
                            .font(.system(size: size, weight: .black))
                            .foregroundStyle(i < filled ? Color(hex: 0xE89A1E) : Color(hex: 0xCDBFD6))
                    )
                    .shadow(color: Theme.ink.opacity(0.25), radius: 4, y: 3)
                    .rotationEffect(.degrees(i == 0 ? -12 : i == 2 ? 12 : 0))
                    .offset(y: i == 1 ? -size * 0.18 : 0)
                    .scaleEffect(i < shown ? 1 : 0.1)
                    .opacity(i < shown ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(i) * 0.32) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) { shown = i + 1 }
                    if i < filled {
                        Sound.shared.play(i == 2 ? .ding : .sparkle, volume: 0.8)
                        Sound.shared.tap()
                    } else {
                        Sound.shared.play(.pop, volume: 0.4)
                    }
                }
            }
        }
    }
}
