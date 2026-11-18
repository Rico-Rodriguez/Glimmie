import SwiftUI

/// First launch (and the mirror button): she designs her own girl.
struct AvatarMakerView: View {
    @EnvironmentObject var game: GameState
    let onDone: () -> Void

    @State private var draft = Avatar()
    @State private var bounce = false
    @State private var happy = false
    @State private var burstID = 0

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Live preview
                ZStack {
                    StageFloor().offset(y: geo.size.height * 0.36)
                    DollView(avatar: draft, outfit: game.outfit, happy: happy)
                        .frame(height: geo.size.height * 0.9)
                        .scaleEffect(x: bounce ? 1.04 : 1, y: bounce ? 0.96 : 1, anchor: .bottom)
                    SparkleBurst(count: 14, radius: 200).id(burstID).offset(y: -geo.size.height * 0.15)
                }
                .frame(width: geo.size.width * 0.5)

                // Choices
                VStack(spacing: 22) {
                    row(symbol: "hand.raised.fill") {
                        ForEach(Palette.skin) { s in
                            Button { pick { draft.skin = s.id } } label: { ColorDot(color: s.color, selected: draft.skin == s.id, size: 58) }
                        }
                    }
                    row(symbol: "comb.fill") {
                        ForEach(Catalog.hairStyles.indices, id: \.self) { i in
                            Button { pick(say: Catalog.hairStyleNames[i] + " hair") { draft.hairStyle = i } } label: {
                                StickerIcon(name: Catalog.hairStyles[i], tint: Palette.hair[draft.hairColor].color)
                                    .frame(width: 104, height: 104)
                                    .scaleEffect(draft.hairStyle == i ? 1.1 : 0.92)
                                    .opacity(draft.hairStyle == i ? 1 : 0.75)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: draft.hairStyle)
                            }
                        }
                    }
                    row(symbol: "paintbrush.pointed.fill") {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(58), spacing: 12), count: 4), spacing: 12) {
                            ForEach(Palette.hair) { s in
                                Button { pick(say: s.name + " hair") { draft.hairColor = s.id } } label: {
                                    ColorDot(color: s.color, selected: draft.hairColor == s.id, size: 50)
                                }
                            }
                        }
                    }
                    row(symbol: "eye.fill") {
                        ForEach(Palette.eyes) { s in
                            Button { pick(say: s.name + " eyes") { draft.eyes = s.id } } label: { ColorDot(color: s.color, selected: draft.eyes == s.id, size: 58) }
                        }
                    }
                    HStack(spacing: 24) {
                        CandyButton(symbol: "shuffle", color: Theme.lilac, size: 76) { randomize() }
                        CandyButton(symbol: "checkmark", color: Color(red: 0.6, green: 0.92, blue: 0.68), size: 96) { done() }
                    }
                    .padding(.top, 6)
                }
                .buttonStyle(SquishStyle())
                .padding(28)
                .background(RoundedRectangle(cornerRadius: 40).fill(Theme.panel))
                .padding(.trailing, 28)
                .frame(width: geo.size.width * 0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DreamyBackground())
        .onAppear {
            draft = game.avatar
            Sound.shared.say("Let's make you! Pick your skin, your hair, and your eyes.")
        }
    }

    @ViewBuilder
    private func row<Content: View>(symbol: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.ink.opacity(0.55))
                .frame(width: 40)
            content()
            Spacer(minLength: 0)
        }
    }

    private func pick(say text: String? = nil, _ change: () -> Void) {
        change()
        Sound.shared.play(.pop, volume: 0.7)
        if let text { Sound.shared.say(text) }
        burstID += 1
        withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) { bounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bounce = false }
        }
    }

    private func randomize() {
        pick {
            draft = Avatar(skin: .random(in: 0..<Palette.skin.count), hairStyle: .random(in: 0..<Catalog.hairStyles.count),
                           hairColor: .random(in: 0..<Palette.hair.count), eyes: .random(in: 0..<Palette.eyes.count))
        }
        Sound.shared.play(.sparkle)
    }

    private func done() {
        game.avatar = draft
        happy = true
        Sound.shared.play(.fanfare, volume: 0.8)
        Sound.shared.say("You look wonderful!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            game.madeAvatar = true
            onDone()
        }
    }
}
