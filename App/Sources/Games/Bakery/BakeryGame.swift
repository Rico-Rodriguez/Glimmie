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
        play: { exit in AnyView(BakeryGameView(exit: exit)) },
        stickers: BakeryFind.stickers
    )
}

struct BakeryGameView: View {
    let exit: () -> Void
    @StateObject private var store = BakeryStore()
    @State private var dessertStation: ICStation?
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
                ShopView(store: store, ready: $ready, order: $order, exit: exit, openStation: openStation) { kind in
                    if kind == .iceCream {
                        openStation(.scoop)
                        return
                    }
                    BakerySound.shared.play(.plop)
                    Sound.shared.tap()
                    startStep = 0
                    withAnimation(.easeInOut(duration: 0.35)) { making = Treat(kind: kind) }
                }
                .opacity(dessertStation == nil ? 1 : 0)
                .allowsHitTesting(dessertStation == nil)
                .accessibilityHidden(dessertStation != nil)
                .transition(.opacity)
            }
            if let station = dessertStation {
                IceCreamView(station: station, bakery: store, exit: { openStation(nil) })
                    .id(station)
                    .transition(.opacity)
            }
        }
        .onAppear(perform: applyLaunchArguments)
        .onDisappear { store.save() }
    }

    private func openStation(_ station: ICStation?) {
        Sound.shared.play(.whoosh, volume: 0.6)
        withAnimation(.easeInOut(duration: 0.3)) { dessertStation = station }
    }

    /// Simulator screenshot hooks: -bakeryDecorate <cake|cupcake|bungeoppang>, -bakeryServe, -bakeryStep <n>.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.hasPrefix("-bakery") }) { order = BakeryOrder.random(customer: 2, seed: 11) }
        if let i = args.firstIndex(of: "-bakeryDecorate"), i + 1 < args.count, let k = TreatKind(rawValue: args[i + 1]) {
            if k == .iceCream {
                dessertStation = .scoop
            } else {
                startStep = 3
                making = Treat.sample(k, seed: 5)
            }
        }
        if let i = args.firstIndex(of: "-bakeryStep"), i + 2 < args.count, let k = TreatKind(rawValue: args[i + 1]), let n = Int(args[i + 2]) {
            if k == .iceCream {
                dessertStation = .scoop
            } else {
                startStep = n
                var t = Treat(kind: k)
                if n > 0 { t = Treat.sample(k, seed: 2); t.toppings = []; if k == .cake || k == .bungeoppang { t.frosting = nil }; if k == .cupcake { t.frostStage = 0 } }
                making = t
            }
        }
        if let i = args.firstIndex(of: "-iceDemo") {
            let arg = i + 1 < args.count ? args[i + 1] : "soft"
            dessertStation = arg == "bingsu" ? .bingsu : arg == "scoop" || arg == "sundae" ? .scoop : (arg == "blend" || arg == "pour" ? .smoothie : .soft)
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
    let openStation: (ICStation) -> Void
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
    @State private var showStickers = false
    @State private var burst = 0

    var body: some View {
        ZStack {
            ShopBackground()
            DesignCanvas {
                ZStack {
                    customerLayer
                    counterLayer
                    topBar
                    StickerToast(game: BakeryStore.game, target: GameChromeLayout.stickerTarget)
                }
                .frame(width: 1024, height: 834)
                .coinPurse(game: "bakery")
            }
            if showCase {
                TreatCase(store: store, close: { withAnimation(.spring(response: 0.4)) { showCase = false } }) { t in
                    withAnimation(.spring(response: 0.4)) { showCase = false }
                    if phase != .eating {
                        BakerySound.shared.play(.magic)
                        bites = 0
                        treatLift = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { ready = t }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }
            if showStickers {
                StickerBookView(game: BakeryStore.game) {
                    withAnimation(.spring(response: 0.35)) { showStickers = false }
                }
                .transition(.opacity)
                .zIndex(4)
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
            // floating hearts track the customer cleanly
            ForEach(0..<hearts, id: \.self) { i in
                FloatingHeart(index: i).position(x: 470 + custX, y: 260)
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
                    MakeButton(kind: .bungeoppang, wished: wish == .bungeoppang && phase == .waiting) { make(.bungeoppang) }
                }
                .position(x: 512, y: 710)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            HomeButton(size: GameChromeLayout.buttonSize) { store.save(); exit() }
            StickerBookButton(game: BakeryStore.game, size: GameChromeLayout.buttonSize) {
                withAnimation(.spring(response: 0.35)) { showStickers = true }
            }
            IceCreamParlorButton { openStation(.scoop) }
                .accessibilityLabel("Ice Cream Parlor")
            Spacer()
            CoinCounter(game: "bakery", height: GameChromeLayout.buttonSize)
            ZStack(alignment: .bottomTrailing) {
                Sprite("heartjar", box: Box.thing).frame(width: 78, height: 78)
                Text("\(store.hearts)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 2)
                    .background(Capsule().fill(Color(hex: 0xF45C9A)))
                    .offset(x: 8, y: 4)
            }
            .scaleEffect(jarBounce ? 1.3 : 1)
            RoundButton(symbol: "square.grid.2x2.fill", tint: Color(hex: 0x46B7B0), size: GameChromeLayout.buttonSize) {
                Sound.shared.play(.whoosh)
                withAnimation(.spring(response: 0.4)) { showCase = true }
            }
            .accessibilityLabel("Treat Case")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .frame(maxHeight: .infinity, alignment: .top)
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
            if !ShopView.demoServe {
                StickerBook.shared.find(game: BakeryStore.game, id: BakeryFind.firstTreat.rawValue)
                if matched {
                    StickerBook.shared.find(game: BakeryStore.game, id: BakeryFind.threeStarBaker.rawValue)
                }
                if t.kind == .cake && t.tiers >= 3 {
                    StickerBook.shared.find(game: BakeryStore.game, id: BakeryFind.tallCake.rawValue)
                }
                let colorfulDecor = t.toppings.contains { $0.sprite.hasPrefix("bit_") } || Set(t.toppings.map { $0.color }).count >= 3
                if t.kind != .iceCream && t.frosting != nil && colorfulDecor {
                    StickerBook.shared.find(game: BakeryStore.game, id: BakeryFind.rainbowFrost.rawValue)
                }
                if t.kind == .bungeoppang {
                    StickerBook.shared.find(game: BakeryStore.game, id: BakeryFind.bungeoppang.rawValue)
                }
                if t.kind == .iceCream {
                    StickerBook.shared.find(game: BakeryStore.game, id: BakeryFind.iceCreamPro.rawValue)
                }
            }
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
        let seed = kind == .cake ? 4 : kind == .cupcake ? 7 : kind == .bungeoppang ? 9 : 12
        Button(action: tap) {
            TreatView(treat: Treat.sample(kind, seed: seed), plate: false)
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

private struct IceCreamParlorButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Canvas { ctx, size in
                let s = min(size.width, size.height) / 52
                var g = ctx
                g.translateBy(x: (size.width - 52 * s) / 2, y: (size.height - 52 * s) / 2)
                g.scaleBy(x: s, y: s)

                // Cute pastel Korean bingsu snow bowl tucked to the right behind the cone
                var spoon = Path()
                spoon.move(to: CGPoint(x: 38, y: 26))
                spoon.addLine(to: CGPoint(x: 45, y: 12))
                g.stroke(spoon, with: .color(StorybookArt.outline(for: 0xFF9EC4)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                g.stroke(spoon, with: .color(StorybookArt.color(0xFFD6E6)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

                let snow = Path(ellipseIn: CGRect(x: 27, y: 17, width: 19, height: 15))
                StorybookArt.shape(g, snow, hex: 0xF7FBFF, width: 1.8)
                let pat = Path(ellipseIn: CGRect(x: 33, y: 15.5, width: 7.5, height: 5))
                StorybookArt.shape(g, pat, hex: 0x7A2E3B, width: 1.3)

                var bowl = Path()
                bowl.move(to: CGPoint(x: 26, y: 26))
                bowl.addLine(to: CGPoint(x: 47, y: 26))
                bowl.addQuadCurve(to: CGPoint(x: 41.5, y: 41.5), control: CGPoint(x: 47, y: 36))
                bowl.addLine(to: CGPoint(x: 31.5, y: 41.5))
                bowl.addQuadCurve(to: CGPoint(x: 26, y: 26), control: CGPoint(x: 26, y: 36))
                bowl.closeSubpath()
                StorybookArt.shape(g, bowl, hex: 0xB8EAE2, width: 2)

                // Golden waffle cone in front
                var cone = Path()
                cone.move(to: CGPoint(x: 10.5, y: 26))
                cone.addLine(to: CGPoint(x: 29.5, y: 26))
                cone.addQuadCurve(to: CGPoint(x: 20, y: 46.5), control: CGPoint(x: 25.5, y: 39))
                cone.addQuadCurve(to: CGPoint(x: 10.5, y: 26), control: CGPoint(x: 14.5, y: 39))
                cone.closeSubpath()
                StorybookArt.shape(g, cone, hex: 0xF2B572, width: 2.2)

                var grid = Path()
                grid.move(to: CGPoint(x: 14.5, y: 27.5)); grid.addLine(to: CGPoint(x: 23.5, y: 37.5))
                grid.move(to: CGPoint(x: 25.5, y: 27.5)); grid.addLine(to: CGPoint(x: 16.5, y: 37.5))
                g.stroke(grid, with: .color(StorybookArt.outline(for: 0xF2B572, factor: 0.72).opacity(0.65)),
                         style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                // Mint + strawberry double scoops with shine
                let bottomScoop = Path(ellipseIn: CGRect(x: 9.5, y: 15.5, width: 21, height: 15.5))
                StorybookArt.shape(g, bottomScoop, hex: 0x9BE3CA, width: 2.2)
                StorybookArt.highlight(g, in: CGRect(x: 13, y: 18.2, width: 5, height: 3), opacity: 0.65)

                let topScoop = Path(ellipseIn: CGRect(x: 11.5, y: 6.5, width: 17, height: 14))
                StorybookArt.shape(g, topScoop, hex: 0xFF8FB8, width: 2.2)
                StorybookArt.highlight(g, in: CGRect(x: 14.5, y: 8.8, width: 4.5, height: 2.8), opacity: 0.65)

                let cherry = Path(ellipseIn: CGRect(x: 17, y: 2.5, width: 6.2, height: 6.2))
                StorybookArt.shape(g, cherry, hex: 0xF45B7A, width: 1.6)
                StorybookArt.highlight(g, in: CGRect(x: 18.4, y: 3.6, width: 2.1, height: 1.6), opacity: 0.75)

                StorybookArt.sparkle(g, at: CGPoint(x: 7, y: 10), radius: 3.5, color: Theme.lemon)
            }
            .frame(width: 48, height: 48)
            .frame(width: GameChromeLayout.buttonSize, height: GameChromeLayout.buttonSize)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFFFDFB), Color(hex: 0xFFF1E6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(Circle().stroke(Theme.peach, lineWidth: 4.5))
            .shadow(color: Theme.ink.opacity(0.22), radius: 6, y: 4)
        }
        .buttonStyle(Squish())
    }
}

// MARK: - Backgrounds

struct ShopBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Canvas { ctx, size in
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xFFF5F8), Color(hex: 0xFFEBF2)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
                let w: CGFloat = 54
                var x: CGFloat = 0
                var i = 0
                while x < size.width {
                    if i % 2 == 0 {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: w, height: size.height)), with: .color(Color(hex: 0xFFE2ED).opacity(0.75)))
                    }
                    x += w; i += 1
                }
                // Little storybook heart motifs on the wallpaper
                var y: CGFloat = 150
                var row = 0
                while y < size.height * 0.75 {
                    var hx: CGFloat = row % 2 == 0 ? 27 : 81
                    while hx < size.width {
                        StorybookArt.heart(ctx, at: CGPoint(x: hx, y: y), size: 15, color: .white, opacity: 0.76)
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
                    let tileRect = CGRect(x: x + 3, y: y + 3, width: tile - 6, height: tile - 6)
                    if c % 2 == 0 {
                        ctx.fill(Path(roundedRect: tileRect, cornerRadius: 10), with: .color(Color(hex: 0xD9EFFF)))
                        ctx.fill(
                            Path(roundedRect: CGRect(x: tileRect.minX + 6, y: tileRect.minY + 4, width: tileRect.width - 12, height: 6), cornerRadius: 3),
                            with: .color(.white.opacity(0.35))
                        )
                    }
                    x += tile; c += 1
                }
                y += tile; r += 1
            }

            // Soft backsplash shadow right above the counter
            ctx.fill(
                Path(CGRect(x: 0, y: wallH - 14, width: size.width, height: 14)),
                with: .linearGradient(
                    Gradient(colors: [Theme.ink.opacity(0), Theme.ink.opacity(0.08)]),
                    startPoint: CGPoint(x: 0, y: wallH - 14),
                    endPoint: CGPoint(x: 0, y: wallH)
                )
            )

            // Countertop with subtle lip depth and top highlight
            ctx.fill(
                Path(CGRect(x: 0, y: wallH, width: size.width, height: 28)),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xFFFBF5), Color(hex: 0xFFF1E3)]),
                    startPoint: CGPoint(x: 0, y: wallH),
                    endPoint: CGPoint(x: 0, y: wallH + 28)
                )
            )
            ctx.fill(Path(CGRect(x: 0, y: wallH, width: size.width, height: 4)), with: .color(.white.opacity(0.85)))
            ctx.fill(Path(CGRect(x: 0, y: wallH + 28, width: size.width, height: size.height - wallH)), with: .color(Color(hex: 0xFFD9C2)))
            ctx.fill(
                Path(CGRect(x: 0, y: wallH + 28, width: size.width, height: 12)),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xE6AD90).opacity(0.75), Color(hex: 0xFFD9C2).opacity(0)]),
                    startPoint: CGPoint(x: 0, y: wallH + 28),
                    endPoint: CGPoint(x: 0, y: wallH + 40)
                )
            )

            // Recessed cabinet doors with trim and warm ceramic knobs
            let cabTrim = StorybookArt.outline(for: 0xFFD9C2, factor: 0.8)
            let knobOutline = StorybookArt.outline(for: 0xE8A878, factor: 0.72)
            let doorH = max(40, size.height - wallH - 86)
            var x: CGFloat = 28
            while x < size.width {
                let doorRect = CGRect(x: x, y: wallH + 54, width: 146, height: doorH)
                let doorPath = Path(roundedRect: doorRect, cornerRadius: 18)
                ctx.fill(doorPath, with: .color(Color(hex: 0xFFE8D8)))
                ctx.stroke(doorPath, with: .color(cabTrim.opacity(0.55)), lineWidth: 3)

                let insetRect = doorRect.insetBy(dx: 12, dy: 12)
                if insetRect.height > 12 {
                    let insetPath = Path(roundedRect: insetRect, cornerRadius: 11)
                    ctx.fill(insetPath, with: .color(Color(hex: 0xFFDFCC).opacity(0.65)))
                    ctx.stroke(insetPath, with: .color(.white.opacity(0.55)), lineWidth: 2)
                }

                // Cute cabinet handle/knob
                let knobC = CGPoint(x: doorRect.maxX - 24, y: doorRect.minY + min(34, doorH * 0.35))
                let knob = Path(ellipseIn: CGRect(x: knobC.x - 9, y: knobC.y - 9, width: 18, height: 18))
                ctx.fill(knob.offsetBy(dx: 0, dy: 2.5), with: .color(Theme.ink.opacity(0.14)))
                StorybookArt.fillAndStroke(ctx, knob, fill: StorybookArt.color(0xFFF6EC), stroke: knobOutline, width: 2.5)
                StorybookArt.highlight(ctx, in: CGRect(x: knobC.x - 5, y: knobC.y - 5.5, width: 5, height: 3.5), opacity: 0.85)

                x += 178
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
                                ForEach(Array(store.served.enumerated()), id: \.offset) { idx, t in
                                    ZStack(alignment: .topTrailing) {
                                        Button { pick(t) } label: {
                                            TreatView(treat: t)
                                                .padding(10)
                                                .frame(width: 170, height: 170)
                                                .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(hex: 0xFFF7F2)))
                                                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Theme.blush, lineWidth: 5))
                                        }
                                        .buttonStyle(Squish())

                                        Button {
                                            Sound.shared.play(.whoosh, volume: 0.5)
                                            Sound.shared.tap()
                                            withAnimation(.spring(response: 0.3)) {
                                                store.removeServed(at: idx)
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 15, weight: .black))
                                                .foregroundStyle(.white)
                                                .frame(width: 34, height: 34)
                                                .background(Circle().fill(Color(hex: 0xF45C9A)))
                                                .overlay(Circle().stroke(.white, lineWidth: 3))
                                                .shadow(color: Theme.ink.opacity(0.2), radius: 3, y: 2)
                                        }
                                        .buttonStyle(Squish())
                                        .accessibilityLabel("Delete Treat")
                                        .offset(x: 8, y: -8)
                                    }
                                }
                            }
                            .padding(.top, 10)
                            .padding(.horizontal, 10)
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
