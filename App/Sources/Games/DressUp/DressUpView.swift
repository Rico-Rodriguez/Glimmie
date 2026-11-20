import SwiftUI

struct DressUpView: View {
    let exit: () -> Void
    @StateObject private var store = LookStore()
    @State private var group = "me"
    @State private var cat = "hairBack"
    @State private var expression: Expression = .normal
    @State private var hop = false
    @State private var burst = 0
    @State private var flash = false
    @State private var showGallery = false
    /// The photo she just took, open in the sticker studio.
    @State private var studio: Look?
    @State private var galleryBounce = false
    @State private var showPets = false
    @State private var showStory = false
    @State private var danceID = 0
    @State private var battle: BattleState?
    /// Her skirt and hair swing (a class: it changes every frame).
    @State private var motion = DollMotion()

    private let art = DressUpArt.shared
    /// The part of the 600x900 art canvas shown on the stage: hat tips at the top, soles at the bottom.
    static let stageBox = CGRect(x: 30, y: 14, width: 540, height: 760)
    static let stageScale: CGFloat = 1.06

    var body: some View {
        ZStack {
            SceneView(bg: store.current.bg)
                .ignoresSafeArea()
                .id(store.current.bg)
                .transition(.opacity)
            SceneLife(bg: store.current.bg)
                .ignoresSafeArea()
                .id("life." + store.current.bg)
            DesignCanvas {
                HStack(spacing: 0) {
                    stage
                    Tray(store: store, group: $group, cat: $cat, onPick: celebrate)
                        .frame(width: 480)
                        .padding(.vertical, 18)
                        .padding(.trailing, 18)
                }
            }
            if flash {
                Color.white.ignoresSafeArea().transition(.opacity)
            }
            if showGallery {
                GalleryView(store: store, close: { withAnimation(.spring(response: 0.4)) { showGallery = false } },
                            open: { look in
                                store.open(look)
                                withAnimation(.spring(response: 0.4)) { showGallery = false }
                                celebrate()
                            })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
            if let photo = studio {
                PhotoStudio(look: photo) { look in
                    store.update(look)
                    withAnimation(.spring(response: 0.4)) { studio = nil }
                    galleryBounce = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.spring(response: 0.3)) { galleryBounce = false }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
            if let b = battle, b.phase == .intro {
                BattleIntroView(state: b,
                                start: {
                                    Sound.shared.play(.sparkle)
                                    store.current.bg = b.theme.scene
                                    withAnimation(.spring(response: 0.4)) { battle?.phase = .dressing }
                                },
                                cancel: { withAnimation(.spring(response: 0.4)) { battle = nil } },
                                reroll: {
                                    Sound.shared.play(.ding)
                                    withAnimation(.spring(response: 0.4)) { battle = .new() }
                                })
                    .transition(.opacity)
                    .zIndex(4)
            }
            if let b = battle, b.phase == .runway {
                RunwayView(state: b, mine: store.current,
                           again: { withAnimation(.spring(response: 0.4)) { battle = .new() } },
                           done: { withAnimation(.spring(response: 0.4)) { battle = nil } })
                    .transition(.opacity)
                    .zIndex(4)
            }
            if showStory {
                StoryStage(me: store.current, friends: store.gallery,
                           close: { withAnimation(.spring(response: 0.4)) { showStory = false } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
            if showPets {
                PetCornerView(look: store.current,
                              close: { withAnimation(.spring(response: 0.4)) { showPets = false } },
                              takeAlong: { pet in
                                  store.current.pet = pet
                                  guard pet != nil else { return }
                                  withAnimation(.spring(response: 0.4)) { showPets = false }
                                  celebrate()
                              },
                              restyle: { pet in store.current.pet = pet })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.current.bg)
        .task { await blinkLoop() }
        .onAppear(perform: applyLaunchArguments)
        .onDisappear { store.flush() }
    }

    private var stage: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(Theme.ink.opacity(0.18))
                    .frame(width: 250, height: 40)
                    .offset(y: -6)
                // Frame her from hat tip to shoe soles so she fills the stage and stands on the floor.
                LiveDollView(look: store.current, expression: expression, box: Self.stageBox, motion: motion,
                             windy: ["bg_park", "bg_beach", "bg_garden", "bg_snow", "bg_sunset", "bg_forest", "bg_rainbow"].contains(store.current.bg))
                    .frame(width: Self.stageBox.width * Self.stageScale, height: Self.stageBox.height * Self.stageScale)
                    .offset(y: hop ? -26 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { cheer() }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { motion.drag($0.location) }
                            .onEnded { _ in motion.endDrag() }
                    )
                TwinkleBurst()
                    .id(burst)
                    .offset(y: -420)
                if danceID > 0 {
                    MusicNotes().id(danceID).offset(y: -380)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 0)

            HStack(spacing: 18) {
                HomeButton { store.flush(); exit() }
                Spacer()
                RoundButton(symbol: "pawprint.fill", tint: Color(hex: 0xFFA24C)) {
                    Sound.shared.play(.whoosh)
                    withAnimation(.spring(response: 0.4)) { showPets = true }
                }
                RoundButton(symbol: "trophy.fill", tint: Color(hex: 0xF2B83E)) {
                    Sound.shared.play(.whoosh)
                    withAnimation(.spring(response: 0.4)) { battle = .new() }
                }
                RoundButton(symbol: "dice.fill", tint: Color(hex: 0x9B79E0)) { surprise() }
                RoundButton(symbol: "camera.fill", tint: Color(hex: 0xF45C9A)) { snap() }
                RoundButton(symbol: "photo.on.rectangle.angled", tint: Color(hex: 0x46B7B0)) {
                    Sound.shared.play(.whoosh)
                    withAnimation(.spring(response: 0.4)) { showGallery = true }
                }
                .scaleEffect(galleryBounce ? 1.25 : 1)
                .overlay(alignment: .topTrailing) {
                    if !store.gallery.isEmpty {
                        Text("\(store.gallery.count)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: 0xF45C9A)))
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)

            VStack(spacing: 16) {
                RoundButton(symbol: "music.note", tint: Color(hex: 0x46B7B0)) { dance() }
                RoundButton(symbol: "theatermasks.fill", tint: Color(hex: 0x9B79E0)) {
                    Sound.shared.play(.whoosh)
                    store.flush()
                    withAnimation(.spring(response: 0.4)) { showStory = true }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 26)
            .padding(.top, 112)

            if let b = battle, b.phase == .dressing {
                BattleBanner(state: b) {
                    Sound.shared.play(.fanfare, volume: 0.7)
                    store.flush()
                    withAnimation(.spring(response: 0.5)) { battle?.phase = .runway }
                }
                .padding(.top, 112)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    /// Simulator screenshot hooks: -randomLook, -tab <group>, -demoGallery, -demoStudio, -demoStory, -demoDance.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-randomLook") { store.current = Look.random().sanitized() }
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
            group = args[i + 1]
            cat = art.categories.first { $0.group == group }?.id ?? cat
        }
        if args.contains("-demoPets") || args.contains("-petDemo") { showPets = true }
        if args.contains("-demoCompanion") {
            var p = PetLook(kind: "puppy")
            p.wear = ["hat": "ph_party", "neck": "pn_bandana"]
            p.colors = ["hat": 16, "neck": 4]
            store.current.pet = p
        }
        if args.contains("-demoBattle") { battle = .new() }
        if args.contains("-demoRunway") { var b = BattleState.new(); b.phase = .runway; battle = b }
        if args.contains("-demoDance") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dance() }
        }
        if args.contains("-demoGallery") {
            let keep = store.current
            for _ in 0..<8 { store.current = Look.random().sanitized(); store.saveToGallery() }
            store.current = keep
            if var first = store.gallery.first {
                first.stickers = Self.demoStickers
                first.frame = "hearts"
                store.update(first)
            }
            showGallery = true
        }
        if args.contains("-demoStory") {
            let keep = store.current
            for _ in 0..<3 { store.current = Look.random().sanitized(); store.saveToGallery() }
            store.current = keep
            showStory = true
        }
        if args.contains("-demoStudio") {
            var photo = store.saveToGallery()
            photo.stickers = Self.demoStickers + [PhotoSticker(kind: "pet:bunny", x: 0.2, y: 0.62, size: 0.28, turn: -6)]
            photo.frame = "stars"
            store.update(photo)
            studio = photo
        }
    }

    private static let demoStickers = [
        PhotoSticker(kind: "heart.fill", x: 0.18, y: 0.14, size: 0.2, turn: -12),
        PhotoSticker(kind: "star.fill", x: 0.82, y: 0.2, size: 0.28, turn: 10),
        PhotoSticker(kind: "sparkles", x: 0.74, y: 0.5, size: 0.14, turn: 0),
        PhotoSticker(kind: "item:h_crown", x: 0.3, y: 0.82, size: 0.2, turn: 8),
    ]

    // MARK: Actions

    private func celebrate() {
        burst += 1
        motion.hop()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { hop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { hop = false }
        }
    }

    private func cheer() {
        Sound.shared.play(.boing)
        Sound.shared.tap()
        expression = .happy
        celebrate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            if expression == .happy { expression = .normal }
        }
    }

    /// A little dance with music; her pet dances along.
    private func dance() {
        Sound.shared.tap()
        motion.startDance(at: Date().timeIntervalSinceReferenceDate)
        danceID += 1
        let id = danceID
        let tune: [SFX] = [.note1, .note3, .note2, .note4, .note1, .note3, .note4, .note2,
                           .note3, .note1, .note2, .note4, .note3, .note2, .note1, .ding]
        let step = DollMotion.danceLength / Double(tune.count)
        for (i, n) in tune.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * step) {
                guard danceID == id else { return }
                Sound.shared.play(n, volume: 0.7)
                if i % 4 == 2 { expression = .happy }
                if i % 4 == 3, expression == .happy { expression = .normal }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + DollMotion.danceLength) {
            if danceID == id { expression = .normal }
        }
    }

    private func surprise() {
        Sound.shared.play(.sparkle)
        Sound.shared.tap()
        withAnimation(.easeInOut(duration: 0.2)) { store.current = Look.random().sanitized() }
        celebrate()
    }

    private func snap() {
        Sound.shared.play(.fanfare, volume: 0.8)
        Sound.shared.tap()
        let photo = store.saveToGallery()
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        // then decorate it in the sticker studio
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.45)) { studio = photo }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.35)) { flash = false }
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4).delay(0.2)) { galleryBounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.3)) { galleryBounce = false }
        }
        cheer()
    }

    private func blinkLoop() async {
        while !Task.isCancelled {
            let wait = UInt64(Double.random(in: 2.2...5.0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: wait)
            guard expression == .normal else { continue }
            expression = .blink
            try? await Task.sleep(nanoseconds: 140_000_000)
            if expression == .blink { expression = .normal }
        }
    }
}

// MARK: - The tray of categories, items and colors

private struct Tray: View {
    @ObservedObject var store: LookStore
    @Binding var group: String
    @Binding var cat: String
    let onPick: () -> Void

    @State private var mixing = false

    private let art = DressUpArt.shared
    private static let groups: [(id: String, first: String)] = [("me", "hairBack"), ("clothes", "dress"), ("extras", "hat"), ("scene", "bg"), ("sets", "sets")]

    var body: some View {
        VStack(spacing: 14) {
            groupTabs
            categoryChips
            ScrollView(showsIndicators: false) {
                if group == "sets" { setsGrid } else if cat == "skin" { skinGrid } else { itemGrid }
            }
            .frame(maxHeight: .infinity)
            swatches
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(.white.opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(.white, lineWidth: 5))
        .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
        .overlay {
            if mixing {
                ColorMixer(palette: art.cloth, close: { withAnimation(.spring(response: 0.35)) { mixing = false } }) { hex in
                    store.current.mixed[mixKey] = hex
                    store.mixes.removeAll { $0 == hex }
                    store.mixes.insert(hex, at: 0)
                    if store.mixes.count > 12 { store.mixes.removeLast(store.mixes.count - 12) }
                    withAnimation(.spring(response: 0.35)) { mixing = false }
                    onPick()
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
    }

    // Big tabs: Me / Clothes / Extras / Scene
    private var groupTabs: some View {
        HStack(spacing: 10) {
            ForEach(Self.groups, id: \.id) { g in
                Button {
                    Sound.shared.play(.tap)
                    group = g.id
                    cat = g.first
                } label: {
                    groupIcon(g.id)
                        .frame(width: 78, height: 78)
                        .frame(maxWidth: .infinity)
                        .frame(height: 92)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(group == g.id ? Theme.pink.opacity(0.9) : Theme.blush.opacity(0.7)))
                }
                .buttonStyle(Squish())
            }
        }
    }

    @ViewBuilder private func groupIcon(_ id: String) -> some View {
        switch id {
        case "me": DollView(look: store.current, box: CGRect(x: 120, y: 70, width: 360, height: 380))
        case "clothes": ItemThumb(item: "d_princess", look: Look.starter)
        case "extras": ItemThumb(item: "h_crown", look: Look.starter)
        case "sets": ItemThumb(item: "d_pumpkin", look: Look.starter)
        default:
            SceneView(bg: store.current.bg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white, lineWidth: 3))
                .padding(4)
        }
    }

    private var categoriesInGroup: [ArtCategory] { art.categories.filter { $0.group == group } }

    @ViewBuilder private var categoryChips: some View {
        let cats = categoriesInGroup
        if cats.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cats) { c in
                        Button {
                            Sound.shared.play(.tap, volume: 0.7)
                            cat = c.id
                        } label: {
                            chipIcon(c)
                                .padding(8)
                                .frame(width: 74, height: 74)
                                .background(Circle().fill(.white))
                                .overlay(Circle().stroke(cat == c.id ? Theme.pink : Theme.blush, lineWidth: cat == c.id ? 6 : 3))
                        }
                        .buttonStyle(Squish())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(height: 84)
        }
    }

    @ViewBuilder private func chipIcon(_ c: ArtCategory) -> some View {
        if c.id == "skin" {
            DollView(look: store.current, box: CGRect(x: 140, y: 130, width: 320, height: 320))
        } else if let icon = c.icon {
            ItemThumb(item: store.current.picks[c.id] ?? icon, look: store.current)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    private var itemGrid: some View {
        let c = art.category(cat)
        let selected = cat == "bg" ? store.current.bg : store.current.picks[cat]
        return LazyVGrid(columns: columns, spacing: 12) {
            if let c, !c.required {
                cell(selected: selected == nil) {
                    Image(systemName: "xmark")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(Theme.pink.opacity(0.7))
                } action: {
                    Sound.shared.play(.whoosh, volume: 0.6)
                    store.current.takeOff(cat)
                }
            }
            ForEach(c?.items ?? [], id: \.self) { id in
                cell(selected: selected == id, scene: cat == "bg") {
                    ItemThumb(item: id, look: store.current)
                } action: {
                    Sound.shared.play(.pop)
                    Sound.shared.tap()
                    store.current.wear(id, in: cat)
                    onPick()
                }
            }
        }
        .padding(4)
    }

    /// Ready-made sets: one tap dresses her (and her pet) for Halloween, winter, a birthday...
    private var setsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(OutfitSet.all) { set in
                cell(selected: isWearing(set)) {
                    ZStack {
                        SceneView(bg: set.bg)
                            .opacity(0.55)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        ItemThumb(item: set.icon, look: set.apply(to: Look.starter))
                            .padding(6)
                    }
                } action: {
                    Sound.shared.play(.sparkle)
                    Sound.shared.tap()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        store.current = set.apply(to: store.current).sanitized()
                    }
                    onPick()
                }
            }
        }
        .padding(4)
    }

    private func isWearing(_ set: OutfitSet) -> Bool {
        store.current.bg == set.bg && set.picks.allSatisfy { store.current.picks[$0.key] == $0.value }
    }

    private var skinGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(art.skin.indices, id: \.self) { i in
                cell(selected: store.current.skin == i) {
                    DollView(look: withSkin(i), box: CGRect(x: 140, y: 130, width: 320, height: 320))
                } action: {
                    Sound.shared.play(.pop)
                    store.current.skin = i
                    onPick()
                }
            }
        }
        .padding(4)
    }

    private func withSkin(_ i: Int) -> Look {
        var l = store.current
        l.skin = i
        return l
    }

    private func cell<Content: View>(selected: Bool, scene: Bool = false, @ViewBuilder content: () -> Content,
                                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            content()
                .padding(scene ? 0 : 8)
                .frame(height: 98)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(selected ? Theme.blush : Color(hex: 0xFFF7FA)))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(selected ? Theme.pink : Color(hex: 0xF5DDE8), lineWidth: selected ? 6 : 3))
        }
        .buttonStyle(Squish())
    }

    // MARK: Colors and patterns

    private var currentItem: ArtItem? { store.current.picks[cat].flatMap { art.items[$0] } }

    @ViewBuilder private var swatches: some View {
        let palette = art.category(cat)?.palette
        VStack(spacing: 10) {
            switch palette ?? "" {
            case "hair": mixRow(art.hair, selected: store.current.hair) { store.current.hair = $0 }
            case "eye": mixRow(art.eye, selected: store.current.eye) { store.current.eye = $0 }
            case "cloth":
                if let item = currentItem, item.colorSource == .own {
                    mixRow(art.cloth, selected: store.current.colorIndex(for: item)) { store.current.colors[cat] = $0 }
                    if item.patternable { patternRow(item) }
                }
            default: EmptyView()
            }
        }
    }

    /// Where a mixed color is kept: "hair" and "eye" for her hair and eyes, else the clothing category.
    private var mixKey: String {
        switch art.category(cat)?.palette {
        case "hair": return "hair"
        case "eye": return "eye"
        default: return cat
        }
    }

    /// Colors for hair, eyes and clothes: the paint pot (mix your own), her own mixes, then the palette.
    private func mixRow(_ palette: [RGB], selected index: Int, pick: @escaping (Int) -> Void) -> some View {
        let key = mixKey
        let mine = store.current.mixed[key]
        let selected = mine == nil ? index : -1
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        Sound.shared.play(.whoosh, volume: 0.6)
                        withAnimation(.spring(response: 0.35)) { mixing = true }
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(AngularGradient(colors: [Theme.pink, Theme.lemon, Theme.mint, Theme.sky, Theme.lilac, Theme.pink], center: .center)))
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .padding(4)
                    }
                    .buttonStyle(Squish())
                    ForEach(store.mixes, id: \.self) { hex in
                        let c = RGB(hex: hex)
                        Button {
                            Sound.shared.play(.ding, volume: 0.6)
                            store.current.mixed[key] = hex
                        } label: {
                            swatch(c, on: mine == hex)
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "drop.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                        .padding(3).background(Circle().fill(Theme.ink.opacity(0.45))).offset(x: 2, y: 2)
                                }
                        }
                        .buttonStyle(Squish())
                    }
                    ForEach(palette.indices, id: \.self) { i in
                        Button {
                            Sound.shared.play(.ding, volume: 0.6)
                            pick(i)
                            store.current.mixed[key] = nil
                        } label: {
                            swatch(palette[i], on: selected == i)
                        }
                        .buttonStyle(Squish())
                        .id(i)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onAppear { if selected >= 0 { proxy.scrollTo(selected, anchor: .center) } }
        }
        .frame(height: 64)
    }

    private func swatch(_ c: RGB, on: Bool) -> some View {
        Circle()
            .fill(c.color)
            .frame(width: 50, height: 50)
            .overlay(Circle().stroke(Shades.outline(c).color.opacity(0.5), lineWidth: 2))
            .overlay(Circle().stroke(.white, lineWidth: on ? 5 : 0).padding(3))
            .overlay(Circle().stroke(Theme.pink, lineWidth: on ? 4 : 0).padding(-3))
            .padding(4)
    }

    private func patternRow(_ item: ArtItem) -> some View {
        let names = ["none"] + art.patternNames
        let current = store.current.patterns[cat] ?? "none"
        let base = store.current.paints(for: item).main
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(names, id: \.self) { name in
                    Button {
                        Sound.shared.play(.ding, volume: 0.6)
                        store.current.patterns[cat] = name == "none" ? nil : name
                    } label: {
                        PatternSwatch(name: name, base: base)
                            .frame(width: 50, height: 50)
                            .overlay(Circle().stroke(Theme.pink, lineWidth: current == name ? 4 : 0).padding(-3))
                            .padding(4)
                    }
                    .buttonStyle(Squish())
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 64)
    }
}

struct PatternSwatch: View {
    let name: String
    let base: RGB
    var body: some View {
        Canvas { ctx, size in
            let circle = Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1))
            ctx.fill(circle, with: .color(base.color))
            if let pat = DressUpArt.shared.patterns[name] {
                var c = ctx
                c.clip(to: circle)
                c.scaleBy(x: size.width / 120, y: size.width / 120)
                if name == "checks" { c.opacity = 0.55 }
                c.fill(pat, with: .color(Shades.pattern(base).color))
            }
            ctx.stroke(circle, with: .color(Shades.outline(base).color.opacity(0.5)), lineWidth: 2)
        }
    }
}

/// Music notes floating up while she dances.
private struct MusicNotes: View {
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                Image(systemName: i % 2 == 0 ? "music.note" : "music.quarternote.3")
                    .font(.system(size: CGFloat(30 + (i % 3) * 10), weight: .bold))
                    .foregroundStyle([Theme.pink, Color(hex: 0x46B7B0), Color(hex: 0x9B79E0), Color(hex: 0xF2B83E)][i % 4])
                    .offset(x: CGFloat((i * 97) % 360 - 180) + (go ? CGFloat(i % 2 == 0 ? 30 : -30) : 0),
                            y: go ? -200 - CGFloat(i * 14) : 120)
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 2.2).delay(Double(i) * 0.3), value: go)
            }
        }
        .allowsHitTesting(false)
        .onAppear { go = true }
    }
}
