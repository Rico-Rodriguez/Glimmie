import SwiftUI

// MARK: - Pet corner: 20 pets to name, dress, feed, bathe, brush, play with and tuck in.
// Love only ever goes up. Nothing gets hungry or sad while she's away, and a pet that "wants"
// something (the thought bubble) is only ever asking to play.

struct PetSave: Codable, Equatable {
    var names: [String: String] = [:]
    var love: [String: Int] = [:]
    var current = "kitty"
    /// Each pet's outfit.
    var outfits: [String: PetLook] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawNames = (try? c.decodeIfPresent([String: String].self, forKey: .names)) ?? [:]
        let rawLove = (try? c.decodeIfPresent([String: Int].self, forKey: .love)) ?? [:]
        // saves from before the pet corner rebuild used item ids ("p_kitty")
        names = Dictionary(rawNames.map { (Self.legacy[$0.key] ?? $0.key, $0.value) }, uniquingKeysWith: { a, _ in a })
        love = Dictionary(rawLove.map { (Self.legacy[$0.key] ?? $0.key, $0.value) }, uniquingKeysWith: { a, b in max(a, b) })
        let cur = (try? c.decodeIfPresent(String.self, forKey: .current)) ?? "kitty"
        current = Self.legacy[cur] ?? cur
        outfits = (try? c.decodeIfPresent([String: PetLook].self, forKey: .outfits)) ?? [:]
    }

    enum CodingKeys: String, CodingKey { case names, love, current, outfits }

    /// Old held-pet item ids -> pet kinds.
    static let legacy = ["p_kitty": "kitty", "p_puppy": "puppy", "p_bunny": "bunny", "p_duck": "duckling",
                         "p_teddy": "bear", "p_unicorn": "unicorn"]
    static var pets: [String] { PetArt.shared.order }
    static let defaultNames = ["kitty": "Mochi", "puppy": "Biscuit", "bunny": "Clover", "unicorn": "Sprinkle",
                               "duckling": "Puddle", "bear": "Honey", "dragon": "Ember", "fox": "Ginger",
                               "panda": "Bamboo", "hamster": "Peanut", "redpanda": "Maple", "owl": "Hoot",
                               "axolotl": "Bubbles", "piglet": "Truffle", "lamb": "Cotton", "frog": "Pickle",
                               "mouse": "Pip", "koala": "Gumdrop", "penguin": "Waddles", "fawn": "Daisy"]
    /// Every pet has a favorite snack: it gets extra happy (and extra hearts) when she finds it.
    static let favorites = ["kitty": "fish", "puppy": "bone", "bunny": "carrot", "unicorn": "cupcake",
                            "duckling": "berry", "bear": "cookie", "dragon": "cupcake", "fox": "berry",
                            "panda": "cookie", "hamster": "carrot", "redpanda": "berry", "owl": "fish",
                            "axolotl": "fish", "piglet": "cookie", "lamb": "carrot", "frog": "berry",
                            "mouse": "cookie", "koala": "berry", "penguin": "fish", "fawn": "carrot"]
    static let nameIdeas = ["Mochi", "Biscuit", "Clover", "Puddle", "Honey", "Sprinkle", "Peaches", "Button", "Bubbles",
                            "Cupcake", "Marshmallow", "Pudding", "Noodle", "Pickle", "Sunny", "Pebble", "Waffles",
                            "Jellybean", "Cocoa", "Daisy", "Twinkle", "Snowball", "Muffin", "Pumpkin", "Coco",
                            "Lulu", "Taffy", "Bean", "Kiwi", "Maple", "Pip", "Star", "Sugar", "Tofu", "Ziggy",
                            "Ember", "Bamboo", "Gumdrop", "Hoot", "Waddles", "Cotton", "Truffle", "Peanut", "Ginger"]

    func name(_ pet: String) -> String { names[pet] ?? Self.defaultNames[pet] ?? "Friend" }
    func look(_ pet: String) -> PetLook { outfits[pet] ?? PetLook(kind: pet) }
}

final class PetStore: ObservableObject {
    @Published var save: PetSave { didSet { GameStorage.save(save, game: LookStore.game, file: "pets.json") } }
    init() {
        var s = GameStorage.load(PetSave.self, game: LookStore.game, file: "pets.json") ?? PetSave()
        if !PetSave.pets.contains(s.current) { s.current = PetSave.pets.first ?? "kitty" }
        s.outfits = s.outfits.compactMapValues { $0.sanitized() }
        save = s
    }
}

private enum PetTab: String, CaseIterable { case care, closet, salon, pets }

private let foods: Set<String> = ["fish", "bone", "carrot", "berry", "cookie", "cupcake"]

struct PetCornerView: View {
    let look: Look
    let close: () -> Void
    /// Sends a pet to sit at her feet (nil: back home).
    let takeAlong: (PetLook?) -> Void
    /// The pet at her feet changed clothes.
    let restyle: (PetLook) -> Void

    @StateObject private var store = PetStore()
    @State private var life = PetLife()
    @State private var tab: PetTab = .care
    @State private var slot = "hat"
    @State private var bigBurst = 0
    @State private var editingName = false
    @State private var draft = ""
    @FocusState private var nameFocused: Bool

    private let art = PetArt.shared
    private var kind: String { store.save.current }
    private var pet: PetLook { store.save.look(kind) }
    private var along: Bool { look.pet?.kind == kind }

    var body: some View {
        ZStack {
            SceneView(bg: "bg_garden").ignoresSafeArea()
            DesignCanvas {
                GeometryReader { geo in
                    let leftW = geo.size.width - PetLife.trayW - 36
                    ZStack(alignment: .topLeading) {
                        TimelineView(.animation) { tl in
                            Canvas { ctx, size in
                                life.frame(tl.date.timeIntervalSinceReferenceDate, pet: pet, size: size, in: ctx)
                            }
                        }
                        .allowsHitTesting(false)
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: leftW, height: geo.size.height)
                            .gesture(stageGesture)
                        VStack(spacing: 10) {
                            topBar
                            if editingName {
                                nameEditor
                                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                            }
                        }
                        .frame(width: leftW)
                        SparkleBurst(colors: [Color(hex: 0xF45C9A), .white, Theme.lemon], count: 18, radius: 240)
                            .id(bigBurst)
                            .position(x: leftW / 2, y: 380)
                        tray
                            .frame(width: PetLife.trayW, height: geo.size.height - 36)
                            .offset(x: geo.size.width - PetLife.trayW - 18, y: 18)
                    }
                    .coordinateSpace(name: "corner")
                }
            }
        }
        .onAppear(perform: start)
        .onDisappear { if editingName { commitName() } }
    }

    // MARK: Setup

    private func start() {
        life.reset(kind: kind)
        life.onLove = { n, wanted in addLove(n, wanted: wanted) }
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-petDemo"), i + 1 < args.count {
            // simulator screenshot hooks: -petDemo dressed | closet | pets | foam | sleep | feed
            let mode = args[i + 1]
            if mode != "foam" && mode != "sleep" && mode != "feed" {
                var p = PetLook.random(kind: kind)
                p.wear["hat"] = "ph_crown"; p.wear["neck"] = "pn_bowtie"; p.wear["body"] = "pb_sweater"
                store.save.outfits[kind] = p.sanitized()
            }
            switch mode {
            case "closet": tab = .closet
            case "salon":
                tab = .salon
                var p = store.save.look(kind)
                p.dye = 6; p.nails = 4; p.glitter = true; p.cheek = "heart"
                store.save.outfits[kind] = p
            case "pets": tab = .pets
            default: break
            }
            life.demo(mode)
        }
    }

    private func addLove(_ n: Int, wanted: Bool) {
        guard n > 0 else { return }
        let before = store.save.love[kind] ?? 0
        store.save.love[kind] = before + n
        DressUpFind.petBestie.unlock()
        if (before + n) / 5 > before / 5 || wanted {
            bigBurst += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { Sound.shared.play(.fanfare, volume: 0.8) }
        }
    }

    private func setPet(_ p: PetLook) {
        store.save.outfits[kind] = p
        if along { restyle(p) }
    }

    // MARK: Stage touches: pet her, tap her, kick the ball

    private var stageGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("corner"))
            .onChanged { v in life.touch(v.location, start: v.startLocation) }
            .onEnded { v in life.release(v.location, start: v.startLocation, predicted: v.predictedEndLocation) }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            RoundButton(symbol: "chevron.down", tint: Theme.pink, size: GameChromeLayout.buttonSize) {
                Sound.shared.play(.whoosh, volume: 0.6)
                close()
            }
            Spacer(minLength: 6)
            hearts
            Spacer(minLength: 6)
            RoundButton(symbol: "pencil", tint: Color(hex: 0x9B79E0), size: 52) {
                Sound.shared.play(.tap)
                if editingName {
                    commitName()
                } else {
                    draft = store.save.name(kind)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { editingName = true }
                    nameFocused = true
                }
            }
            Button {
                if along {
                    Sound.shared.play(.whoosh)
                    takeAlong(nil)
                } else {
                    Sound.shared.play(.cheer)
                    takeAlong(pet)
                }
            } label: {
                ZStack {
                    Circle().fill(along ? Color(hex: 0x6CCB8B) : Color(hex: 0xF45C9A))
                    Image(systemName: along ? "pawprint.circle.fill" : "figure.stand")
                        .font(.system(size: along ? 30 : 27, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: GameChromeLayout.buttonSize, height: GameChromeLayout.buttonSize)
                .overlay(Circle().stroke(.white, lineWidth: 4.5))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: along ? "checkmark.circle.fill" : "pawprint.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(along ? .white : Theme.lemon)
                        .background(Circle().fill(along ? Color(hex: 0x45A868) : Color(hex: 0xD94580)).padding(2))
                        .offset(x: 3, y: 3)
                }
                .shadow(color: Theme.ink.opacity(0.24), radius: 6, y: 4)
            }
            .buttonStyle(Squish())
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var nameEditor: some View {
        HStack(spacing: 10) {
            TextField("", text: $draft)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)
                .frame(width: 220)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit(commitName)
            Button {
                Sound.shared.play(.ding)
                var n = PetSave.nameIdeas.randomElement() ?? "Mochi"
                if n == draft { n = PetSave.nameIdeas.randomElement() ?? n }
                draft = n
                store.save.names[kind] = n
            } label: {
                Image(systemName: "dice.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color(hex: 0x9B79E0))
            }
            .buttonStyle(Squish())
            Button {
                Sound.shared.play(.whoosh, volume: 0.5)
                withAnimation(.spring(response: 0.3)) { editingName = false }
                nameFocused = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.pink)
            }
            .buttonStyle(Squish())
            Button(action: commitName) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: 0x6CCB8B))
            }
            .buttonStyle(Squish())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Capsule().fill(Theme.cream.opacity(0.96)))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 3.5))
        .shadow(color: Theme.ink.opacity(0.18), radius: 10, y: 5)
    }

    private func commitName() {
        let n = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { store.save.names[kind] = String(n.prefix(16)) }
        withAnimation(.spring(response: 0.3)) { editingName = false }
        nameFocused = false
    }

    private var hearts: some View {
        let love = store.save.love[kind] ?? 0
        let filled = love % 5 == 0 && love > 0 ? 5 : love % 5
        let crowns = min(5, love / 5)
        return HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < filled ? "heart.fill" : "heart")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(i < filled ? Color(hex: 0xF45C9A) : Color(hex: 0xF45C9A).opacity(0.32))
                    .scaleEffect(i == filled - 1 ? 1.14 : 1)
            }
            if crowns > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<crowns, id: \.self) { _ in
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color(hex: 0xF2B83E))
                            .shadow(color: Color(hex: 0xD98D26).opacity(0.35), radius: 1, y: 1)
                    }
                }
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Theme.cream.opacity(0.95)))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 3.5))
        .shadow(color: Theme.ink.opacity(0.14), radius: 6, y: 3)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: love)
    }

    // MARK: The tray

    private var tray: some View {
        VStack(spacing: 14) {
            tabs
            switch tab {
            case .care: careShelf
            case .closet: closet
            case .salon: salon
            case .pets: petPicker
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Theme.cream.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(Theme.blush, lineWidth: 4))
        .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
    }

    private var tabs: some View {
        HStack(spacing: 10) {
            ForEach(PetTab.allCases, id: \.self) { t in
                Button {
                    Sound.shared.play(.tap)
                    if editingName { commitName() }
                    tab = t
                } label: {
                    tabIcon(t)
                        .frame(width: 76, height: 76)
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(tab == t ? Theme.pink.opacity(0.9) : Theme.blush.opacity(0.7)))
                }
                .buttonStyle(Squish())
            }
        }
    }

    @ViewBuilder private func tabIcon(_ t: PetTab) -> some View {
        switch t {
        case .care: PetPropThumb(name: "bone").padding(6)
        case .closet: PetThumb(pet: dressedSample, box: CGRect(x: 100, y: -20, width: 400, height: 420))
        case .salon:
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
        case .pets: PetThumb(pet: PetLook(kind: kind == "puppy" ? "kitty" : "puppy"), box: CGRect(x: 90, y: 30, width: 420, height: 420))
        }
    }

    private var dressedSample: PetLook {
        var p = pet
        if p.wear["hat"] == nil { p.wear["hat"] = "ph_party"; p.colors["hat"] = 16 }
        return p
    }

    private static let careGroups: [(items: [String], columns: Int, bg: Color, border: Color)] = [
        (["fish", "bone", "carrot", "berry", "cookie", "cupcake"], 3, Color(hex: 0xFFF5E6), Color(hex: 0xF7D7B2)),
        (["sponge", "shower", "towel", "brush"], 4, Color(hex: 0xECF6FF), Color(hex: 0xC6E1FA)),
        (["ball", "yarn", "feather"], 3, Color(hex: 0xE9FAF3), Color(hex: 0xBCEBD9)),
        (["bed"], 1, Color(hex: 0xF1EDFF), Color(hex: 0xD4C8FA)),
    ]

    // Care: snacks, bath things, toys and the bed, grouped in tidy pastel sections.
    private var careShelf: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(0..<Self.careGroups.count, id: \.self) { gIdx in
                    let group = Self.careGroups[gIdx]
                    let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: group.columns)
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(group.items, id: \.self) { id in
                            careTile(id, compact: group.columns == 4)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(group.bg))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(group.border, lineWidth: 2.5))
                }
            }
            .padding(4)
        }
    }

    private func careTile(_ id: String, compact: Bool = false) -> some View {
        let fav = foods.contains(id) && PetSave.favorites[kind] == id && (store.save.love[kind] ?? 0) >= 3
        let tileHeight: CGFloat = id == "bed" ? 76 : (compact ? 82 : 86)
        return ZStack(alignment: .topTrailing) {
            Group {
                if id == "bed" {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color(hex: 0x6B6FD6))
                } else {
                    PetPropThumb(name: id).padding(compact ? 6 : 8)
                }
            }
            .frame(height: tileHeight)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(tileTint(id), lineWidth: 3))
            if fav {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF45C9A))
                    .padding(5)
            }
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("corner"))
                .onChanged { v in life.trayChanged(id, v.location, translation: v.translation) }
                .onEnded { v in life.trayEnded(id, v.location, predicted: v.predictedEndLocation) }
        )
    }

    private func tileTint(_ id: String) -> Color {
        if foods.contains(id) { return Color(hex: 0xFFF1DC) }
        switch id {
        case "sponge", "shower", "towel": return Color(hex: 0xE3F1FF)
        case "brush": return Color(hex: 0xEEE6FF)
        case "bed": return Color(hex: 0xE6E4FF)
        default: return Color(hex: 0xDDF5EC)
        }
    }

    // Closet: what the pet wears, in five places, in any color.
    private var closet: some View {
        VStack(spacing: 12) {
            slotChips
            ScrollView(showsIndicators: false) {
                wearGrid
            }
            .frame(maxHeight: .infinity)
            wearColors
        }
    }

    private var slotChips: some View {
        HStack(spacing: 8) {
            ForEach(art.slots, id: \.self) { s in
                Button {
                    Sound.shared.play(.tap, volume: 0.7)
                    slot = s
                } label: {
                    PetThumb(pet: chipPet(s), box: art.thumbs[s])
                        .padding(4)
                        .frame(width: 62, height: 62)
                        .background(Circle().fill(.white))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(slot == s ? Theme.pink : Theme.blush, lineWidth: slot == s ? 5 : 3))
                }
                .buttonStyle(Squish())
            }
            Button {
                Sound.shared.play(.sparkle)
                Sound.shared.tap()
                setPet(PetLook.random(kind: kind))
                life.cheer()
            } label: {
                Image(systemName: "dice.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(Color(hex: 0x9B79E0)))
            }
            .buttonStyle(Squish())
        }
    }

    /// The pet wearing only what's on it in `s` (or a sample there), for a chip.
    private func chipPet(_ s: String) -> PetLook {
        var p = PetLook(kind: kind)
        let sample = ["hat": "ph_bow", "glasses": "pg_heart", "neck": "pn_bowtie", "body": "pb_sweater", "back": "pk_butterfly"]
        p.wear[s] = pet.wear[s] ?? sample[s]
        if let c = pet.colors[s] { p.colors[s] = c }
        if let pt = pet.patterns[s] { p.patterns[s] = pt }
        return p
    }

    private var wearGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        let selected = pet.wear[slot]
        return LazyVGrid(columns: cols, spacing: 10) {
            wearCell(selected: selected == nil) {
                Image(systemName: "xmark")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Theme.pink.opacity(0.7))
            } action: {
                Sound.shared.play(.whoosh, volume: 0.6)
                var p = pet
                p.wear[slot] = nil
                p.colors[slot] = nil
                p.patterns[slot] = nil
                setPet(p)
            }
            ForEach(art.bySlot[slot] ?? [], id: \.self) { id in
                wearCell(selected: selected == id) {
                    PetThumb(pet: trying(id), box: art.thumbs[slot])
                } action: {
                    Sound.shared.play(.pop)
                    Sound.shared.tap()
                    var p = pet
                    if p.wear[slot] != id { p.colors[slot] = nil; p.patterns[slot] = nil }
                    p.wear[slot] = id
                    setPet(p)
                    life.cheer()
                }
            }
        }
        .padding(4)
    }

    private func trying(_ id: String) -> PetLook {
        var p = PetLook(kind: kind)
        p.wear[slot] = id
        if pet.wear[slot] == id {
            p.colors[slot] = pet.colors[slot]
            p.patterns[slot] = pet.patterns[slot]
        }
        return p
    }

    private func wearCell<Content: View>(selected: Bool, @ViewBuilder content: () -> Content,
                                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            content()
                .padding(4)
                .frame(height: 104)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(selected ? Theme.blush : Color(hex: 0xFFF7FA)))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(selected ? Theme.pink : Color(hex: 0xF5DDE8), lineWidth: selected ? 6 : 3))
        }
        .buttonStyle(Squish())
    }

    @ViewBuilder private var wearColors: some View {
        if let id = pet.wear[slot], let item = art.wear[id] {
            let cloth = DressUpArt.shared.cloth
            let current = pet.colorIndex(slot)
            VStack(spacing: 6) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cloth.indices, id: \.self) { i in
                                Button {
                                    Sound.shared.play(.ding, volume: 0.6)
                                    var p = pet
                                    p.colors[slot] = i
                                    setPet(p)
                                } label: {
                                    Circle()
                                        .fill(cloth[i].color)
                                        .frame(width: 46, height: 46)
                                        .overlay(Circle().stroke(Shades.outline(cloth[i]).color.opacity(0.5), lineWidth: 2))
                                        .overlay(Circle().stroke(.white, lineWidth: current == i ? 5 : 0).padding(3))
                                        .overlay(Circle().stroke(Theme.pink, lineWidth: current == i ? 4 : 0).padding(-3))
                                        .padding(4)
                                }
                                .buttonStyle(Squish())
                                .id(i)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .onAppear { proxy.scrollTo(current, anchor: .center) }
                }
                .frame(height: 58)
                if item.patternable { patternRow(item) }
            }
        }
    }

    private func patternRow(_ item: PetWearItem) -> some View {
        let names = ["none"] + DressUpArt.shared.patternNames
        let current = pet.patterns[slot] ?? "none"
        let base = pet.paints(for: item).main
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(names, id: \.self) { name in
                    Button {
                        Sound.shared.play(.ding, volume: 0.6)
                        var p = pet
                        p.patterns[slot] = name == "none" ? nil : name
                        setPet(p)
                    } label: {
                        PatternSwatch(name: name, base: base)
                            .frame(width: 46, height: 46)
                            .overlay(Circle().stroke(Theme.pink, lineWidth: current == name ? 4 : 0).padding(-3))
                            .padding(4)
                    }
                    .buttonStyle(Squish())
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 58)
    }

    // Salon: fur dye, nail polish, sparkle fur and cheek stickers.
    private var salon: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                salonHeader("drop.fill", Color(hex: 0xFF8FB8))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    salonButton(selected: pet.dye == nil, action: { pamper { $0.dye = nil } }) {
                        Image(systemName: "xmark").font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.pink.opacity(0.7))
                    }
                    ForEach(0...PetPainter.dyes.count, id: \.self) { i in
                        salonButton(selected: pet.dye == i, action: { pamper { $0.dye = i } }) { DyeBottle(index: i) }
                    }
                }
                salonHeader("hand.raised.fingers.spread.fill", Color(hex: 0xF45C9A))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    salonButton(selected: pet.nails == nil, action: { pamper { $0.nails = nil } }) {
                        Image(systemName: "xmark").font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.pink.opacity(0.7))
                    }
                    ForEach(Self.polishes, id: \.self) { i in
                        salonButton(selected: pet.nails == i, action: { pamper { $0.nails = i } }) {
                            PolishBottle(color: DressUpArt.shared.cloth[safe: i] ?? Shades.white)
                        }
                    }
                }
                salonHeader("sparkles", Color(hex: 0x9B79E0))
                HStack(spacing: 10) {
                    salonButton(selected: pet.glitter, action: { pamper { $0.glitter.toggle() } }) {
                        Image(systemName: "sparkles").font(.system(size: 34, weight: .bold)).foregroundStyle(Color(hex: 0xF2B83E))
                    }
                    salonButton(selected: pet.cheek == nil, action: { pamper { $0.cheek = nil } }) {
                        Image(systemName: "face.smiling").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.pink.opacity(0.7))
                    }
                    salonButton(selected: pet.cheek == "heart", action: { pamper { $0.cheek = "heart" } }) {
                        Image(systemName: "heart.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(Color(hex: 0xFF6F96))
                    }
                    salonButton(selected: pet.cheek == "star", action: { pamper { $0.cheek = "star" } }) {
                        Image(systemName: "star.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(Color(hex: 0xF2B83E))
                    }
                }
            }
            .padding(4)
        }
    }

    private static let polishes = [3, 4, 5, 8, 9, 12, 16, 19, 20]

    private func pamper(_ change: (inout PetLook) -> Void) {
        var p = pet
        change(&p)
        Sound.shared.play(.sparkle)
        Sound.shared.tap()
        setPet(p)
        life.pamper()
    }

    private func salonHeader(_ symbol: String, _ tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(tint)
            .padding(.leading, 6)
    }

    private func salonButton<Content: View>(selected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .frame(width: 62, height: 62)
                .background(Circle().fill(selected ? Theme.blush : Color(hex: 0xFFF7FA)))
                .overlay(Circle().stroke(selected ? Theme.pink : Color(hex: 0xF5DDE8), lineWidth: selected ? 5 : 3))
        }
        .buttonStyle(Squish())
    }

    // Pets: all twenty, each in its own outfit.
    private var petPicker: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        return ScrollView(showsIndicators: false) {
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(PetSave.pets, id: \.self) { p in
                    Button {
                        Sound.shared.play(.pop)
                        if editingName { commitName() }
                        store.save.current = p
                        life.reset(kind: p)
                        life.cheer()
                    } label: {
                        PetThumb(pet: store.save.look(p), box: CGRect(x: 40, y: -10, width: 520, height: 660))
                            .padding(4)
                            .frame(height: 104)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(p == kind ? Theme.blush : Color(hex: 0xFFF7FA)))
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(p == kind ? Theme.pink : Color(hex: 0xF5DDE8), lineWidth: p == kind ? 6 : 3))
                            .overlay(alignment: .topTrailing) {
                                if look.pet?.kind == p {
                                    Image(systemName: "pawprint.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(5)
                                        .background(Circle().fill(Color(hex: 0x6CCB8B)))
                                        .overlay(Circle().stroke(.white, lineWidth: 2))
                                        .offset(x: 4, y: -4)
                                }
                            }
                    }
                    .buttonStyle(Squish())
                }
            }
            .padding(6)
        }
    }
}

/// A curved storybook bottle of fur dye.
private struct DyeBottle: View {
    let index: Int
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cap = Path(roundedRect: CGRect(x: w * 0.36, y: h * 0.1, width: w * 0.28, height: h * 0.2), cornerRadius: w * 0.08)
            StorybookArt.fillAndStroke(
                ctx,
                cap,
                fill: StorybookArt.color(0xEFE8FA),
                stroke: StorybookArt.outline(for: 0xC9B6FF),
                width: 2.2
            )
            StorybookArt.highlight(ctx, in: CGRect(x: w * 0.4, y: h * 0.13, width: w * 0.07, height: h * 0.12), opacity: 0.75)

            var body = Path()
            body.move(to: CGPoint(x: w * 0.34, y: h * 0.28))
            body.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.28), control: CGPoint(x: w * 0.5, y: h * 0.25))
            body.addCurve(to: CGPoint(x: w * 0.8, y: h * 0.78), control1: CGPoint(x: w * 0.8, y: h * 0.38), control2: CGPoint(x: w * 0.84, y: h * 0.62))
            body.addQuadCurve(to: CGPoint(x: w * 0.2, y: h * 0.78), control: CGPoint(x: w * 0.5, y: h * 0.92))
            body.addCurve(to: CGPoint(x: w * 0.34, y: h * 0.28), control1: CGPoint(x: w * 0.16, y: h * 0.62), control2: CGPoint(x: w * 0.2, y: h * 0.38))
            body.closeSubpath()

            var clipped = ctx
            clipped.clip(to: body)
            clipped.translateBy(x: w * 0.18, y: h * 0.26)
            clipped.scaleBy(x: w * 0.64 / 600, y: h * 0.64 / 660)
            if let shade = PetPainter.dyeSwatch(index) {
                clipped.fill(Path(CGRect(x: 0, y: 0, width: 600, height: 660)), with: shade)
            }
            let outline: Color
            if let rgb = PetPainter.dyes[safe: index] {
                outline = Shades.outline(rgb).color
            } else {
                outline = StorybookArt.outline(for: 0xFF8FB8)
            }
            ctx.stroke(body, with: .color(outline), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            StorybookArt.highlight(ctx, in: CGRect(x: w * 0.27, y: h * 0.39, width: w * 0.12, height: h * 0.26), opacity: 0.62)
        }
    }
}

/// A curved storybook bottle of nail polish.
private struct PolishBottle: View {
    let color: RGB
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cap = Path(roundedRect: CGRect(x: w * 0.38, y: h * 0.09, width: w * 0.24, height: h * 0.32), cornerRadius: w * 0.07)
            StorybookArt.fillAndStroke(
                ctx,
                cap,
                fill: StorybookArt.color(0x6C4D80),
                stroke: StorybookArt.outline(for: 0x5B3A68),
                width: 2.2
            )
            StorybookArt.highlight(ctx, in: CGRect(x: w * 0.42, y: h * 0.13, width: w * 0.055, height: h * 0.22), opacity: 0.42)

            var jar = Path()
            jar.move(to: CGPoint(x: w * 0.33, y: h * 0.39))
            jar.addQuadCurve(to: CGPoint(x: w * 0.67, y: h * 0.39), control: CGPoint(x: w * 0.5, y: h * 0.35))
            jar.addCurve(to: CGPoint(x: w * 0.77, y: h * 0.82), control1: CGPoint(x: w * 0.77, y: h * 0.48), control2: CGPoint(x: w * 0.79, y: h * 0.68))
            jar.addQuadCurve(to: CGPoint(x: w * 0.23, y: h * 0.82), control: CGPoint(x: w * 0.5, y: h * 0.92))
            jar.addCurve(to: CGPoint(x: w * 0.33, y: h * 0.39), control1: CGPoint(x: w * 0.21, y: h * 0.68), control2: CGPoint(x: w * 0.23, y: h * 0.48))
            jar.closeSubpath()
            StorybookArt.fillAndStroke(ctx, jar, fill: color.color, stroke: Shades.outline(color).color, width: 2.4)
            StorybookArt.highlight(ctx, in: CGRect(x: w * 0.3, y: h * 0.48, width: w * 0.11, height: h * 0.23), opacity: 0.65)
        }
    }
}
