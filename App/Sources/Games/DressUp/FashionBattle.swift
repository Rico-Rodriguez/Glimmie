import SwiftUI

// MARK: - Fashion battle (offline): a theme, a rival doll, three animal judges.
// Kind by design: everyone gets stars, and dressing to the theme almost always wins.

struct BattleTheme: Identifiable, Equatable {
    let id: String
    let scene: String
    /// Items that fit the theme. Wearing them earns stars.
    let items: Set<String>
    /// Three items shown on the theme card as hints.
    let hints: [String]
    /// Pets that fit the theme when they sit at her feet (empty: any pet does).
    var pets: Set<String> = []

    static let all: [BattleTheme] = [
        BattleTheme(id: "beach", scene: "bg_beach",
                    items: ["sh_sandals", "h_sunhat", "g_sun", "d_sun", "b_shorts", "t_tank", "p_icecream", "h_shell", "d_mermaid", "t_crop", "p_umbrella", "g_heart"],
                    hints: ["h_sunhat", "d_sun", "sh_sandals"], pets: ["axolotl", "duckling", "penguin", "frog"]),
        BattleTheme(id: "princess", scene: "bg_castle",
                    items: ["h_crown", "h_tiara", "d_princess", "d_gown", "d_magic", "n_pearls", "p_wand", "sh_glitter", "w_fairy", "d_frilly", "h_starcrown", "er_pearl", "sh_ballet"],
                    hints: ["h_crown", "d_gown", "p_wand"], pets: ["unicorn", "kitty", "bunny", "dragon"]),
        BattleTheme(id: "snow", scene: "bg_snow",
                    items: ["h_beanie", "n_scarf", "o_jacket", "o_cardigan", "t_sweater", "t_turtle", "b_pants", "sh_boots", "s_tights", "t_hoodie", "b_leggings", "t_long", "s_knee"],
                    hints: ["h_beanie", "n_scarf", "sh_boots"], pets: ["penguin", "lamb", "redpanda", "fox", "owl"]),
        BattleTheme(id: "party", scene: "bg_stage",
                    items: ["d_party", "d_hearts", "d_star", "h_boppers", "p_balloon", "p_cupcake", "sh_glitter", "h_bigbow", "mk_glitter", "d_rainbow", "t_star", "b_tutu", "g_star"],
                    hints: ["h_boppers", "d_party", "p_balloon"], pets: ["puppy", "kitty", "piglet", "hamster", "unicorn"]),
        BattleTheme(id: "garden", scene: "bg_garden",
                    items: ["h_flowers", "h_sunflower", "p_bouquet", "p_flower", "w_butterfly", "d_tulip", "er_flower", "b_tiered", "d_aline", "sh_sandals"],
                    hints: ["h_flowers", "w_butterfly", "p_bouquet"], pets: ["bunny", "duckling", "fawn", "mouse", "frog"]),
        BattleTheme(id: "magic", scene: "bg_space",
                    items: ["h_witch", "d_magic", "w_bat", "mk_moon", "g_star", "e_star", "h_starcrown", "o_cape", "w_cape", "h_halo", "p_wand", "w_angel", "n_star", "er_star"],
                    hints: ["h_witch", "o_cape", "p_wand"], pets: ["dragon", "unicorn", "owl", "kitty"]),
        BattleTheme(id: "rain", scene: "bg_park",
                    items: ["o_raincoat", "sh_rain", "p_umbrella", "h_cap", "b_overalls", "sh_sneakers", "t_hoodie", "b_pants"],
                    hints: ["o_raincoat", "p_umbrella", "sh_rain"], pets: ["duckling", "frog", "puppy", "axolotl"]),
        BattleTheme(id: "animals", scene: "bg_forest",
                    items: ["h_cat", "h_bunny", "h_bear", "h_fox", "d_bunnypj", "sh_bunny", "p_teddy", "m_cat", "n_cat"],
                    hints: ["h_cat", "d_bunnypj", "sh_bunny"]),
        BattleTheme(id: "sweets", scene: "bg_candy",
                    items: ["p_cupcake", "p_lolly", "p_icecream", "d_frilly", "h_bigbow", "d_hearts", "b_bubble", "mk_heart", "b_hearts", "er_cherry", "s_stripes"],
                    hints: ["p_lolly", "p_cupcake", "d_frilly"], pets: ["bear", "piglet", "mouse", "hamster", "unicorn"]),
    ]

    /// How well a look fits: matching items, the matching scene, and a complete outfit.
    func points(_ look: Look) -> Int {
        var p = look.picks.values.filter { items.contains($0) }.count * 2
        if look.bg == scene { p += 1 }
        let dressed = look.picks["dress"] != nil || (look.picks["top"] != nil && look.picks["bottom"] != nil)
        if dressed { p += 1 }
        if look.picks["shoes"] != nil { p += 1 }
        if ["hat", "neck", "hold", "earrings", "glasses", "back"].contains(where: { look.picks[$0] != nil }) { p += 1 }
        if let pet = look.pet {
            // a pet always helps; one that fits the theme (or any pet at the animal show) helps more
            p += pets.isEmpty || pets.contains(pet.kind) ? 3 : 1
            if !pet.wear.isEmpty { p += 1 }
        }
        return p
    }

    /// Three judges' stars (each 1...5).
    func stars(_ look: Look, luck: [Int]) -> [Int] {
        let base = 2 + min(3, points(look) / 3)
        return (0..<3).map { min(5, max(1, base + luck[$0])) }
    }

    /// A rival who wears a couple of theme pieces, but not too many.
    func rival() -> Look {
        var l = Look.random().sanitized()
        let art = DressUpArt.shared
        for id in items.shuffled().prefix(Int.random(in: 1...2)) {
            if let it = art.items[id] { l.wear(id, in: it.category) }
        }
        l.bg = scene
        l.pet = nil
        if Double.random(in: 0..<1) < 0.5 {
            let kinds = pets.isEmpty ? PetArt.shared.order : Array(pets)
            if let k = kinds.randomElement() { l.pet = PetLook.random(kind: k) }
        }
        return l
    }
}

struct BattleSave: Codable {
    var wins = 0
    var shows = 0
}

enum BattlePhase: Equatable {
    case intro, dressing, runway
}

struct BattleState: Equatable {
    var theme: BattleTheme
    var rival: Look
    var phase: BattlePhase = .intro

    static func new() -> BattleState {
        let t = BattleTheme.all.randomElement()!
        return BattleState(theme: t, rival: t.rival())
    }
}

// MARK: Theme card

struct BattleIntroView: View {
    let state: BattleState
    let start: () -> Void
    let cancel: () -> Void
    let reroll: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: cancel)
            DesignCanvas {
                VStack(spacing: 22) {
                    HStack(spacing: 18) {
                        Image(systemName: "trophy.fill").foregroundStyle(Theme.lemon)
                        ZStack {
                            SceneView(bg: state.theme.scene)
                            HStack(spacing: 6) {
                                ForEach(state.theme.hints, id: \.self) { id in
                                    ItemThumb(item: id, look: state.rival)
                                        .padding(8)
                                        .frame(width: 110, height: 110)
                                        .background(Circle().fill(.white.opacity(0.92)))
                                }
                            }
                        }
                        .frame(width: 420, height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(.white, lineWidth: 8))
                        Image(systemName: "trophy.fill").foregroundStyle(Theme.lemon)
                    }
                    .font(.system(size: 60))

                    HStack(spacing: 40) {
                        VStack(spacing: 6) {
                            Text("VS")
                                .font(.system(size: 54, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: 0xF45C9A))
                        }
                        DollView(look: state.rival, box: DressUpView.stageBox)
                            .frame(width: 180, height: 253)
                            .background(Circle().fill(.white.opacity(0.7)).frame(width: 240, height: 240))
                    }

                    HStack(spacing: 28) {
                        RoundButton(symbol: "arrow.triangle.2.circlepath", tint: Color(hex: 0x9B79E0), size: 84) { reroll() }
                        Button(action: start) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 200, height: 100)
                                .background(Capsule().fill(Color(hex: 0x6CCB8B).gradient))
                                .overlay(Capsule().stroke(.white, lineWidth: 6))
                                .shadow(color: Theme.ink.opacity(0.3), radius: 10, y: 6)
                        }
                        .buttonStyle(Squish())
                        RoundButton(symbol: "xmark", tint: Theme.pink, size: 84) { cancel() }
                    }
                }
                .padding(40)
                .background(RoundedRectangle(cornerRadius: 50, style: .continuous).fill(Theme.cream.opacity(0.96)))
            }
        }
    }
}

/// Shown on the stage while she dresses for the theme.
struct BattleBanner: View {
    let state: BattleState
    let done: () -> Void
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                SceneView(bg: state.theme.scene)
                ItemThumb(item: state.theme.hints[0], look: state.rival).padding(10)
            }
            .frame(width: 92, height: 92)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 5))
            ForEach(state.theme.hints.dropFirst(), id: \.self) { id in
                ItemThumb(item: id, look: state.rival)
                    .padding(8)
                    .frame(width: 70, height: 70)
                    .background(Circle().fill(.white.opacity(0.9)))
            }
            Button(action: done) {
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 92)
                    .background(Circle().fill(Color(hex: 0x6CCB8B).gradient))
                    .overlay(Circle().stroke(.white, lineWidth: 5))
                    .scaleEffect(pulse ? 1.08 : 0.96)
            }
            .buttonStyle(Squish())
        }
        .padding(10)
        .background(Capsule().fill(.white.opacity(0.75)))
        .shadow(color: Theme.ink.opacity(0.2), radius: 8, y: 4)
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

// MARK: Runway

struct RunwayView: View {
    let state: BattleState
    let mine: Look
    let again: () -> Void
    let done: () -> Void

    @State private var shown = 0
    @State private var finished = false
    @State private var save = GameStorage.load(BattleSave.self, game: LookStore.game, file: "battle.json") ?? BattleSave()
    @State private var myStars: [Int] = []
    @State private var rivalStars: [Int] = []
    @State private var walkIn = false

    private static let judges = ["kitty", "puppy", "bunny"]

    private var myTotal: Int { myStars.prefix(shown).reduce(0, +) }
    private var rivalTotal: Int { rivalStars.prefix(shown).reduce(0, +) }
    private var iWin: Bool { myStars.reduce(0, +) >= rivalStars.reduce(0, +) }

    var body: some View {
        ZStack {
            SceneView(bg: state.theme.scene).ignoresSafeArea()
            DesignCanvas {
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 60) {
                        contestant(mine, stars: myTotal, winner: finished && iWin)
                            .offset(x: walkIn ? 0 : -700)
                        contestant(state.rival, stars: rivalTotal, winner: finished && !iWin)
                            .offset(x: walkIn ? 0 : 700)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    HStack(spacing: 28) {
                        judgesRow
                        // Kept in the layout from the start so nothing shifts when they appear,
                        // and beside the judges so they never cover one.
                        HStack(spacing: 18) {
                            RoundButton(symbol: "arrow.clockwise", tint: Color(hex: 0x9B79E0), size: 84) { again() }
                            RoundButton(symbol: "checkmark", tint: Color(hex: 0x6CCB8B), size: 84) { done() }
                        }
                        .opacity(finished ? 1 : 0)
                        .scaleEffect(finished ? 1 : 0.6)
                        .allowsHitTesting(finished)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .onAppear(perform: run)
    }

    private func contestant(_ look: Look, stars: Int, winner: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                if winner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(Theme.lemon)
                        .shadow(color: .orange.opacity(0.5), radius: 6)
                        .transition(.scale.combined(with: .move(edge: .top)))
                    SparkleBurst(colors: [Theme.lemon, .white, Theme.pink], count: 16, radius: 220)
                } else if finished {
                    Image(systemName: "rosette")
                        .font(.system(size: 60))
                        .foregroundStyle(Color(hex: 0x5C9BEB))
                        .transition(.scale)
                }
            }
            .frame(height: 76)
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(Theme.lemon)
                Text("\(stars)").foregroundStyle(Theme.ink)
            }
            .font(.system(size: 40, weight: .heavy, design: .rounded))
            .padding(.horizontal, 20).padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.9)))
            DollView(look: look, box: DressUpView.stageBox)
                .frame(width: 330, height: 464)
                .scaleEffect(winner ? 1.06 : 1, anchor: .bottom)
        }
    }

    private var judgesRow: some View {
        HStack(spacing: 40) {
            ForEach(0..<3, id: \.self) { i in
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        card(i < shown ? myStars[safe: i] : nil, tint: Color(hex: 0xF45C9A))
                        card(i < shown ? rivalStars[safe: i] : nil, tint: Color(hex: 0x5C9BEB))
                    }
                    PetThumb(pet: PetLook(kind: Self.judges[i]), box: CGRect(x: 60, y: 0, width: 480, height: 480),
                             pose: judgeFace(i))
                        .frame(width: 96, height: 96)
                        .offset(y: i == shown - 1 ? -10 : 0)
                }
            }
        }
        .padding(.horizontal, 30).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.85)))
    }

    /// Judges smile, and beam once they've shown a high score.
    private func judgeFace(_ i: Int) -> PetPose {
        var p = PetPose()
        if i < shown, (myStars[safe: i] ?? 0) >= 4 { p.eyes = "happy"; p.mouth = "grin" }
        return p
    }

    private func card(_ n: Int?, tint: Color) -> some View {
        Text(n.map(String.init) ?? "?")
            .font(.system(size: 34, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(n == nil ? tint.opacity(0.35) : tint))
    }

    private func run() {
        // her luck leans kind; the rival's is plain
        myStars = state.theme.stars(mine, luck: (0..<3).map { _ in [0, 0, 1].randomElement()! })
        rivalStars = state.theme.stars(state.rival, luck: (0..<3).map { _ in [-1, 0, 0].randomElement()! })
        Sound.shared.play(.whoosh)
        withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) { walkIn = true }
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 + Double(i) * 0.9) {
                Sound.shared.play([SFX.note1, .note2, .note3][i - 1])
                withAnimation(.spring(response: 0.35)) { shown = i }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            Sound.shared.play(iWin ? .fanfare : .cheer)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { finished = true }
            save.shows += 1
            if iWin { save.wins += 1 }
            GameStorage.save(save, game: LookStore.game, file: "battle.json")
        }
    }
}
