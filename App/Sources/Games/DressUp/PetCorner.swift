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

private enum PetTab: String, CaseIterable { case care, closet, pets }

/// The things on the care shelf, in order, with the section each starts.
private let careItems = ["fish", "bone", "carrot", "berry", "cookie", "cupcake",
                         "sponge", "shower", "towel", "brush", "ball", "yarn", "feather", "bed"]
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
                            hearts
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
        HStack {
            RoundButton(symbol: "chevron.down", tint: Theme.pink) {
                Sound.shared.play(.whoosh, volume: 0.6)
                close()
            }
            Spacer()
            nameTag
            Spacer()
            Button {
                if along {
                    Sound.shared.play(.whoosh)
                    takeAlong(nil)
                } else {
                    Sound.shared.play(.cheer)
                    takeAlong(pet)
                }
            } label: {
                Image(systemName: along ? "house.fill" : "hand.raised.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(along ? Color(hex: 0x6CCB8B) : Color(hex: 0xF45C9A)))
                    .overlay(Circle().stroke(.white, lineWidth: 5))
                    .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 4)
            }
            .buttonStyle(Squish())
        }
        .padding(.horizontal, 26)
        .padding(.top, 22)
    }

    private var nameTag: some View {
        HStack(spacing: 12) {
            if editingName {
                TextField("Name", text: $draft)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    .frame(width: 280)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit(commitName)
                Button(action: commitName) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(Color(hex: 0x6CCB8B))
                }
            } else {
                Text(store.save.name(kind))
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .onTapGesture {
                        draft = store.save.name(kind)
                        editingName = true
                        nameFocused = true
                    }
                Button {
                    Sound.shared.play(.ding)
                    var n = PetSave.nameIdeas.randomElement() ?? "Mochi"
                    if n == store.save.name(kind) { n = PetSave.nameIdeas.randomElement() ?? n }
                    store.save.names[kind] = n
                } label: {
                    Image(systemName: "dice.fill").font(.system(size: 30)).foregroundStyle(Color(hex: 0x9B79E0))
                }
                .buttonStyle(Squish())
            }
        }
        .padding(.horizontal, 26).padding(.vertical, 10)
        .background(Capsule().fill(.white.opacity(0.92)))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 4))
    }

    private func commitName() {
        let n = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { store.save.names[kind] = String(n.prefix(16)) }
        editingName = false
        nameFocused = false
    }

    private var hearts: some View {
        let love = store.save.love[kind] ?? 0
        let filled = love % 5 == 0 && love > 0 ? 5 : love % 5
        return HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < filled ? "heart.fill" : "heart")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(i < filled ? Color(hex: 0xF45C9A) : Color(hex: 0xF45C9A).opacity(0.35))
                    .scaleEffect(i == filled - 1 ? 1.15 : 1)
            }
            if love >= 5 {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill").foregroundStyle(Color(hex: 0xF2B83E))
                    Text("\(love / 5)").foregroundStyle(Theme.ink)
                }
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.85)))
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: love)
    }

    // MARK: The tray

    private var tray: some View {
        VStack(spacing: 14) {
            tabs
            switch tab {
            case .care: careShelf
            case .closet: closet
            case .pets: petPicker
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(.white.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(.white, lineWidth: 5))
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
        case .pets: PetThumb(pet: PetLook(kind: kind == "puppy" ? "kitty" : "puppy"), box: CGRect(x: 90, y: 30, width: 420, height: 420))
        }
    }

    private var dressedSample: PetLook {
        var p = pet
        if p.wear["hat"] == nil { p.wear["hat"] = "ph_party"; p.colors["hat"] = 16 }
        return p
    }

    // Care: snacks, bath things, toys and the bed. Drag one onto the pet, or tap it.
    private var careShelf: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(careItems, id: \.self) { id in careTile(id) }
        }
        .padding(4)
    }

    private func careTile(_ id: String) -> some View {
        let fav = foods.contains(id) && PetSave.favorites[kind] == id && (store.save.love[kind] ?? 0) >= 3
        return ZStack(alignment: .topTrailing) {
            Group {
                if id == "bed" {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(Color(hex: 0x6B6FD6))
                } else {
                    PetPropThumb(name: id).padding(10)
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(tileTint(id)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white, lineWidth: 3))
            if fav {
                // after a few hearts she learns what it likes best
                Image(systemName: "heart.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF45C9A))
                    .padding(6)
            }
        }
        .contentShape(Rectangle())
        .gesture(
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
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(6)
                                        .background(Circle().fill(Color(hex: 0xF45C9A)))
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
