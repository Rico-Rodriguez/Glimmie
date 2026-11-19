import SwiftUI

// MARK: - Pet corner: pick a pet, name it, feed, bathe, brush, play and tuck it in.
// Love only ever goes up. Nothing gets hungry or sad while she's away.

struct PetSave: Codable, Equatable {
    var names: [String: String] = [:]
    var love: [String: Int] = [:]
    var current = "p_kitty"

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        names = (try? c.decodeIfPresent([String: String].self, forKey: .names)) ?? [:]
        love = (try? c.decodeIfPresent([String: Int].self, forKey: .love)) ?? [:]
        current = (try? c.decodeIfPresent(String.self, forKey: .current)) ?? "p_kitty"
    }

    enum CodingKeys: String, CodingKey { case names, love, current }

    static let pets = ["p_kitty", "p_puppy", "p_bunny", "p_duck", "p_teddy", "p_unicorn"]
    static let defaultNames = ["p_kitty": "Mochi", "p_puppy": "Biscuit", "p_bunny": "Clover",
                               "p_duck": "Puddle", "p_teddy": "Honey", "p_unicorn": "Sprinkle"]
    static let nameIdeas = ["Mochi", "Biscuit", "Clover", "Puddle", "Honey", "Sprinkle", "Peaches", "Button", "Bubbles",
                            "Cupcake", "Marshmallow", "Pudding", "Noodle", "Pickle", "Sunny", "Pebble", "Waffles",
                            "Jellybean", "Cocoa", "Daisy", "Twinkle", "Snowball", "Muffin", "Pumpkin", "Coco",
                            "Lulu", "Taffy", "Bean", "Kiwi", "Maple", "Pip", "Star", "Sugar", "Tofu", "Ziggy"]

    func name(_ pet: String) -> String { names[pet] ?? Self.defaultNames[pet] ?? "Friend" }
}

final class PetStore: ObservableObject {
    @Published var save: PetSave { didSet { GameStorage.save(save, game: LookStore.game, file: "pets.json") } }
    init() {
        var s = GameStorage.load(PetSave.self, game: LookStore.game, file: "pets.json") ?? PetSave()
        if !PetSave.pets.contains(s.current) { s.current = PetSave.pets[0] }
        save = s
    }
}

private enum Care: String, CaseIterable, Identifiable {
    case feed, bath, brush, play, sleep
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .feed: return "fork.knife"
        case .bath: return "bubbles.and.sparkles.fill"
        case .brush: return "wand.and.stars"
        case .play: return "tennisball.fill"
        case .sleep: return "moon.zzz.fill"
        }
    }
    var tint: Color {
        switch self {
        case .feed: return Color(hex: 0xFFA24C)
        case .bath: return Color(hex: 0x5C9BEB)
        case .brush: return Color(hex: 0x9B79E0)
        case .play: return Color(hex: 0x6CCB8B)
        case .sleep: return Color(hex: 0x3C4A8C)
        }
    }
    var sound: SFX {
        switch self {
        case .feed: return .pop
        case .bath: return .bubble
        case .brush: return .sparkle
        case .play: return .boing
        case .sleep: return .note1
        }
    }
}

struct PetCornerView: View {
    let look: Look
    let close: () -> Void
    let takeAlong: (String) -> Void

    @StateObject private var pets = PetStore()
    @State private var action: Care?
    @State private var bounce = false
    @State private var burst = 0
    @State private var editingName = false
    @State private var draft = ""
    @FocusState private var nameFocused: Bool

    private var pet: String { pets.save.current }

    var body: some View {
        ZStack {
            SceneView(bg: "bg_garden").ignoresSafeArea()
            if action == .sleep { Color(hex: 0x2E2A6B).opacity(0.45).ignoresSafeArea().transition(.opacity) }
            DesignCanvas {
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 30) {
                        careColumn
                        stage
                        careColumnRight
                    }
                    .padding(.horizontal, 30)
                    Spacer(minLength: 10)
                    picker
                        .padding(.bottom, 22)
                }
            }
        }
        .onDisappear { if editingName { commitName() } }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            RoundButton(symbol: "chevron.down", tint: Theme.pink) {
                Sound.shared.play(.whoosh, volume: 0.6)
                close()
            }
            Spacer()
            nameTag
            Spacer()
            RoundButton(symbol: "hand.raised.fill", tint: Color(hex: 0xF45C9A)) {
                Sound.shared.play(.cheer)
                takeAlong(pet)
            }
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
                    .frame(width: 300)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit(commitName)
                Button(action: commitName) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(Color(hex: 0x6CCB8B))
                }
            } else {
                Text(pets.save.name(pet))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .onTapGesture {
                        draft = pets.save.name(pet)
                        editingName = true
                        nameFocused = true
                    }
                Button {
                    Sound.shared.play(.ding)
                    var n = PetSave.nameIdeas.randomElement() ?? "Mochi"
                    if n == pets.save.name(pet) { n = PetSave.nameIdeas.randomElement() ?? n }
                    pets.save.names[pet] = n
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
        if !n.isEmpty { pets.save.names[pet] = String(n.prefix(16)) }
        editingName = false
        nameFocused = false
    }

    private var hearts: some View {
        let love = pets.save.love[pet] ?? 0
        let filled = love % 5 == 0 && love > 0 ? 5 : love % 5
        return HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < filled ? "heart.fill" : "heart")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(i < filled ? Color(hex: 0xF45C9A) : Color(hex: 0xF45C9A).opacity(0.35))
            }
            if love >= 5 {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill").foregroundStyle(Theme.lemon)
                    Text("\(love / 5)").foregroundStyle(Theme.ink)
                }
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.85)))
    }

    private var stage: some View {
        VStack(spacing: 10) {
            hearts
            ZStack {
                Ellipse().fill(Theme.ink.opacity(0.16)).frame(width: 300, height: 44).offset(y: 200)
                ItemThumb(item: pet, look: look)
                    .frame(width: 440, height: 440)
                    .scaleEffect(x: 1, y: bounce ? 0.92 : 1, anchor: .bottom)
                    .offset(y: bounce ? -30 : 0)
                    .rotationEffect(.degrees(action == .sleep ? -6 : 0))
                    .onTapGesture { care(.play) }
                effects
                SparkleBurst(colors: [Color(hex: 0xF45C9A), .white, Theme.lemon]).id(burst).offset(y: -60)
            }
            .frame(width: 460, height: 460)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var effects: some View {
        switch action {
        case .feed?: FallingTreat().id(burst).offset(y: 40)
        case .bath?: Bubbles().id(burst)
        case .sleep?: Zzz().id(burst).offset(x: 120, y: -140)
        default: EmptyView()
        }
    }

    private var careColumn: some View {
        VStack(spacing: 22) { careButton(.feed); careButton(.bath); careButton(.brush) }
    }

    private var careColumnRight: some View {
        VStack(spacing: 22) { careButton(.play); careButton(.sleep) }
    }

    private func careButton(_ c: Care) -> some View {
        Button { care(c) } label: {
            Image(systemName: c.symbol)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 112, height: 112)
                .background(Circle().fill(c.tint.gradient))
                .overlay(Circle().stroke(.white, lineWidth: 6))
                .shadow(color: Theme.ink.opacity(0.25), radius: 8, y: 5)
        }
        .buttonStyle(Squish())
    }

    private func care(_ c: Care) {
        Sound.shared.play(c.sound)
        Sound.shared.tap()
        withAnimation(.easeInOut(duration: 0.3)) { action = c }
        burst += 1
        pets.save.love[pet, default: 0] += 1
        if (pets.save.love[pet] ?? 0) % 5 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { Sound.shared.play(.fanfare, volume: 0.8) }
        }
        let hops = c == .play ? 3 : (c == .sleep ? 0 : 1)
        for i in 0..<hops {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.34) {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { bounce = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { bounce = false }
                }
            }
        }
        let shown = burst
        DispatchQueue.main.asyncAfter(deadline: .now() + (c == .sleep ? 3.0 : 1.6)) {
            if burst == shown { withAnimation(.easeInOut(duration: 0.4)) { action = nil } }
        }
    }

    private var picker: some View {
        HStack(spacing: 16) {
            ForEach(PetSave.pets, id: \.self) { p in
                Button {
                    Sound.shared.play(.pop)
                    if editingName { commitName() }
                    withAnimation(.spring(response: 0.35)) { pets.save.current = p }
                    burst += 1
                } label: {
                    ItemThumb(item: p, look: look)
                        .padding(10)
                        .frame(width: 104, height: 104)
                        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white.opacity(0.92)))
                        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(p == pet ? Theme.pink : .white, lineWidth: p == pet ? 6 : 3))
                }
                .buttonStyle(Squish())
            }
        }
    }
}

// MARK: - Little effects

private struct FallingTreat: View {
    @State private var down = false
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0xE9B26A)).frame(width: 56, height: 56)
                .overlay(Circle().stroke(Color(hex: 0xB07A3A), lineWidth: 4))
                .overlay(HStack(spacing: 6) { ForEach(0..<3, id: \.self) { _ in Circle().fill(Color(hex: 0x6B4537)).frame(width: 8) } })
                .offset(y: down ? 60 : -260)
                .opacity(down ? 0 : 1)
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeIn(duration: 0.9)) { down = true } }
    }
}

private struct Bubbles: View {
    @State private var up = false
    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .background(Circle().fill(Color(hex: 0x9CCBFF).opacity(0.35)))
                    .frame(width: CGFloat(24 + (i % 4) * 12))
                    .offset(x: CGFloat((i * 53) % 300 - 150), y: up ? -260 - CGFloat(i * 12) : 120)
                    .opacity(up ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 1.5)) { up = true } }
    }
}

private struct Zzz: View {
    @State private var up = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("z").font(.system(size: 60, weight: .heavy, design: .rounded))
            Text("z").font(.system(size: 44, weight: .heavy, design: .rounded)).offset(x: -24)
            Text("z").font(.system(size: 30, weight: .heavy, design: .rounded)).offset(x: -40)
        }
        .foregroundStyle(.white)
        .offset(y: up ? -40 : 20)
        .opacity(up ? 1 : 0)
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { up = true } }
    }
}
