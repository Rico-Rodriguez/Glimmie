import SwiftUI

struct BattleTheme: Identifiable, Equatable {
    let id: String
    let scene: String
    let items: Set<String>
    let hints: [String]
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

    func points(_ look: Look) -> Int {
        var p = look.picks.values.filter { items.contains($0) }.count * 2
        if look.bg == scene { p += 1 }
        let dressed = look.picks["dress"] != nil || (look.picks["top"] != nil && look.picks["bottom"] != nil)
        if dressed { p += 1 }
        if look.picks["shoes"] != nil { p += 1 }
        if ["hat", "neck", "hold", "earrings", "glasses", "back"].contains(where: { look.picks[$0] != nil }) { p += 1 }
        if look.makeup.contains(where: \.hasPoints) { p += 1 }
        if look.nails.contains(where: \.hasArt) { p += 1 }
        if let pet = look.pet {
            p += pets.isEmpty || pets.contains(pet.kind) ? 3 : 1
            if !pet.wear.isEmpty { p += 1 }
        }
        return p
    }

    func stars(_ look: Look, luck: [Int]) -> [Int] {
        let base = 2 + min(3, points(look) / 3)
        return (0..<3).map { min(5, max(1, base + luck[$0])) }
    }

    /// Play coins earned from a runway show (3...5 coins: everyone earns, higher stars earn more).
    static func coinReward(stars: [Int], won: Bool) -> Int {
        let avg = stars.isEmpty ? 1 : Int((Double(stars.reduce(0, +)) / Double(stars.count)).rounded())
        let tier = won ? max(2, min(3, avg - 2)) : max(1, min(2, avg - 2))
        return Coins.reward(stars: tier)
    }

    @discardableResult
    static func awardRunway(stars: [Int], won: Bool, from: CGPoint = CGPoint(x: 340, y: 390)) -> Int {
        let reward = coinReward(stars: stars, won: won)
        Coins.shared.earn(reward, game: LookStore.game, from: from)
        DressUpFind.runwayStar.unlock()
        return reward
    }

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

// MARK: - Theme card

struct BattleIntroView: View {
    let state: BattleState
    var mine: Look? = nil
    let start: () -> Void
    let cancel: () -> Void
    let reroll: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: cancel)
            DesignCanvas {
                VStack(spacing: 20) {
                    HStack(spacing: 18) {
                        Image(systemName: "trophy.fill").foregroundStyle(Theme.lemon)
                        ZStack {
                            SceneView(bg: state.theme.scene)
                            HStack(spacing: 6) {
                                ForEach(state.theme.hints, id: \.self) { id in
                                    ItemThumb(item: id, look: state.rival)
                                        .padding(8)
                                        .frame(width: 110, height: 110)
                                        .background(Circle().fill(.white.opacity(0.94)))
                                        .overlay(Circle().stroke(Theme.blush, lineWidth: 3))
                                }
                            }
                        }
                        .frame(width: 420, height: 224)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(.white, lineWidth: 7))
                        Image(systemName: "trophy.fill").foregroundStyle(Theme.lemon)
                    }
                    .font(.system(size: 56))

                    HStack(spacing: 28) {
                        if let mine {
                            DollView(look: mine, expression: .happy, box: DressUpView.stageBox)
                                .frame(width: 174, height: 244)
                                .background(
                                    Circle()
                                        .fill(Color(hex: 0xFFF3F8))
                                        .overlay(Circle().stroke(Theme.pink.opacity(0.6), lineWidth: 4))
                                        .frame(width: 220, height: 220)
                                )
                        }
                        BattleStarEmblem()
                            .frame(width: 112, height: 112)
                        DollView(look: state.rival, box: DressUpView.stageBox)
                            .frame(width: 174, height: 244)
                            .background(
                                Circle()
                                    .fill(Color(hex: 0xEEF5FF))
                                    .overlay(Circle().stroke(Theme.sky.opacity(0.7), lineWidth: 4))
                                    .frame(width: 220, height: 220)
                            )
                    }

                    HStack(spacing: 28) {
                        RoundButton(symbol: "arrow.triangle.2.circlepath", tint: Color(hex: 0x9B79E0), size: 80) { reroll() }
                        Button(action: start) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 196, height: 94)
                                .background(Capsule().fill(Color(hex: 0x6CCB8B).gradient))
                                .overlay(Capsule().stroke(.white, lineWidth: 6))
                                .shadow(color: Theme.ink.opacity(0.28), radius: 10, y: 6)
                        }
                        .buttonStyle(Squish())
                        RoundButton(symbol: "xmark", tint: Theme.pink, size: 80) { cancel() }
                    }
                }
                .padding(36)
                .background(RoundedRectangle(cornerRadius: 48, style: .continuous).fill(Theme.cream.opacity(0.96)))
                .overlay(RoundedRectangle(cornerRadius: 48, style: .continuous).stroke(Theme.blush, lineWidth: 5))
                .shadow(color: Theme.ink.opacity(0.24), radius: 20, y: 10)
            }
        }
    }
}

private struct BattleStarEmblem: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let pulse = 1 + 0.06 * sin(t * 3.4)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                var g = ctx
                g.translateBy(x: c.x, y: c.y)
                g.scaleBy(x: CGFloat(pulse), y: CGFloat(pulse))

                let halo = Path(ellipseIn: CGRect(x: -50, y: -50, width: 100, height: 100))
                g.fill(
                    halo,
                    with: .radialGradient(
                        Gradient(colors: [Theme.lemon.opacity(0.55), Theme.pink.opacity(0.2), .clear]),
                        center: .zero,
                        startRadius: 8,
                        endRadius: 50
                    )
                )

                var burst = Path()
                for k in 0..<12 {
                    let a = Double(k) * .pi / 6 + t * 0.45
                    let r: CGFloat = k.isMultiple(of: 2) ? 40 : 24
                    let pt = CGPoint(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
                    if k == 0 { burst.move(to: pt) } else { burst.addLine(to: pt) }
                }
                burst.closeSubpath()
                StorybookArt.fillAndStroke(
                    g,
                    burst,
                    fill: StorybookArt.color(0xFF9AC0),
                    stroke: StorybookArt.outline(for: 0xF45C9A),
                    width: 3
                )

                var star = Path()
                for k in 0..<10 {
                    let a = -Double.pi / 2 + Double(k) * .pi / 5
                    let r: CGFloat = k.isMultiple(of: 2) ? 24 : 11
                    let pt = CGPoint(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
                    if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                }
                star.closeSubpath()
                StorybookArt.fillAndStroke(
                    g,
                    star,
                    fill: StorybookArt.color(0xFFE378),
                    stroke: StorybookArt.outline(for: 0xE6A93B),
                    width: 2.6
                )
                StorybookArt.sparkle(g, at: CGPoint(x: -36, y: -32), radius: 7, color: Theme.lemon)
                StorybookArt.sparkle(g, at: CGPoint(x: 36, y: 30), radius: 6, color: .white)
            }
        }
    }
}

/// Shown on the stage while she dresses for the theme.
struct BattleBanner: View {
    let state: BattleState
    var cancel: () -> Void = {}
    let done: () -> Void
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            RoundButton(symbol: "xmark", tint: Theme.pink, size: 54) {
                Sound.shared.play(.whoosh, volume: 0.6)
                cancel()
            }
            ZStack {
                SceneView(bg: state.theme.scene)
                ItemThumb(item: state.theme.hints[0], look: state.rival).padding(8)
            }
            .frame(width: 74, height: 74)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 4))
            ForEach(state.theme.hints.dropFirst(), id: \.self) { id in
                ItemThumb(item: id, look: state.rival)
                    .padding(6)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(.white.opacity(0.95)))
                    .overlay(Circle().stroke(Theme.blush, lineWidth: 2.5))
            }
            Button(action: done) {
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 74, height: 74)
                    .background(Circle().fill(Color(hex: 0x6CCB8B).gradient))
                    .overlay(Circle().stroke(.white, lineWidth: 4.5))
                    .scaleEffect(pulse ? 1.07 : 0.96)
            }
            .buttonStyle(Squish())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.cream.opacity(0.96)))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 3.5))
        .shadow(color: Theme.ink.opacity(0.18), radius: 10, y: 5)
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

// MARK: - Runway

struct RunwayView: View {
    let state: BattleState
    let mine: Look
    let again: () -> Void
    let done: () -> Void

    @State private var shown = 0
    @State private var finished = false
    @State private var awarded = false
    @State private var save = GameStorage.load(BattleSave.self, game: LookStore.game, file: "battle.json") ?? BattleSave()
    @State private var myStars: [Int] = []
    @State private var rivalStars: [Int] = []
    @State private var walkIn = false
    @State private var myMotion = DollMotion()
    @State private var rivalMotion = DollMotion()

    private static let judges = ["kitty", "puppy", "bunny"]

    private var revealedMine: [Int] { Array(myStars.prefix(shown)) }
    private var revealedRival: [Int] { Array(rivalStars.prefix(shown)) }
    private var iWin: Bool { myStars.reduce(0, +) >= rivalStars.reduce(0, +) }

    var body: some View {
        ZStack {
            SceneView(bg: state.theme.scene).ignoresSafeArea()
            SceneLife(bg: state.theme.scene).ignoresSafeArea()
            RunwayAtmosphere()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            DesignCanvas {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        HStack(alignment: .bottom, spacing: 64) {
                            contestant(mine, scores: revealedMine, motion: myMotion, winner: finished && iWin)
                                .offset(x: walkIn ? 0 : -700)
                            contestant(state.rival, scores: revealedRival, motion: rivalMotion, winner: finished && !iWin)
                                .offset(x: walkIn ? 0 : 700)
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)

                        HStack(spacing: 24) {
                            judgesRow
                            HStack(spacing: 16) {
                                RoundButton(symbol: "arrow.clockwise", tint: Color(hex: 0x9B79E0), size: 78) { again() }
                                RoundButton(symbol: "checkmark", tint: Color(hex: 0x6CCB8B), size: 78) { done() }
                            }
                            .opacity(finished ? 1 : 0)
                            .scaleEffect(finished ? 1 : 0.6)
                            .allowsHitTesting(finished)
                        }
                        .padding(.vertical, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    CoinCounter(game: LookStore.game, height: GameChromeLayout.buttonSize)
                        .padding(.top, 18)
                        .padding(.trailing, 22)
                }
                .coinPurse(game: LookStore.game)
            }
        }
        .onAppear(perform: run)
    }

    private func contestant(_ look: Look, scores: [Int], motion: DollMotion, winner: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                if winner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 68))
                        .foregroundStyle(Theme.lemon)
                        .shadow(color: Color(hex: 0xD98D26).opacity(0.55), radius: 6, y: 2)
                        .transition(.scale.combined(with: .move(edge: .top)))
                    SparkleBurst(colors: [Theme.lemon, .white, Theme.pink], count: 16, radius: 220)
                } else if finished {
                    Image(systemName: "rosette")
                        .font(.system(size: 56))
                        .foregroundStyle(Color(hex: 0x5C9BEB))
                        .transition(.scale)
                }
            }
            .frame(height: 74)

            starRibbon(scores: scores)

            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Theme.lemon.opacity(winner ? 0.55 : 0.3), Theme.ink.opacity(0.16), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 120
                        )
                    )
                    .frame(width: 230, height: 38)
                    .offset(y: -4)
                LiveDollView(look: look, expression: winner ? .happy : .normal, box: DressUpView.stageBox, motion: motion)
                    .frame(width: 330, height: 464)
                    .scaleEffect(winner ? 1.05 : 1, anchor: .bottom)
            }
        }
    }

    private func starRibbon(scores: [Int]) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { idx in
                if idx < scores.count {
                    HStack(spacing: 1.5) {
                        ForEach(0..<scores[idx], id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Color(hex: 0xF5B92E))
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: 0xFFF8E0)))
                    .overlay(Capsule().stroke(Theme.lemon, lineWidth: 2))
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "star")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.22))
                        .frame(width: 34, height: 24)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.cream.opacity(0.95)))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 3))
        .shadow(color: Theme.ink.opacity(0.14), radius: 6, y: 3)
    }

    private var judgesRow: some View {
        HStack(spacing: 32) {
            ForEach(0..<3, id: \.self) { i in
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        card(i < shown ? myStars[safe: i] : nil, tint: Color(hex: 0xF45C9A))
                        card(i < shown ? rivalStars[safe: i] : nil, tint: Color(hex: 0x5C9BEB))
                    }
                    PetThumb(pet: PetLook(kind: Self.judges[i]), box: CGRect(x: 60, y: 0, width: 480, height: 480),
                             pose: judgeFace(i))
                        .frame(width: 92, height: 92)
                        .offset(y: i == shown - 1 ? -10 : 0)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Theme.cream.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Theme.blush, lineWidth: 3.5))
        .shadow(color: Theme.ink.opacity(0.16), radius: 10, y: 5)
    }

    private func judgeFace(_ i: Int) -> PetPose {
        var p = PetPose()
        if i < shown, (myStars[safe: i] ?? 0) >= 4 { p.eyes = "happy"; p.mouth = "grin" }
        return p
    }

    private func card(_ n: Int?, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(n == nil ? tint.opacity(0.32) : tint)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white, lineWidth: 2.5))
            if let count = n {
                starCluster(count)
            } else {
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(width: 64, height: 56)
    }

    @ViewBuilder
    private func starCluster(_ count: Int) -> some View {
        let clamped = max(1, min(5, count))
        if clamped <= 3 {
            HStack(spacing: 2) {
                ForEach(0..<clamped, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.lemon)
                }
            }
        } else {
            let top = 2
            let bottom = clamped - top
            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    ForEach(0..<top, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Theme.lemon)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(0..<bottom, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Theme.lemon)
                    }
                }
            }
        }
    }

    private func run() {
        guard !awarded else { return }
        myStars = state.theme.stars(mine, luck: (0..<3).map { _ in [0, 0, 1].randomElement()! })
        rivalStars = state.theme.stars(state.rival, luck: (0..<3).map { _ in [-1, 0, 0].randomElement()! })
        Sound.shared.play(.whoosh)
        myMotion.swish()
        rivalMotion.swish()
        withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) { walkIn = true }
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 + Double(i) * 0.9) {
                Sound.shared.play([SFX.note1, .note2, .note3][i - 1])
                myMotion.hop()
                withAnimation(.spring(response: 0.35)) { shown = i }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            guard !awarded else { return }
            awarded = true
            Sound.shared.play(iWin ? .fanfare : .cheer)
            let now = Date().timeIntervalSinceReferenceDate
            if iWin {
                myMotion.startDance(at: now)
                rivalMotion.hop()
            } else {
                myMotion.hop()
                rivalMotion.startDance(at: now)
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { finished = true }
            save.shows += 1
            if iWin { save.wins += 1 }
            GameStorage.save(save, game: LookStore.game, file: "battle.json")
            BattleTheme.awardRunway(stars: myStars, won: iWin, from: CGPoint(x: 340, y: 390))
        }
    }
}

private struct RunwayAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let sway = CGFloat(sin(t * 0.9)) * 28
                let w = size.width
                let h = size.height

                // Soft sweeping stage spotlight cones
                for (originX, targetX, tint) in [
                    (w * 0.16, w * 0.33 + sway, Color(hex: 0xFFF4B8)),
                    (w * 0.84, w * 0.67 - sway, Color(hex: 0xFFE3F2)),
                ] as [(CGFloat, CGFloat, Color)] {
                    var beam = Path()
                    beam.move(to: CGPoint(x: originX - 24, y: -10))
                    beam.addLine(to: CGPoint(x: originX + 24, y: -10))
                    beam.addLine(to: CGPoint(x: targetX + 140, y: h * 0.82))
                    beam.addLine(to: CGPoint(x: targetX - 140, y: h * 0.82))
                    beam.closeSubpath()
                    ctx.fill(
                        beam,
                        with: .linearGradient(
                            Gradient(colors: [tint.opacity(0.32), tint.opacity(0.08), .clear]),
                            startPoint: CGPoint(x: originX, y: 0),
                            endPoint: CGPoint(x: targetX, y: h * 0.82)
                        )
                    )
                }

                // Soft scalloped storybook curtains framing the top left & right edges
                for side in [-1.0, 1.0] as [CGFloat] {
                    let edgeX: CGFloat = side < 0 ? 0 : w
                    let dir: CGFloat = side < 0 ? 1 : -1
                    var drape = Path()
                    drape.move(to: CGPoint(x: edgeX, y: 0))
                    drape.addLine(to: CGPoint(x: edgeX + dir * 135, y: 0))
                    drape.addCurve(
                        to: CGPoint(x: edgeX + dir * 32, y: h * 0.52),
                        control1: CGPoint(x: edgeX + dir * 112, y: h * 0.2),
                        control2: CGPoint(x: edgeX + dir * 72, y: h * 0.38)
                    )
                    drape.addLine(to: CGPoint(x: edgeX, y: h * 0.56))
                    drape.closeSubpath()
                    StorybookArt.fillAndStroke(
                        ctx,
                        drape,
                        fill: StorybookArt.color(0xF685B0, alpha: 0.72),
                        stroke: StorybookArt.outline(for: 0xE0568D),
                        width: 4
                    )
                }
            }
        }
    }
}
