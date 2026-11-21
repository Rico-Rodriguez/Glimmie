import SwiftUI

// MARK: - Bakery (a game in the drawer)
//
// A sweet shop. Cute animal customers come to the counter dreaming of a treat. She bakes cakes and
// cupcakes (add the ingredients, pick a flavor, stir, pour, bake, frost) or builds ice cream (cone,
// scoops, sauce), decorates it with 37 toppings and five kinds of sprinkles, then serves it and the
// customer gobbles it up. Every flavor, color and topping is open. No voice, no words to read.
//
// Art: tools/bakery/build.py -> App/Resources/Games/Bakery/bakery.json. Sounds: tools/bakery/sounds.py.

enum BakeryGame {
    static let entry = GameEntry(
        id: "bakery",
        title: "Bakery",
        tint: Color(hex: 0xFFC09F),
        icon: { AnyView(TreatView(treat: .tile, plate: false, box: CGRect(x: 150, y: 150, width: 300, height: 395))) },
        play: { exit in AnyView(BakeryGameView(exit: exit)) }
    )
}

struct BakeryGameView: View {
    let exit: () -> Void
    @StateObject private var store = BakeryStore()
    @State private var making: Treat?
    @State private var ready: Treat?
    @State private var startStep = 0
    @State private var order = BakeryOrder.random(customer: Int.random(in: 0..<BakeryPalette.customers.count))

    var body: some View {
        ZStack {
            if let t = making {
                KitchenView(treat: Binding(get: { making ?? t }, set: { making = $0 }), order: order, startStep: startStep,
                            onDone: { finished in
                                withAnimation(.easeInOut(duration: 0.35)) { ready = finished; making = nil }
                            },
                            onShop: { withAnimation(.easeInOut(duration: 0.35)) { making = nil } })
                    .transition(.opacity)
            } else {
                ShopView(store: store, ready: $ready, order: $order, exit: exit) { kind in
                    BakerySound.shared.play(.plop)
                    Sound.shared.tap()
                    startStep = 0
                    withAnimation(.easeInOut(duration: 0.35)) { making = Treat(kind: kind) }
                }
                .transition(.opacity)
            }
        }
        .onAppear(perform: applyLaunchArguments)
        .onDisappear { store.save() }
    }

    /// Simulator screenshot hooks: -bakeryDecorate <cake|cupcake|iceCream>, -bakeryServe, -bakeryStep <n>.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.hasPrefix("-bakery") }) { order = BakeryOrder.random(customer: 2, seed: 11) }
        if let i = args.firstIndex(of: "-bakeryDecorate"), i + 1 < args.count, let k = TreatKind(rawValue: args[i + 1]) {
            startStep = 3
            making = Treat.sample(k, seed: 5)
        }
        if let i = args.firstIndex(of: "-bakeryStep"), i + 2 < args.count, let k = TreatKind(rawValue: args[i + 1]), let n = Int(args[i + 2]) {
            startStep = n
            var t = Treat(kind: k)
            if n > 0 { t = Treat.sample(k, seed: 2); t.toppings = []; if k == .cake { t.frosting = nil }; if k == .cupcake { t.frostStage = 0 } }
            making = t
        }
        if args.contains("-bakeryServe") { ready = Treat.sample(.cake, seed: 9) }
        if args.contains("-bakeryRated") {
            // the exact order, served: three stars
            ready = order.picture
            ShopView.demoServe = true
            Coins.shared.demo = true
        }
    }
}

// MARK: - The shop

struct ShopView: View {
    @ObservedObject var store: BakeryStore
    @Binding var ready: Treat?
    @Binding var order: BakeryOrder
    let exit: () -> Void
    let make: (TreatKind) -> Void

    private enum Phase { case arriving, waiting, eating, happy, leaving }
    @State private var phase: Phase = .arriving
    /// The treat just served and its stars (shown while the customer is happy).
    @State private var rated: (treat: Treat, stars: Int)?
    /// Screenshot hook (-bakeryRated): serve the ready treat right away and stay.
    static var demoServe = false

    private var customer: Int { order.customer }
    private var wish: TreatKind { order.kind }
    @State private var custX: CGFloat = 900
    @State private var eyes = "open"
    @State private var mouth = "smile"
    @State private var bob = false
    @State private var bites = 0
    @State private var treatLift = false
    @State private var hearts = 0
    @State private var jarBounce = false
    @State private var showCase = false
    @State private var burst = 0

    var body: some View {
        ZStack {
            ShopBackground()
            DesignCanvas {
                ZStack {
                    customerLayer
                    counterLayer
                    topBar
                }
                .frame(width: 1024, height: 834)
                .coinPurse(game: "bakery")
            }
            if showCase {
                TreatCase(store: store, close: { withAnimation(.spring(response: 0.4)) { showCase = false } }) { t in
                    withAnimation(.spring(response: 0.4)) { showCase = false }
                    if ready == nil && phase == .waiting {
                        BakerySound.shared.play(.magic)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { ready = t }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }
        }
        .onAppear {
            if phase == .arriving { arrive() }
            if ShopView.demoServe { DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { serve() } }
        }
        .task { await blinkLoop() }
    }

    // MARK: Layers

    private var customerLayer: some View {
        ZStack {
            // the wish bubble: the exact treat they want, and under it the four parts of the order
            if phase == .waiting || phase == .happy {
                ZStack {
                    Sprite("thought", box: Box.thought)
                    if phase == .happy, let r = rated {
                        StarRating(filled: r.stars, size: 62)
                            .offset(x: 22, y: -30)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        TreatView(treat: order.picture, plate: false)
                            .frame(width: 180, height: 180)
                            .offset(x: 24, y: -28)
                    }
                }
                .frame(width: 300, height: 270)
                .scaleEffect(bob ? 1.04 : 0.97)
                .position(x: 720, y: 230)
                .transition(.scale(scale: 0.3).combined(with: .opacity))
                .onTapGesture { if ready == nil && phase == .waiting { make(wish) } }
                OrderParts(order: order, treat: phase == .happy ? rated?.treat : ready, item: 60)
                    .padding(10)
                    .background(Capsule().fill(.white.opacity(0.92)))
                    .overlay(Capsule().stroke(Theme.blush, lineWidth: 4))
                    .position(x: 790, y: 404)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
            ZStack {
                Sprite("cust_\(BakeryPalette.customers[customer])", box: Box.customer)
                Sprite("eyes_\(eyes)", box: Box.customer)
                Sprite("mouth_\(mouth)", box: Box.customer)
            }
            .frame(width: 400, height: 440)
            .offset(y: bob ? -6 : 4)
            .position(x: 470 + custX, y: 390)
            .onTapGesture { tickle() }
            // floating hearts
            ForEach(0..<hearts, id: \.self) { i in
                FloatingHeart(index: i).position(x: 470, y: 260)
            }
        }
    }

    private var counterLayer: some View {
        ZStack {
            Counter()
                .frame(width: 2400, height: 260)
                .position(x: 512, y: 704)
            if let t = ready {
                ZStack {
                    TreatView(treat: t, bites: bites)
                        .frame(width: 330, height: 330)
                    SparkleBurst(colors: [.white, Theme.lemon, Theme.pink], count: 14, radius: 190).id(burst)
                }
                .scaleEffect(treatLift ? 0.86 : 1)
                .position(x: 470, y: treatLift ? 470 : 520)
                .onTapGesture { serve() }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
                Sprite("bell", box: Box.thing)
                    .frame(width: 120, height: 120)
                    .scaleEffect(bob && phase == .waiting ? 1.12 : 1)
                    .position(x: 750, y: 600)
                    .onTapGesture { serve() }
            } else {
                HStack(spacing: 34) {
                    MakeButton(kind: .cake, wished: wish == .cake && phase == .waiting) { make(.cake) }
                    MakeButton(kind: .cupcake, wished: wish == .cupcake && phase == .waiting) { make(.cupcake) }
                    MakeButton(kind: .iceCream, wished: wish == .iceCream && phase == .waiting) { make(.iceCream) }
                }
                .position(x: 512, y: 710)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            HomeButton { store.save(); exit() }
            Spacer()
            CoinCounter(game: "bakery")
            ZStack(alignment: .bottomTrailing) {
                Sprite("heartjar", box: Box.thing).frame(width: 86, height: 86)
                Text("\(store.hearts)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: 0xF45C9A)))
                    .offset(x: 10, y: 4)
            }
            .scaleEffect(jarBounce ? 1.3 : 1)
            RoundButton(symbol: "square.grid.2x2.fill", tint: Color(hex: 0x46B7B0)) {
                Sound.shared.play(.whoosh)
                withAnimation(.spring(response: 0.4)) { showCase = true }
            }
        }
        .padding(.horizontal, 26)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 22)
    }

    // MARK: Story

    private func arrive() {
        custX = 900
        eyes = "open"; mouth = "smile"; bites = 0; treatLift = false
        BakerySound.shared.play(.doorbell, volume: 0.7)
        withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) { custX = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { phase = .waiting }
            Sound.shared.play(.bubble, volume: 0.6)
        }
    }

    private func tickle() {
        guard phase == .waiting else { return }
        Sound.shared.play(.boing, volume: 0.7)
        Sound.shared.tap()
        eyes = "happy"; mouth = "open"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if phase == .waiting { eyes = "open"; mouth = "smile" }
        }
    }

    private func serve() {
        guard let t = ready, phase == .waiting else { return }
        phase = .eating
        Sound.shared.play(.whoosh, volume: 0.6)
        withAnimation(.easeInOut(duration: 0.4)) { treatLift = true }
        eyes = "happy"; mouth = "open"
        for k in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(k) * 0.55) {
                BakerySound.shared.play(.nom)
                Sound.shared.tap()
                mouth = "chew"
                withAnimation(.easeOut(duration: 0.12)) { bites = k }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { mouth = "open" }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            let stars = order.stars(for: t)
            let matched = stars == 3
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                rated = (t, stars)
                phase = .happy
            }
            eyes = matched ? "star" : "happy"
            mouth = "open"
            store.serve(t, hearts: stars)
            // the customer pays: coins hop out of their paws into the purse
            Coins.shared.earn(Coins.reward(stars: stars), game: "bakery", from: CGPoint(x: 470, y: 360))
            withAnimation(.easeOut(duration: 0.25)) { ready = nil }
            BakerySound.shared.play(.yay)
            Sound.shared.play(matched ? .fanfare : .cheer, volume: 0.7)
            hearts = 2 + stars * 2
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { jarBounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { jarBounce = false }
            }
        }
        if ShopView.demoServe { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) { leave() }
    }

    private func leave() {
        withAnimation(.easeOut(duration: 0.25)) { phase = .leaving }
        hearts = 0
        Sound.shared.play(.whoosh, volume: 0.5)
        withAnimation(.easeIn(duration: 0.6)) { custX = -1000 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            var next = Int.random(in: 0..<BakeryPalette.customers.count)
            if next == customer { next = (next + 1) % BakeryPalette.customers.count }
            order = BakeryOrder.random(customer: next)
            rated = nil
            phase = .arriving
            arrive()
        }
    }

    private func blinkLoop() async {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.2...4.2) * 1_000_000_000))
            if eyes == "open" {
                eyes = "blink"
                try? await Task.sleep(nanoseconds: 140_000_000)
                if eyes == "blink" { eyes = "open" }
            }
        }
    }
}

private struct MakeButton: View {
    let kind: TreatKind
    let wished: Bool
    let tap: () -> Void
    @State private var wiggle = false

    var body: some View {
        Button(action: tap) {
            TreatView(treat: Treat.sample(kind, seed: kind == .cake ? 4 : kind == .cupcake ? 7 : 12), plate: false)
                .padding(12)
                .frame(width: 190, height: 190)
                .background(Circle().fill(.white))
                .overlay(Circle().stroke(wished ? Theme.pink : Theme.blush, lineWidth: wished ? 9 : 6))
                .shadow(color: Theme.ink.opacity(0.22), radius: 8, y: 6)
                .rotationEffect(.degrees(wished && wiggle ? 5 : wished ? -5 : 0))
        }
        .buttonStyle(Squish())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { wiggle = true }
        }
    }
}

private struct FloatingHeart: View {
    let index: Int
    @State private var go = false
    var body: some View {
        let dx = CGFloat((index * 53) % 220) - 110
        Sprite("top_heart", color: BakeryPalette.candy[index % 3], box: Box.topping)
            .frame(width: 70, height: 70)
            .offset(x: go ? dx : 0, y: go ? -260 - CGFloat(index % 3) * 40 : 0)
            .scaleEffect(go ? 1.1 : 0.3)
            .opacity(go ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).delay(Double(index) * 0.12)) { go = true }
            }
    }
}

// MARK: - Backgrounds

struct ShopBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFFF3F7)))
                let w: CGFloat = 54
                var x: CGFloat = 0
                var i = 0
                while x < size.width {
                    if i % 2 == 0 {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: w, height: size.height)), with: .color(Color(hex: 0xFFE4EE)))
                    }
                    x += w; i += 1
                }
                // little hearts on the wallpaper
                var y: CGFloat = 150
                var row = 0
                while y < size.height * 0.75 {
                    var hx: CGFloat = row % 2 == 0 ? 27 : 81
                    while hx < size.width {
                        let r = CGRect(x: hx - 6, y: y - 6, width: 12, height: 12)
                        ctx.fill(Path(ellipseIn: r), with: .color(Color(hex: 0xFFFFFF, alpha: 0.7)))
                        hx += 108
                    }
                    y += 90; row += 1
                }
            }
            GeometryReader { geo in
                let s = geo.size.height / 834
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    while x < size.width {
                        var g = ctx
                        g.translateBy(x: x, y: 0)
                        g.scaleBy(x: s, y: s)
                        BakeryArt.shared.draw("awning", in: g)
                        x += 1200 * s
                    }
                    for wx in [size.width * 0.08, size.width * 0.78] {
                        var g = ctx
                        g.translateBy(x: wx, y: 150 * s)
                        g.scaleBy(x: s * 0.8, y: s * 0.8)
                        BakeryArt.shared.draw("window", in: g)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct Counter: View {
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            g.scaleBy(x: size.height / 260, y: size.height / 260)
            BakeryArt.shared.draw("counter", in: g)
            var g2 = ctx
            g2.translateBy(x: 1200 * size.height / 260, y: 0)
            g2.scaleBy(x: size.height / 260, y: size.height / 260)
            BakeryArt.shared.draw("counter", in: g2)
        }
    }
}

struct KitchenBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xEAF7FF)))
            let tile: CGFloat = 64
            let wallH = size.height * 0.7
            var y: CGFloat = 0
            var r = 0
            while y < wallH {
                var x: CGFloat = 0
                var c = r
                while x < size.width {
                    if c % 2 == 0 {
                        ctx.fill(Path(roundedRect: CGRect(x: x + 3, y: y + 3, width: tile - 6, height: tile - 6), cornerRadius: 10),
                                 with: .color(Color(hex: 0xD9EFFF)))
                    }
                    x += tile; c += 1
                }
                y += tile; r += 1
            }
            // countertop
            ctx.fill(Path(CGRect(x: 0, y: wallH, width: size.width, height: 26)), with: .color(Color(hex: 0xFFF6EC)))
            ctx.fill(Path(CGRect(x: 0, y: wallH + 26, width: size.width, height: size.height - wallH)), with: .color(Color(hex: 0xFFD9C2)))
            ctx.fill(Path(CGRect(x: 0, y: wallH + 26, width: size.width, height: 8)), with: .color(Color(hex: 0xF2BFA6)))
            var x: CGFloat = 30
            while x < size.width {
                ctx.fill(Path(roundedRect: CGRect(x: x, y: wallH + 60, width: 140, height: size.height - wallH - 90), cornerRadius: 20),
                         with: .color(Color(hex: 0xFFE6D6)))
                x += 180
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - The treat case (every treat she has served)

struct TreatCase: View {
    @ObservedObject var store: BakeryStore
    let close: () -> Void
    let pick: (Treat) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea().onTapGesture(perform: close)
            DesignCanvas {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        RoundButton(symbol: "xmark", tint: Theme.pink, action: close)
                    }
                    if store.served.isEmpty {
                        Sprite("thought", box: Box.thought).frame(width: 300, height: 270)
                            .overlay(TreatView(treat: .tile, plate: false).frame(width: 150, height: 150).offset(x: 24, y: -28).opacity(0.5))
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(170), spacing: 18), count: 5), spacing: 18) {
                                ForEach(Array(store.served.enumerated()), id: \.offset) { _, t in
                                    Button { pick(t) } label: {
                                        TreatView(treat: t)
                                            .padding(10)
                                            .frame(width: 170, height: 170)
                                            .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(hex: 0xFFF7F2)))
                                            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Theme.blush, lineWidth: 5))
                                    }
                                    .buttonStyle(Squish())
                                }
                            }
                            .padding(.bottom, 30)
                        }
                    }
                }
                .padding(28)
                .frame(width: 1000, height: 760)
                .background(RoundedRectangle(cornerRadius: 50, style: .continuous).fill(.white))
                .shadow(color: Theme.ink.opacity(0.25), radius: 20, y: 10)
            }
        }
    }
}
