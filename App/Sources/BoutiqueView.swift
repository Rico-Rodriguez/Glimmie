import SwiftUI

// MARK: - Frame reading helpers

private let space = "boutique"

struct FrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func frameTag(_ id: String) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: FrameKey.self, value: [id: g.frame(in: .named(space))])
        })
    }
}

// MARK: - Drag model

enum StickerKind: Equatable {
    case item(String)
    case takeOff(Category)
    var key: String {
        switch self {
        case .item(let id): return id
        case .takeOff(let c): return "off_" + c.rawValue
        }
    }
}

struct DragState {
    var sticker: StickerKind
    var tint: Color?
    var start: CGPoint
    var location: CGPoint
    var tilt: Double = 0
    var returning = false
}

// MARK: - Boutique

struct BoutiqueView: View {
    @EnvironmentObject var game: GameState
    let editAvatar: () -> Void

    @State private var tab: Category = .dress
    @State private var drawerColor: [Category: Int] = [:]
    @State private var drag: DragState? = nil
    @State private var frames: [String: CGRect] = [:]

    // avatar reactions
    @State private var squish = false
    @State private var cheer = false
    @State private var breathe = false
    @State private var bursts: [Int] = []
    @State private var burstSeq = 0

    // wishes + rewards
    @State private var wish: Wish? = nil
    @State private var wishShown = false
    @State private var celebrating = false
    @State private var confetti = 0
    @State private var flyingStar = false
    @State private var starAtJar = false
    @State private var jarPulse = false
    @State private var showEgg = false
    @State private var showShelf = false
    @State private var showHouse = ProcessInfo.processInfo.arguments.contains("-demoHouse")
    @State private var secretBanner: SecretLook? = nil
    @State private var hintFor: String? = nil
    @State private var lastHint = Date.distantPast
    @State private var greeted = false
    @State private var wishTask: DispatchWorkItem? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DreamyBackground()

                HStack(spacing: 0) {
                    stage(height: geo.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    drawer(height: geo.size.height)
                        .frame(width: min(380, geo.size.width * 0.32))
                        .padding(.vertical, 18)
                    tabs
                        .frame(width: 104)
                        .padding(.trailing, 12)
                }

                // top bar
                VStack {
                    HStack(spacing: 16) {
                        CandyButton(symbol: "face.smiling", color: Color(red: 1, green: 0.85, blue: 0.92), size: 66) { editAvatar() }
                        StarJar(stars: game.stars, pulse: jarPulse).frameTag("jar")
                        Spacer()
                        CandyButton(symbol: "house.fill", color: Color(red: 1, green: 0.8, blue: 0.62), size: 66) { showHouse = true }
                        CandyButton(symbol: "square.grid.2x2.fill", color: Theme.lilac, size: 66) { showShelf = true }
                    }
                    .padding(.leading, 22)
                    .padding(.trailing, min(380, geo.size.width * 0.32) + 104 + 30)
                    .padding(.top, 18)
                    Spacer()
                }

                if confetti > 0 { Confetti().id(confetti) }

                // star flying from the wish bubble to the jar
                if flyingStar, let from = frames["wish"], let to = frames["jar"] {
                    StarShape()
                        .fill(Theme.gold)
                        .overlay(StarShape().stroke(Color.white, lineWidth: 3))
                        .frame(width: 70, height: 70)
                        .shadow(color: Theme.gold, radius: 12)
                        .rotationEffect(.degrees(starAtJar ? 360 : 0))
                        .scaleEffect(starAtJar ? 0.6 : 1.3)
                        .position(starAtJar ? CGPoint(x: to.midX, y: to.midY) : CGPoint(x: from.midX, y: from.midY))
                        .allowsHitTesting(false)
                }

                if let s = secretBanner { secretView(s).transition(.scale.combined(with: .opacity)) }

                // the sticker being dragged
                if let d = drag {
                    stickerArt(d.sticker, tint: d.tint)
                        .frame(width: 150, height: 150)
                        .scaleEffect(d.returning ? 1 : 1.18)
                        .rotationEffect(.degrees(d.tilt))
                        .shadow(color: Theme.ink.opacity(d.returning ? 0.1 : 0.35), radius: d.returning ? 4 : 16, y: d.returning ? 2 : 14)
                        .position(d.location)
                        .allowsHitTesting(false)
                }

                if showEgg {
                    HatchView(kind: game.nextGlimmie) { finishHatch() }
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .coordinateSpace(name: space)
            .onPreferenceChange(FrameKey.self) { frames = $0 }
        }
        .fullScreenCover(isPresented: $showShelf) {
            ShelfView { showShelf = false }.environmentObject(game)
        }
        .fullScreenCover(isPresented: $showHouse) {
            HouseView {
                showHouse = false
                if wish == nil { scheduleWish(after: 3) }
            }
            .environmentObject(game)
        }
        .onAppear(perform: appear)
    }

    // MARK: Stage

    private func stage(height: CGFloat) -> some View {
        let hovering = drag.map { !$0.returning && overAvatar($0.location) } ?? false
        return ZStack {
            StageFloor().offset(y: height * 0.38)

            DollView(avatar: game.avatar, outfit: game.outfit, happy: cheer)
                .frame(height: height * 0.86)
                .shadow(color: hovering ? Color.white : .clear, radius: hovering ? 24 : 0)
                .shadow(color: hovering ? Color(red: 1, green: 0.6, blue: 0.85) : .clear, radius: hovering ? 12 : 0)
                .scaleEffect(x: squish ? 1.07 : 1, y: squish ? 0.93 : (breathe ? 1.008 : 1), anchor: .bottom)
                .offset(y: cheer ? -18 : 0)
                .frameTag("avatar")
                .onTapGesture { tapAvatar() }
                .offset(y: height * 0.04)

            ForEach(bursts, id: \.self) { _ in SparkleBurst(count: 18, radius: 220) }

            if let wish, wishShown {
                wishView(wish)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 90).padding(.leading, 10)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: squish)
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: cheer)
        .animation(.easeInOut(duration: 0.2), value: hovering)
    }

    private func wishView(_ wish: Wish) -> some View {
        HStack(alignment: .top, spacing: 0) {
            GlimmieView(kind: wish.glimmie)
                .frame(width: 190, height: 190)
                .scaleEffect(celebrating ? 1.15 : 1)
                .rotationEffect(.degrees(celebrating ? -8 : 0))
                .onTapGesture { Sound.shared.say(wish.sentence) }
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(Array(wish.wants.enumerated()), id: \.offset) { _, w in
                        let met = w.isMet(by: game.outfit)
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                StickerIcon(name: w.iconItem, tint: wantTint(w))
                                if w.item == nil {
                                    Image(systemName: "sparkles").font(.system(size: 18, weight: .bold)).foregroundColor(Theme.ink.opacity(0.5))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                }
                            }
                            .frame(width: 112, height: 112)
                            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(met ? Color(red: 0.3, green: 0.8, blue: 0.45) : Theme.ink.opacity(0.25))
                                .background(Circle().fill(Color.white).padding(2))
                                .scaleEffect(met ? 1.15 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: met)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.92))
                    .shadow(color: Theme.ink.opacity(0.18), radius: 8, y: 4)
            )
            .overlay(alignment: .leading) {
                Circle().fill(Color.white.opacity(0.92)).frame(width: 18, height: 18).offset(x: -14, y: 10)
            }
            .frameTag("wish")
            .onTapGesture { Sound.shared.say(wish.sentence) }
            .offset(y: 30)
        }
    }

    private func wantTint(_ w: Want) -> Color? {
        let it = Catalog.item(w.iconItem)
        guard it?.tintable == true else { return nil }
        return Palette.clothes[w.color ?? it!.defaultColor].color
    }

    private func secretView(_ s: SecretLook) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles").font(.system(size: 44, weight: .bold)).foregroundColor(Theme.gold)
            Text(s.name)
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.6), radius: 0, x: 3, y: 3)
                .shadow(color: Theme.ink.opacity(0.4), radius: 10)
        }
        .padding(.horizontal, 50).padding(.vertical, 24)
        .background(Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.7, blue: 0.86), Theme.lilac], startPoint: .leading, endPoint: .trailing)))
        .overlay(Capsule().stroke(Color.white, lineWidth: 6))
        .shadow(color: Theme.ink.opacity(0.3), radius: 16, y: 8)
        .allowsHitTesting(false)
    }

    // MARK: Drawer

    private var tabs: some View {
        VStack(spacing: 14) {
            ForEach(Category.allCases) { c in
                Button {
                    guard tab != c else { return }
                    Sound.shared.play(.tap, volume: 0.6)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { tab = c }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(c.tabColor)
                            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white, lineWidth: tab == c ? 6 : 3))
                            .shadow(color: Theme.ink.opacity(tab == c ? 0.3 : 0.15), radius: tab == c ? 8 : 4, y: 3)
                        Art.image("I_" + c.tabIcon).resizable().aspectRatio(contentMode: .fit)
                            .padding(12)
                    }
                    .frame(width: 92, height: 92)
                    .scaleEffect(tab == c ? 1.08 : 0.94)
                    .offset(x: tab == c ? -8 : 0)
                }
                .buttonStyle(SquishStyle())
            }
        }
    }

    private func drawer(height: CGFloat) -> some View {
        let items = Catalog.items(in: tab)
        let anyTint = items.contains { $0.tintable }
        let sel = drawerColor[tab] ?? currentColor(tab)
        let stickerSize: CGFloat = min(150, (height - 260) / 3)
        return VStack(spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                ForEach(Palette.clothes) { s in
                    Button { pickColor(s.id) } label: { ColorDot(color: s.color, selected: anyTint && sel == s.id, size: 50) }
                        .buttonStyle(SquishStyle())
                }
            }
            .opacity(anyTint ? 1 : 0.3)
            .disabled(!anyTint)
            .padding(.horizontal, 6)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(items) { it in
                    let tint = it.tintable ? Palette.clothes[sel].color : nil
                    sticker(.item(it.id), tint: tint, size: stickerSize, wearing: game.outfit[tab]?.item == it.id)
                }
                sticker(.takeOff(tab), tint: nil, size: stickerSize, wearing: false)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 40).stroke(tab.tabColor, lineWidth: 6))
                .shadow(color: Theme.ink.opacity(0.15), radius: 10, y: 4)
        )
        .id(tab)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    @ViewBuilder
    private func stickerArt(_ k: StickerKind, tint: Color?) -> some View {
        switch k {
        case .item(let id):
            StickerIcon(name: id, tint: tint)
        case .takeOff:
            ZStack {
                Circle().fill(Color.white).shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 4)
                Circle().fill(Color(red: 1, green: 0.88, blue: 0.93)).padding(14)
                Image(systemName: "xmark").font(.system(size: 46, weight: .heavy)).foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.6))
            }
            .padding(14)
        }
    }

    private func sticker(_ k: StickerKind, tint: Color?, size: CGFloat, wearing: Bool) -> some View {
        let isDragged = drag?.sticker == k
        return stickerArt(k, tint: tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(wearing ? Color.white.opacity(0.9) : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(wearing ? tab.tabColor : .clear, lineWidth: 4))
            )
            .opacity(isDragged ? 0.25 : 1)
            .scaleEffect(hintFor == k.key ? 1.12 : 1)
            .rotationEffect(.degrees(hintFor == k.key ? 6 : 0))
            .animation(.spring(response: 0.25, dampingFraction: 0.35), value: hintFor)
            .contentShape(Rectangle())
            .onTapGesture { hint(k) }
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named(space))
                    .onChanged { v in dragChanged(k, tint: tint, v) }
                    .onEnded { v in dragEnded(v) }
            )
    }

    // MARK: Drag logic

    private func overAvatar(_ p: CGPoint) -> Bool {
        guard let f = frames["avatar"] else { return false }
        // the doll image has empty margins; use the middle of it as the target
        return f.insetBy(dx: f.width * 0.12, dy: f.height * 0.04).contains(p)
    }

    private func dragChanged(_ k: StickerKind, tint: Color?, _ v: DragGesture.Value) {
        let lifted = CGPoint(x: v.location.x, y: v.location.y - 30)
        if drag == nil || drag?.returning == true || drag?.sticker != k {
            Sound.shared.play(.tap, volume: 0.5)
            Sound.shared.tapHaptic()
            drag = DragState(sticker: k, tint: tint, start: v.startLocation, location: lifted)
        }
        let vx = v.predictedEndLocation.x - v.location.x
        let tilt = max(-22, min(22, Double(vx) * 0.08))
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.5)) {
            drag?.location = lifted
            drag?.tilt = tilt
        }
    }

    private func dragEnded(_ v: DragGesture.Value) {
        guard var d = drag, !d.returning else { return }
        let lifted = CGPoint(x: v.location.x, y: v.location.y - 30)
        if overAvatar(lifted) || overAvatar(v.location) {
            drag = nil
            wear(d.sticker)
        } else {
            Sound.shared.play(.boing, volume: 0.6)
            d.returning = true
            d.tilt = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                d.location = d.start
                drag = d
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                if drag?.returning == true { drag = nil }
            }
        }
    }

    // MARK: Actions

    private func currentColor(_ c: Category) -> Int {
        if let w = game.outfit[c], Catalog.item(w.item)?.tintable == true { return w.color }
        return Catalog.items(in: c).first(where: { $0.tintable })?.defaultColor ?? 0
    }

    private func wear(_ k: StickerKind) {
        switch k {
        case .item(let id):
            guard let it = Catalog.item(id) else { return }
            let color = drawerColor[it.category] ?? currentColor(it.category)
            game.outfit[it.category] = Worn(item: id, color: color)
            Sound.shared.play(.pop)
            Sound.shared.play(.sparkle, volume: 0.5)
        case .takeOff(let c):
            guard game.outfit[c] != nil else { Sound.shared.play(.boing, volume: 0.5); return }
            game.outfit[c] = nil
            Sound.shared.play(.whoosh)
        }
        Sound.shared.tapHaptic()
        react()
        checkProgress()
    }

    private func pickColor(_ i: Int) {
        drawerColor[tab] = i
        Sound.shared.play(.ding, volume: 0.6)
        if var w = game.outfit[tab], Catalog.item(w.item)?.tintable == true {
            w.color = i
            game.outfit[tab] = w
            react()
            checkProgress()
        }
        Sound.shared.say(Palette.clothes[i].name)
    }

    private func react() {
        burstSeq += 1
        let id = burstSeq
        bursts.append(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { bursts.removeAll { $0 == id } }
        squish = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { squish = false }
        cheerBriefly(0.7)
    }

    private func cheerBriefly(_ t: Double) {
        cheer = true
        DispatchQueue.main.asyncAfter(deadline: .now() + t) { if !celebrating { cheer = false } }
    }

    private func tapAvatar() {
        Sound.shared.play(.boing, volume: 0.5)
        Sound.shared.say(["Hee hee!", "I love my outfit!", "So sparkly!", "Twirl, twirl!", "Do I look pretty?"].randomElement()!)
        squish = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { squish = false }
        cheerBriefly(0.8)
    }

    private func hint(_ k: StickerKind) {
        hintFor = k.key
        Sound.shared.play(.tap, volume: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { if hintFor == k.key { hintFor = nil } }
        if Date().timeIntervalSince(lastHint) > 4 {
            lastHint = Date()
            Sound.shared.say("Drag it onto you!")
        }
    }

    // MARK: Wishes & rewards

    private func appear() {
        Art.preload()
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathe = true }
        if game.eggWaiting {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { showEgg = true } }
            return
        }
        if !greeted {
            greeted = true
            Sound.shared.say("Welcome to the boutique! Drag a sticker onto you to dress up!")
        }
        scheduleWish(after: 5)
    }

    private func scheduleWish(after t: Double) {
        wishTask?.cancel()
        let task = DispatchWorkItem {
            guard wish == nil, !showEgg, !showHouse else { return }
            let w = Wish.make(level: game.wishesDone, glimmies: game.owned, avoid: game.outfit)
            wish = w
            Sound.shared.play(.whoosh, volume: 0.7)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { wishShown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Sound.shared.say("Hi! It's \(Glimmies.all[w.glimmie].name). " + w.sentence)
            }
        }
        wishTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: task)
    }

    private func checkProgress() {
        // secret looks
        if let s = Secrets.all.first(where: { !game.secrets.contains($0.id) && $0.isMet(by: game.outfit) }) {
            game.secrets.append(s.id)
            Sound.shared.play(.fanfare)
            confetti += 1
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { secretBanner = s }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { Sound.shared.say("Secret look! " + s.name + "!", interrupt: true) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { withAnimation { secretBanner = nil } }
        }
        // the current wish
        guard let w = wish, !celebrating, w.isMet(by: game.outfit) else { return }
        celebrating = true
        cheer = true
        confetti += 1
        Sound.shared.play(.ding)
        Sound.shared.play(.sparkle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Sound.shared.say(["Yay! Thank you!", "You did it! So pretty!", "Wow! Perfect!", "Hooray! I love it!"].randomElement()!,
                             interrupt: secretBanner == nil)
        }
        // star flies to the jar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            starAtJar = false
            flyingStar = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.9)) { starAtJar = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                flyingStar = false
                Sound.shared.play(.ding)
                game.stars += 1
                game.wishesDone += 1
                jarPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { jarPulse = false }
                withAnimation(.easeIn(duration: 0.4)) { wishShown = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    wish = nil
                    celebrating = false
                    cheer = false
                    if game.stars >= GameState.jarSize {
                        game.stars = 0
                        game.eggWaiting = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation { showEgg = true } }
                    } else {
                        scheduleWish(after: 4)
                    }
                }
            }
        }
    }

    private func finishHatch() {
        if let k = game.nextGlimmie { game.owned.append(k) }
        game.eggWaiting = false
        withAnimation { showEgg = false }
        scheduleWish(after: 3)
    }
}
