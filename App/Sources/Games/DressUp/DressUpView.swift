import SwiftUI

/// The 5 consolidated Face & Hair sub-tabs, partitioning all 10 underlying `me` categories without dropping an item.
enum MeSubTab: String, CaseIterable, Identifiable {
    case skin
    case hair
    case eyes
    case mouthAndBlush
    case faceShape

    var id: String { rawValue }

    var categoryIDs: [String] {
        switch self {
        case .skin: return ["skin"]
        case .hair: return ["hairFront", "hairBack"]
        case .eyes: return ["eyes", "brows"]
        case .mouthAndBlush: return ["mouth", "cheeks", "makeup"]
        case .faceShape: return ["face", "nose"]
        }
    }

    var primaryCategoryID: String {
        switch self {
        case .skin: return "skin"
        case .hair: return "hairBack"
        case .eyes: return "eyes"
        case .mouthAndBlush: return "mouth"
        case .faceShape: return "face"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .skin: return "Skin Tone"
        case .hair: return "Hair"
        case .eyes: return "Eyes"
        case .mouthAndBlush: return "Mouth and Blush"
        case .faceShape: return "Face Shape"
        }
    }

    static var allCoveredCategoryIDs: [String] {
        allCases.flatMap(\.categoryIDs)
    }

    static func tab(forCategory categoryID: String) -> MeSubTab {
        allCases.first { $0.categoryIDs.contains(categoryID) } ?? .hair
    }
}

struct DressUpView: View {
    let exit: () -> Void
    @StateObject private var store = LookStore()
    @State private var group = "me"
    @State private var cat = "hairBack"
    @State private var expression: Expression = .normal
    @State private var hop = false
    @State private var burst = 0
    @State private var flash = false
    @State private var showActivityHub = false
    @State private var showGallery = false
    /// The photo she just took, open in the sticker studio.
    @State private var studio: Look?
    @State private var galleryBounce = false
    @State private var showPets = false
    @State private var showStory = false
    /// The makeup or nail studio, when open.
    @State private var beauty: BeautyWorld.Mode?
    @State private var danceID = 0
    @State private var battle: BattleState?
    @State private var showBook = false
    /// Her skirt and hair swing (a class: it changes every frame).
    @State private var motion = DollMotion()
    @AppStorage(PinnedFairySpec.defaultsKey) private var pinnedFairyID = ""

    private let art = DressUpArt.shared
    /// The part of the 600x900 art canvas shown on the stage: hat tips at the top, soles at the bottom.
    static let stageBox = CGRect(x: 30, y: 14, width: 540, height: 760)
    static let stageScale: CGFloat = 1.06

    /// Fits `LiveDollView` cleanly within the stage column so it never clips behind the wardrobe tray.
    static func fittedDollSize(in stageSize: CGSize) -> CGSize {
        let maxW = max(1, min(stageSize.width - 16, stageBox.width * stageScale))
        let maxH = max(1, min(stageSize.height - 28, stageBox.height * stageScale))
        let s = min(maxW / stageBox.width, maxH / stageBox.height, stageScale)
        return CGSize(width: stageBox.width * s, height: stageBox.height * s)
    }

    private var isStageCovered: Bool {
        showActivityHub || showGallery || studio != nil || showPets || showStory || beauty != nil
            || battle?.phase == .intro || battle?.phase == .runway || showBook
    }

    var body: some View {
        ZStack {
            SceneView(bg: store.current.bg)
                .ignoresSafeArea()
                .id(store.current.bg)
                .transition(.opacity)
            SceneLife(bg: store.current.bg, paused: isStageCovered)
                .ignoresSafeArea()
                .id("life." + store.current.bg)
            DesignCanvas {
                HStack(spacing: 0) {
                    stage
                    Tray(store: store, group: $group, cat: $cat, onPick: celebrate)
                        .frame(width: 480)
                        .padding(.top, 18)
                        .padding(.bottom, 32)
                        .padding(.trailing, 18)
                }
                .coinPurse(game: LookStore.game)
            }
            if flash {
                Color.white.ignoresSafeArea().transition(.opacity)
            }
            if showActivityHub {
                DressUpActivityHub(
                    look: store.current,
                    latestPhoto: store.gallery.first,
                    hasGalleryItems: store.hasGalleryItems,
                    close: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showActivityHub = false
                        }
                    },
                    select: openActivity
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .zIndex(3)
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
                PhotoStudio(
                    look: photo,
                    cancel: {
                        withAnimation(.spring(response: 0.4)) { studio = nil }
                    },
                    done: { look in
                        store.update(look)
                        withAnimation(.spring(response: 0.4)) { studio = nil }
                        galleryBounce = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation(.spring(response: 0.3)) { galleryBounce = false }
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
            if let b = battle, b.phase == .intro {
                BattleIntroView(state: b,
                                mine: store.current,
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
            if let mode = beauty {
                BeautyStudio(
                    look: store.current,
                    mode: mode,
                    cancel: {
                        withAnimation(.spring(response: 0.4)) { beauty = nil }
                    },
                    done: { look in
                        if look != store.current {
                            store.pushUndoSnapshot()
                        }
                        store.current = look
                        if look.makeup.contains(where: \.hasPoints) {
                            DressUpFind.glamMakeup.unlock()
                        }
                        if look.nails.contains(where: \.hasArt) {
                            DressUpFind.nailArtist.unlock()
                        }
                        withAnimation(.spring(response: 0.4)) { beauty = nil }
                        cheer()
                    }
                )
                .id(mode)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }
            if showStory {
                StoryStage(me: store.current, friends: store.gallery, store: store,
                           close: { withAnimation(.spring(response: 0.4)) { showStory = false } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
            if showPets {
                PetCornerView(look: store.current,
                              close: { withAnimation(.spring(response: 0.4)) { showPets = false } },
                              takeAlong: { pet in
                                  if store.current.pet != pet {
                                      store.pushUndoSnapshot()
                                  }
                                  store.current.pet = pet
                                  guard pet != nil else { return }
                                  withAnimation(.spring(response: 0.4)) { showPets = false }
                                  celebrate()
                              },
                              restyle: { pet in store.current.pet = pet })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
            DesignCanvas {
                StickerToast(game: LookStore.game, target: GameChromeLayout.stickerTarget)
            }
            .allowsHitTesting(false)
            .zIndex(5)
            if showBook {
                StickerBookView(game: LookStore.game) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(6)
            }
        }
        .defersSystemGestures(on: .bottom)
        .animation(.easeInOut(duration: 0.35), value: store.current.bg)
        .task { await blinkLoop() }
        .onAppear(perform: applyLaunchArguments)
        .onDisappear { store.flush() }
    }

    private var stage: some View {
        GeometryReader { geo in
            let dollSize = Self.fittedDollSize(in: geo.size)
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(Theme.ink.opacity(0.18))
                    .frame(width: min(250, dollSize.width * 0.44), height: 40)
                    .offset(y: -6)
                // Frame her from hat tip to shoe soles above the lifted bottom bar without clipping into the tray.
                LiveDollView(look: store.current, expression: expression, box: Self.stageBox, motion: motion,
                             windy: ["bg_park", "bg_beach", "bg_garden", "bg_snow", "bg_sunset", "bg_forest", "bg_rainbow"].contains(store.current.bg),
                             paused: isStageCovered)
                    .frame(width: dollSize.width, height: dollSize.height)
                    .offset(y: hop ? -26 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { tapDoll() }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { motion.drag($0.location) }
                            .onEnded { _ in motion.endDrag() }
                    )
                    .accessibilityLabel("Dance")
                if let fairy = PinnedFairySpec.spec(for: pinnedFairyID) {
                    PinnedFairyCompanionView(spec: fairy, paused: isStageCovered)
                        .frame(width: 112, height: 112)
                        .position(
                            x: min(geo.size.width - 66, geo.size.width * 0.5 + dollSize.width * 0.36),
                            y: max(156, geo.size.height - dollSize.height * 0.72)
                        )
                }
                if burst > 0 {
                    TwinkleBurst()
                        .id(burst)
                        .offset(y: -380)
                }
                if danceID > 0 {
                    MusicNotes().id(danceID).offset(y: -350)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .padding(.bottom, 108)
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .overlay(alignment: .top) {
            HStack(spacing: 14) {
                HomeButton(size: GameChromeLayout.buttonSize) { store.flush(); exit() }
                StickerBookButton(game: LookStore.game, size: GameChromeLayout.buttonSize) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = true
                    }
                }
                .accessibilityLabel("Sticker Book")
                Spacer()
                CoinCounter(game: LookStore.game, height: GameChromeLayout.buttonSize)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
        }
        .overlay(alignment: .top) {
            if let b = battle, b.phase == .dressing {
                BattleBanner(
                    state: b,
                    cancel: {
                        withAnimation(.spring(response: 0.4)) { battle = nil }
                    },
                    done: {
                        Sound.shared.play(.fanfare, volume: 0.7)
                        store.flush()
                        withAnimation(.spring(response: 0.5)) { battle?.phase = .runway }
                    }
                )
                .padding(.top, 98)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            bottomControlBar
                .padding(.bottom, 34)
        }
    }

    private var bottomControlBar: some View {
        GameTrayCard(cornerRadius: 42, paddingH: 12, paddingV: 10) {
            HStack(spacing: 12) {
                Button {
                    Sound.shared.play(.whoosh, volume: 0.65)
                    Sound.shared.tap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showActivityHub = true
                    }
                } label: {
                    PlayHubButtonArt()
                        .frame(width: 118, height: 64)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0xD8BEFF), Color(hex: 0xFFA7CF)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(Capsule().stroke(.white, lineWidth: 4))
                        .shadow(color: Theme.ink.opacity(0.22), radius: 6, y: 4)
                }
                .buttonStyle(Squish())
                .scaleEffect(galleryBounce ? 1.12 : 1)
                .accessibilityLabel("Activities")

                Button(action: snap) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color(hex: 0xF45C9A)))
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .shadow(color: Theme.ink.opacity(0.22), radius: 6, y: 4)
                }
                .buttonStyle(Squish())
                .accessibilityLabel("Take Photo")

                HStack(spacing: 10) {
                    RoundButton(symbol: "dice.fill", tint: Color(hex: 0x9B79E0), size: 64) {
                        surprise()
                    }
                    .accessibilityLabel("Surprise Outfit")

                    if store.canUndo {
                        Button(action: undoLook) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 25, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 58, height: 58)
                                .background(Circle().fill(Color(hex: 0x67B7FF)))
                                .overlay(Circle().stroke(.white, lineWidth: 4))
                                .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
                        }
                        .buttonStyle(Squish())
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .accessibilityLabel("Undo")
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: store.canUndo)
    }

    /// Simulator screenshot hooks: -randomLook, -tab <group>, -demoGallery, -demoStudio, -demoStory, -demoDance, -demoMakeup, -demoNails.
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
        if args.contains("-demoMakeup") || args.contains("-demoNails") {
            var l = store.current
            l.makeup = [BeautyStroke(tool: "blush", color: "#FF8FA8", pts: [206, 362, 222, 366, 238, 364]),
                        BeautyStroke(tool: "blush", color: "#FF8FA8", pts: [362, 364, 378, 366, 394, 362]),
                        BeautyStroke(tool: "shadow", color: "#B48BE8", pts: [214, 306, 238, 300, 262, 306]),
                        BeautyStroke(tool: "shadow", color: "#B48BE8", pts: [338, 306, 362, 300, 386, 306]),
                        BeautyStroke(tool: "lip", color: "#F45C9A", pts: [276, 388, 290, 384, 304, 390, 318, 386, 324, 390]),
                        BeautyStroke(tool: "glitter", color: "#F2C14E", pts: [228, 350, 236, 344, 372, 348, 366, 342, 300, 280, 312, 286])]
            var nails: [NailPaint] = []
            for (i, c) in ["#F45C9A", "#7FB8F0", "#F45C9A", "#7FB8F0", "#F45C9A"].enumerated() {
                var n = NailPaint()
                n.color = c
                n.mask = NailGrid.encode(NailGrid.inside)
                n.coats = 2
                n.glitter = i == 2
                if i == 1 { n.gems = [NailGem(kind: "g_heart", color: "#E8F4FF", u: 0, v: 0.5)] }
                nails.append(n)
            }
            l.nails = nails
            store.current = l.sanitized()
            beauty = args.contains("-demoNails") ? .nails : .makeup
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

    private func openActivity(_ activity: DressUpActivity) {
        Sound.shared.play(.whoosh)
        withAnimation(.spring(response: 0.4)) {
            showActivityHub = false
            switch activity {
            case .makeup:
                beauty = .makeup
            case .nails:
                beauty = .nails
            case .pets:
                showPets = true
            case .playhouse:
                store.flush()
                showStory = true
            case .runway:
                battle = .new()
            case .gallery:
                showGallery = true
            }
        }
    }

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

    /// Tapping the doll plays a joyful musical dance and cheer directly without a conflicting music button.
    private func tapDoll() {
        Sound.shared.play(.boing, volume: 0.72)
        Sound.shared.play(.cheer, volume: 0.55)
        expression = .happy
        celebrate()
        dance()
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
        withAnimation(.easeInOut(duration: 0.2)) {
            store.applySurprise()
        }
        celebrate()
    }

    private func undoLook() {
        guard store.canUndo else { return }
        Sound.shared.play(.whoosh, volume: 0.65)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
            _ = store.undo()
        }
        celebrate()
    }

    private func snap() {
        Sound.shared.play(.fanfare, volume: 0.8)
        Sound.shared.tap()
        let photo = store.saveToGallery()
        let earned = store.awardGallerySaveCoins(for: photo, from: CGPoint(x: 260, y: 420))
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        // Let earned Play Coins fly into the purse before opening the sticker studio.
        DispatchQueue.main.asyncAfter(deadline: .now() + (earned > 0 ? 1.15 : 0.9)) {
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
    private static let groups: [(id: String, first: String, label: String)] = [
        ("me", "hairBack", "Face and Hair"),
        ("clothes", "dress", "Clothes"),
        ("sets", "sets", "Full Outfits"),
        ("extras", "hat", "Accessories"),
        ("scene", "bg", "Scenes"),
    ]

    private var activeMeTab: MeSubTab {
        MeSubTab.tab(forCategory: cat)
    }

    private var scrollKey: String {
        if group == "sets" { return "sets" }
        if group == "me" { return "me.\(activeMeTab.rawValue)" }
        return "\(group).\(cat)"
    }

    var body: some View {
        VStack(spacing: 14) {
            groupTabs
            categoryChips
            ScrollView(showsIndicators: false) {
                if group == "sets" {
                    setsGrid
                } else if group == "me" {
                    meContent
                } else {
                    itemGrid(for: cat)
                }
            }
            .id(scrollKey)
            .frame(maxHeight: .infinity)
            swatches
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Theme.cream.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(Theme.blush, lineWidth: 4))
        .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
        .overlay {
            if mixing {
                let mixerCat = effectiveSwatchCategory ?? cat
                ColorMixer(
                    palette: ColorMixer.palette(forCategory: mixerCat, art: art),
                    close: { withAnimation(.spring(response: 0.35)) { mixing = false } }
                ) { hex in
                    store.current.mixed[mixKey] = hex
                    store.mixes.removeAll { $0 == hex }
                    store.mixes.insert(hex, at: 0)
                    if store.mixes.count > 12 { store.mixes.removeLast(store.mixes.count - 12) }
                    DressUpFind.colorAlchemist.unlock()
                    withAnimation(.spring(response: 0.35)) { mixing = false }
                    onPick()
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
    }

    // 5 clear group tabs: Face & Hair / Clothes / Full Outfits / Accessories / Scenes
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
                .accessibilityLabel(g.label)
            }
        }
    }

    @ViewBuilder private func groupIcon(_ id: String) -> some View {
        switch id {
        case "me":
            DollView(look: store.current, box: CGRect(x: 120, y: 70, width: 360, height: 380))
        case "clothes":
            ItemThumb(item: "d_princess", look: Look.starter)
        case "sets":
            OutfitSetsGroupIcon()
        case "extras":
            AccessoriesGroupIcon()
        default:
            SceneView(bg: store.current.bg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white, lineWidth: 3))
                .padding(4)
        }
    }

    private var categoriesInGroup: [ArtCategory] { art.categories.filter { $0.group == group } }

    @ViewBuilder private var categoryChips: some View {
        if group == "me" {
            // 5 unmistakable non-scrolling Face & Hair chips
            HStack(spacing: 10) {
                ForEach(MeSubTab.allCases) { tab in
                    let isSelected = activeMeTab == tab
                    Button {
                        Sound.shared.play(.tap, volume: 0.7)
                        cat = tab.primaryCategoryID
                    } label: {
                        MeSubTabIcon(tab: tab, look: store.current)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 74)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(isSelected ? Theme.pink : Theme.blush, lineWidth: isSelected ? 6 : 3)
                            )
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel(tab.accessibilityLabel)
                }
            }
            .padding(.horizontal, 2)
            .frame(height: 82)
        } else {
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
                            .accessibilityLabel(categoryLabel(for: c.id))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .frame(height: 84)
            }
        }
    }

    private func categoryLabel(for id: String) -> String {
        switch id {
        case "dress": return "Dresses"
        case "top": return "Tops"
        case "bottom": return "Bottoms"
        case "outer": return "Outerwear"
        case "socks": return "Socks"
        case "shoes": return "Shoes"
        case "earrings": return "Earrings"
        case "hat": return "Hats"
        case "glasses": return "Glasses"
        case "neck": return "Necklaces"
        case "back": return "Wings"
        case "hold": return "Props"
        default: return id
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

    @ViewBuilder private var meContent: some View {
        switch activeMeTab {
        case .skin:
            skinGrid
        default:
            VStack(spacing: 16) {
                ForEach(activeMeTab.categoryIDs, id: \.self) { categoryID in
                    VStack(spacing: 10) {
                        meSectionDivider(for: categoryID)
                        itemGrid(for: categoryID)
                    }
                }
            }
        }
    }

    private func meSectionDivider(for categoryID: String) -> some View {
        let fallback = art.category(categoryID)?.icon
        let thumbItem = store.current.picks[categoryID] ?? fallback
        return HStack(spacing: 10) {
            Capsule()
                .fill(Theme.blush)
                .frame(height: 3)
            HStack(spacing: 6) {
                if let item = thumbItem {
                    ItemThumb(item: item, look: store.current)
                        .frame(width: 30, height: 30)
                }
                if categoryID == "hairFront" {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.pink)
                } else if categoryID == "hairBack" {
                    Image(systemName: "wind")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: 0x9B79E0))
                } else if categoryID == "makeup" {
                    Twinkle()
                        .fill(Theme.lemon)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(Theme.blush, lineWidth: 2.5))
            Capsule()
                .fill(Theme.blush)
                .frame(height: 3)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    private func itemGrid(for categoryID: String) -> some View {
        let c = art.category(categoryID)
        let selected = categoryID == "bg" ? store.current.bg : store.current.picks[categoryID]
        return LazyVGrid(columns: columns, spacing: 12) {
            if let c, !c.required {
                cell(selected: selected == nil) {
                    Image(systemName: "xmark")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(Theme.pink.opacity(0.7))
                } action: {
                    Sound.shared.play(.whoosh, volume: 0.6)
                    cat = categoryID
                    store.current.takeOff(categoryID)
                }
                .accessibilityLabel("None")
            }
            ForEach(c?.availableItems ?? [], id: \.self) { id in
                cell(selected: selected == id, scene: categoryID == "bg") {
                    ItemThumb(item: id, look: store.current)
                } action: {
                    Sound.shared.play(.pop)
                    Sound.shared.tap()
                    cat = categoryID
                    store.current.wear(id, in: categoryID)
                    onPick()
                }
            }
        }
        .padding(4)
    }

    /// Ready-made sets: one tap dresses her (and her pet) for Hanbok, Fairy, Halloween, winter, birthday...
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
                        store.applyOutfitSet(set)
                    }
                    DressUpFind.outfitSet.unlock()
                    onPick()
                }
                .accessibilityLabel(set.id)
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

    private var effectiveSwatchCategory: String? {
        if group == "sets" { return nil }
        if group == "me" {
            switch activeMeTab {
            case .hair: return "hairBack"
            case .eyes: return "eyes"
            case .mouthAndBlush: return store.current.picks["makeup"] != nil ? "makeup" : nil
            case .skin, .faceShape: return nil
            }
        }
        return cat
    }

    private var currentItem: ArtItem? {
        guard let swatchCat = effectiveSwatchCategory else { return nil }
        return store.current.picks[swatchCat].flatMap { art.items[$0] }
    }

    @ViewBuilder private var swatches: some View {
        let swatchCat = effectiveSwatchCategory
        let palette = swatchCat.flatMap { art.category($0)?.palette }
        VStack(spacing: 10) {
            switch palette ?? "" {
            case "hair": mixRow(art.hair, selected: store.current.hair) { store.current.hair = $0 }
            case "eye": mixRow(art.eye, selected: store.current.eye) { store.current.eye = $0 }
            case "cloth":
                if let swatchCat, let item = currentItem, item.colorSource == .own {
                    mixRow(art.cloth, selected: store.current.colorIndex(for: item)) { store.current.colors[swatchCat] = $0 }
                    if item.patternable { patternRow(item, for: swatchCat) }
                }
            default: EmptyView()
            }
        }
    }

    /// Where a mixed color is kept: "hair" and "eye" for her hair and eyes, else the clothing category.
    private var mixKey: String {
        let swatchCat = effectiveSwatchCategory ?? cat
        switch art.category(swatchCat)?.palette {
        case "hair": return "hair"
        case "eye": return "eye"
        default: return swatchCat
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
                    .accessibilityLabel("Mix Color")
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

    private func patternRow(_ item: ArtItem, for categoryID: String) -> some View {
        let names = ["none"] + art.patternNames
        let current = store.current.patterns[categoryID] ?? "none"
        let base = store.current.paints(for: item).main
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(names, id: \.self) { name in
                    Button {
                        Sound.shared.play(.ding, volume: 0.6)
                        store.current.patterns[categoryID] = name == "none" ? nil : name
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

// MARK: - Group Tab & Consolidated Me Sub-Tab Icons

/// Sparkling twin-star Hanbok costume card icon for the Full Outfits group tab.
private struct OutfitSetsGroupIcon: View {
    private static let hanbokLook: Look = {
        OutfitSet.all.first { $0.id == "hanbok" }?.apply(to: Look.starter).sanitized() ?? Look.starter
    }()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFFF4D9), Color(hex: 0xFFE6F4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white, lineWidth: 3)
                )
                .padding(5)

            DollView(look: Self.hanbokLook, box: CGRect(x: 150, y: 422, width: 300, height: 336))
                .padding(8)

            Twinkle()
                .fill(Theme.lemon)
                .overlay(Twinkle().stroke(Color(hex: 0xE29B2E), lineWidth: 1.5))
                .frame(width: 22, height: 22)
                .offset(x: -24, y: -23)

            Twinkle()
                .fill(.white)
                .overlay(Twinkle().stroke(Theme.pink, lineWidth: 1.4))
                .frame(width: 18, height: 18)
                .offset(x: 24, y: 22)
        }
    }
}

/// Sparkling golden crown + butterfly wings badge for the Accessories group tab.
private struct AccessoriesGroupIcon: View {
    var body: some View {
        ZStack {
            ItemThumb(item: "w_butterfly", look: Look.starter)
                .scaleEffect(0.95)
                .offset(y: 6)
            ItemThumb(item: "h_crown", look: Look.starter)
                .scaleEffect(0.84)
                .offset(y: -8)
            Twinkle()
                .fill(Theme.lemon)
                .frame(width: 16, height: 16)
                .offset(x: 23, y: -22)
            Twinkle()
                .fill(.white)
                .frame(width: 13, height: 13)
                .offset(x: -24, y: -16)
        }
    }
}

/// Five unmistakable, non-repetitive custom icons for the consolidated Face & Hair strip.
private struct MeSubTabIcon: View {
    let tab: MeSubTab
    let look: Look

    private var art: DressUpArt { DressUpArt.shared }

    private var skinRGB: RGB {
        art.skin[safe: look.skin] ?? RGB(hex: "#FFDCCB")
    }

    private var hairRGB: RGB {
        look.mixed["hair"].map(RGB.init(hex:)) ?? art.hair[safe: look.hair] ?? RGB(hex: "#C98A55")
    }

    private var eyeRGB: RGB {
        look.mixed["eye"].map(RGB.init(hex:)) ?? art.eye[safe: look.eye] ?? RGB(hex: "#5C9BEB")
    }

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let cx = w * 0.5
            let cy = h * 0.5
            let s = min(w, h)

            switch tab {
            case .skin:
                // Fan of 3 distinct skin-tone droplets so it never looks like another face crop
                let tones: [(CGFloat, CGFloat, RGB)] = [
                    (-s * 0.25, s * 0.06, art.skin[safe: 0] ?? RGB(hex: "#FFE7D9")),
                    (0, -s * 0.08, art.skin[safe: 3] ?? RGB(hex: "#E8B692")),
                    (s * 0.25, s * 0.06, art.skin[safe: 6] ?? RGB(hex: "#9B6244")),
                ]
                let r = s * 0.23
                for (dx, dy, tone) in tones {
                    let c = CGPoint(x: cx + dx, y: cy + dy)
                    let drop = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                    StorybookArt.fillAndStroke(ctx, drop, fill: tone.color, stroke: Shades.outline(tone).color, width: 2.4)
                    StorybookArt.highlight(ctx, in: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.62, width: r * 0.55, height: r * 0.36), opacity: 0.5)
                }
                StorybookArt.heart(ctx, at: CGPoint(x: cx, y: cy + s * 0.28), size: s * 0.22, color: Theme.pink)

            case .hair:
                // Stylized wavy hairstyle sweep + cute pink ribbon bow in live hair color
                let hc = hairRGB
                var hair = Path()
                hair.move(to: CGPoint(x: cx - s * 0.36, y: cy + s * 0.36))
                hair.addCurve(
                    to: CGPoint(x: cx, y: cy - s * 0.40),
                    control1: CGPoint(x: cx - s * 0.46, y: cy - s * 0.14),
                    control2: CGPoint(x: cx - s * 0.26, y: cy - s * 0.42)
                )
                hair.addCurve(
                    to: CGPoint(x: cx + s * 0.36, y: cy + s * 0.36),
                    control1: CGPoint(x: cx + s * 0.26, y: cy - s * 0.42),
                    control2: CGPoint(x: cx + s * 0.46, y: cy - s * 0.14)
                )
                hair.addQuadCurve(to: CGPoint(x: cx + s * 0.14, y: cy + s * 0.26), control: CGPoint(x: cx + s * 0.24, y: cy + s * 0.42))
                hair.addQuadCurve(to: CGPoint(x: cx, y: cy - s * 0.04), control: CGPoint(x: cx + s * 0.12, y: cy + s * 0.02))
                hair.addQuadCurve(to: CGPoint(x: cx - s * 0.14, y: cy + s * 0.26), control: CGPoint(x: cx - s * 0.12, y: cy + s * 0.02))
                hair.addQuadCurve(to: CGPoint(x: cx - s * 0.36, y: cy + s * 0.36), control: CGPoint(x: cx - s * 0.24, y: cy + s * 0.42))
                hair.closeSubpath()
                StorybookArt.fillAndStroke(ctx, hair, fill: hc.color, stroke: Shades.outline(hc).color, width: 2.6)

                // Gloss highlight arc on hair crown
                var shine = Path()
                shine.move(to: CGPoint(x: cx - s * 0.18, y: cy - s * 0.16))
                shine.addQuadCurve(to: CGPoint(x: cx + s * 0.14, y: cy - s * 0.18), control: CGPoint(x: cx - s * 0.02, y: cy - s * 0.30))
                ctx.stroke(shine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

                // Cute bow accent on upper right of hair
                let bx = cx + s * 0.20
                let by = cy - s * 0.26
                let bowL = Path(ellipseIn: CGRect(x: bx - 12, y: by - 6, width: 12, height: 11))
                let bowR = Path(ellipseIn: CGRect(x: bx, y: by - 6, width: 12, height: 11))
                StorybookArt.fillAndStroke(ctx, bowL, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xF45C9A), width: 2)
                StorybookArt.fillAndStroke(ctx, bowR, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xF45C9A), width: 2)
                ctx.fill(Path(ellipseIn: CGRect(x: bx - 3.5, y: by - 3.5, width: 7, height: 7)), with: .color(Theme.lemon))

            case .eyes:
                // Big sparkling storybook eye with curved brow & catchlights in live eye color
                var brow = Path()
                brow.move(to: CGPoint(x: cx - s * 0.30, y: cy - s * 0.30))
                brow.addQuadCurve(to: CGPoint(x: cx + s * 0.30, y: cy - s * 0.28), control: CGPoint(x: cx, y: cy - s * 0.44))
                ctx.stroke(brow, with: .color(Shades.outline(hairRGB).color), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))

                let sclera = Path(ellipseIn: CGRect(x: cx - s * 0.38, y: cy - s * 0.18, width: s * 0.76, height: s * 0.56))
                StorybookArt.fillAndStroke(ctx, sclera, fill: .white, stroke: Theme.ink, width: 2.8)

                let irisR = s * 0.22
                let iris = Path(ellipseIn: CGRect(x: cx - irisR, y: cy - irisR + s * 0.08, width: irisR * 2, height: irisR * 2))
                StorybookArt.fillAndStroke(ctx, iris, fill: eyeRGB.color, stroke: Shades.outline(eyeRGB).color, width: 2.2)

                let pupilR = s * 0.11
                ctx.fill(Path(ellipseIn: CGRect(x: cx - pupilR, y: cy - pupilR + s * 0.08, width: pupilR * 2, height: pupilR * 2)), with: .color(Theme.ink))
                ctx.fill(Path(ellipseIn: CGRect(x: cx - irisR * 0.62, y: cy - irisR * 0.52 + s * 0.08, width: s * 0.13, height: s * 0.13)), with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x: cx + irisR * 0.22, y: cy + irisR * 0.22 + s * 0.08, width: s * 0.07, height: s * 0.07)), with: .color(.white))

                // Upper lash flourish
                var lash = Path()
                lash.move(to: CGPoint(x: cx - s * 0.39, y: cy + s * 0.04))
                lash.addQuadCurve(to: CGPoint(x: cx + s * 0.40, y: cy + s * 0.02), control: CGPoint(x: cx, y: cy - s * 0.26))
                ctx.stroke(lash, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            case .mouthAndBlush:
                // Twin rosy blush hearts + happy smiling rosy lips + sparkle
                ctx.fill(Path(ellipseIn: CGRect(x: cx - s * 0.44, y: cy - s * 0.18, width: s * 0.28, height: s * 0.18)), with: .color(Color(hex: 0xFFA4C2).opacity(0.65)))
                ctx.fill(Path(ellipseIn: CGRect(x: cx + s * 0.16, y: cy - s * 0.18, width: s * 0.28, height: s * 0.18)), with: .color(Color(hex: 0xFFA4C2).opacity(0.65)))

                var lips = Path()
                lips.move(to: CGPoint(x: cx - s * 0.30, y: cy + s * 0.04))
                lips.addQuadCurve(to: CGPoint(x: cx - s * 0.08, y: cy - s * 0.04), control: CGPoint(x: cx - s * 0.18, y: cy - s * 0.07))
                lips.addQuadCurve(to: CGPoint(x: cx, y: cy + s * 0.02), control: CGPoint(x: cx - s * 0.03, y: cy + s * 0.02))
                lips.addQuadCurve(to: CGPoint(x: cx + s * 0.08, y: cy - s * 0.04), control: CGPoint(x: cx + s * 0.03, y: cy + s * 0.02))
                lips.addQuadCurve(to: CGPoint(x: cx + s * 0.30, y: cy + s * 0.04), control: CGPoint(x: cx + s * 0.18, y: cy - s * 0.07))
                lips.addQuadCurve(to: CGPoint(x: cx - s * 0.30, y: cy + s * 0.04), control: CGPoint(x: cx, y: cy + s * 0.36))
                lips.closeSubpath()
                StorybookArt.fillAndStroke(ctx, lips, fill: Color(hex: 0xF45C9A), stroke: StorybookArt.outline(for: 0xD63E7F), width: 2.5)
                StorybookArt.highlight(ctx, in: CGRect(x: cx - s * 0.10, y: cy + s * 0.10, width: s * 0.16, height: s * 0.07), opacity: 0.65)
                StorybookArt.sparkle(ctx, at: CGPoint(x: cx + s * 0.28, y: cy - s * 0.30), radius: 7, color: Theme.lemon)

            case .faceShape:
                // Clean soft face-contour outline + cute button nose & chin guide sparkles
                let sc = skinRGB
                var contour = Path()
                contour.move(to: CGPoint(x: cx, y: cy - s * 0.36))
                contour.addCurve(
                    to: CGPoint(x: cx + s * 0.34, y: cy + s * 0.04),
                    control1: CGPoint(x: cx + s * 0.28, y: cy - s * 0.36),
                    control2: CGPoint(x: cx + s * 0.36, y: cy - s * 0.14)
                )
                contour.addCurve(
                    to: CGPoint(x: cx, y: cy + s * 0.38),
                    control1: CGPoint(x: cx + s * 0.32, y: cy + s * 0.24),
                    control2: CGPoint(x: cx + s * 0.16, y: cy + s * 0.38)
                )
                contour.addCurve(
                    to: CGPoint(x: cx - s * 0.34, y: cy + s * 0.04),
                    control1: CGPoint(x: cx - s * 0.16, y: cy + s * 0.38),
                    control2: CGPoint(x: cx - s * 0.32, y: cy + s * 0.24)
                )
                contour.addCurve(
                    to: CGPoint(x: cx, y: cy - s * 0.36),
                    control1: CGPoint(x: cx - s * 0.36, y: cy - s * 0.14),
                    control2: CGPoint(x: cx - s * 0.28, y: cy - s * 0.36)
                )
                contour.closeSubpath()
                StorybookArt.fillAndStroke(ctx, contour, fill: sc.color, stroke: Shades.outline(sc).color, width: 2.8)

                // Cute button nose dot in center
                var nose = Path()
                nose.move(to: CGPoint(x: cx - s * 0.05, y: cy + s * 0.02))
                nose.addQuadCurve(to: CGPoint(x: cx + s * 0.05, y: cy + s * 0.02), control: CGPoint(x: cx, y: cy + s * 0.10))
                ctx.stroke(nose, with: .color(Shades.outline(sc).color), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

                StorybookArt.sparkle(ctx, at: CGPoint(x: cx - s * 0.34, y: cy - s * 0.26), radius: 6, color: Theme.pink)
                StorybookArt.sparkle(ctx, at: CGPoint(x: cx + s * 0.34, y: cy + s * 0.26), radius: 6, color: Theme.lemon)
            }
        }
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
