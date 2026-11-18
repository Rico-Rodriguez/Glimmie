import SwiftUI

// MARK: - Star jar

struct StarJar: View {
    let stars: Int
    var pulse = false
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<GameState.jarSize, id: \.self) { i in
                StarShape()
                    .fill(i < stars ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.55), Theme.gold],
                                                                startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(Color.white.opacity(0.55)))
                    .overlay(StarShape().stroke(i < stars ? Color.orange.opacity(0.6) : Theme.ink.opacity(0.18), lineWidth: 2))
                    .frame(width: 40, height: 40)
                    .scaleEffect(i < stars ? 1 : 0.86)
                    .shadow(color: i < stars ? Theme.gold.opacity(0.8) : .clear, radius: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: stars)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.7)).shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 3))
        .scaleEffect(pulse ? 1.12 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.45), value: pulse)
    }
}

// MARK: - Egg → hatch

struct HatchView: View {
    let kind: Int?           // nil = every Glimmie already collected
    let onDone: () -> Void

    @State private var cracks = 0
    @State private var wobble = 0.0
    @State private var hatched = false
    @State private var flash = false
    @State private var appear = false
    @State private var bursts = 0

    var body: some View {
        ZStack {
            Color(red: 0.25, green: 0.12, blue: 0.3).opacity(0.55).ignoresSafeArea()
            RadialGradient(colors: [Color.white.opacity(0.8), .clear], center: .center, startRadius: 10, endRadius: 380)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if !hatched {
                EggView(cracks: cracks)
                    .rotationEffect(.degrees(wobble), anchor: .bottom)
                    .scaleEffect(appear ? 1.4 : 0.2)
                    .onTapGesture { tapEgg() }
                ForEach(0..<bursts, id: \.self) { _ in SparkleBurst(count: 10, radius: 180) }
            } else {
                VStack(spacing: 10) {
                    if let kind {
                        GlimmieView(kind: kind).frame(width: 380, height: 380)
                            .transition(.scale(scale: 0.1).combined(with: .opacity))
                        Text(Glimmies.all[kind].name)
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Theme.ink.opacity(0.6), radius: 6, y: 3)
                    } else {
                        HStack(spacing: -40) {
                            ForEach(Glimmies.all) { g in GlimmieView(kind: g.id).frame(width: 150, height: 150) }
                        }
                    }
                    CandyButton(symbol: "checkmark", color: Color(red: 0.6, green: 0.92, blue: 0.68), size: 90) { onDone() }
                        .padding(.top, 10)
                }
                Confetti()
                SparkleBurst(count: 24, radius: 320)
            }

            Color.white.opacity(flash ? 0.95 : 0).ignoresSafeArea().allowsHitTesting(false)
        }
        .onAppear {
            Sound.shared.play(.whoosh)
            Sound.shared.say("A magic egg! Tap it three times!")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { appear = true }
            idleWobble()
        }
    }

    private func idleWobble() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard !hatched, cracks == 0 else { return }
            shake(4)
            idleWobble()
        }
    }

    private func shake(_ amp: Double) {
        withAnimation(.easeInOut(duration: 0.08)) { wobble = amp }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { withAnimation(.easeInOut(duration: 0.1)) { wobble = -amp } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) { wobble = 0 } }
    }

    private func tapEgg() {
        guard !hatched else { return }
        cracks += 1
        bursts += 1
        Sound.shared.tapHaptic()
        shake(8 + Double(cracks) * 4)
        if cracks < 3 {
            Sound.shared.play(.crack)
            Sound.shared.say(cracks == 1 ? "Again!" : "One more!")
        } else {
            Sound.shared.play(.crack)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeIn(duration: 0.15)) { flash = true }
                Sound.shared.play(.hatch)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) { hatched = true }
                    withAnimation(.easeOut(duration: 0.6)) { flash = false }
                    Sound.shared.play(.fanfare)
                    if let kind {
                        Sound.shared.say("Hooray! A new Glimmie friend! Hello, \(Glimmies.all[kind].name)!")
                    } else {
                        Sound.shared.say("Hooray! You found every Glimmie! They're all so happy!")
                    }
                }
            }
        }
    }
}

// MARK: - Shelf (collection)

struct ShelfView: View {
    @EnvironmentObject var game: GameState
    let onClose: () -> Void
    @State private var tapped: Int? = nil
    @State private var resetHold = false

    var body: some View {
        ZStack {
            DreamyBackground()
            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    CandyButton(symbol: "xmark", color: .white, size: 64) { onClose() }
                }
                .padding(.horizontal, 30).padding(.top, 20)

                // Glimmie shelf: two wooden-ish shelves of 4
                VStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { row in
                        HStack(spacing: 18) {
                            ForEach(0..<4, id: \.self) { col in
                                let id = row * 4 + col
                                let has = game.owned.contains(id)
                                GlimmieView(kind: id, silhouette: !has)
                                    .frame(width: 150, height: 150)
                                    .scaleEffect(tapped == id ? 1.18 : 1)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.4), value: tapped)
                                    .onTapGesture {
                                        guard has else { Sound.shared.play(.boing, volume: 0.5); return }
                                        tapped = id
                                        Sound.shared.play(.ding)
                                        Sound.shared.say(Glimmies.all[id].name)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if tapped == id { tapped = nil } }
                                    }
                            }
                        }
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.9), Color(red: 0.93, green: 0.66, blue: 0.8)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 700, height: 22)
                            .shadow(color: Theme.ink.opacity(0.2), radius: 4, y: 4)
                            .padding(.bottom, 14)
                    }
                }

                // Secret looks (scrolls sideways once there are more than fit)
                ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 26) {
                    ForEach(Secrets.all) { s in
                        let has = game.secrets.contains(s.id)
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(has ? Color.white : Color.white.opacity(0.45))
                                    .overlay(Circle().stroke(has ? Theme.gold : Color.white, lineWidth: 5))
                                    .shadow(color: has ? Theme.gold.opacity(0.7) : .clear, radius: 10)
                                if has {
                                    StickerIcon(name: s.badgeItem).padding(14)
                                } else {
                                    Text("?").font(.system(size: 56, weight: .heavy, design: .rounded)).foregroundColor(Theme.ink.opacity(0.35))
                                }
                            }
                            .frame(width: 120, height: 120)
                            Text(has ? s.name : " ")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.ink)
                        }
                        .onTapGesture {
                            if has { Sound.shared.say(s.name) } else { Sound.shared.say("A secret look! Can you find it?") }
                        }
                    }
                }
                .padding(.horizontal, 30).padding(.vertical, 12)
                }
                Spacer(minLength: 0)
            }
            // Grown-ups: hold for 3 seconds to start over.
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 26))
                        .foregroundColor(Theme.ink.opacity(resetHold ? 0.8 : 0.25))
                        .padding(18)
                        .onLongPressGesture(minimumDuration: 3, pressing: { resetHold = $0 }) {
                            game.resetAll()
                            onClose()
                        }
                    Spacer()
                }
            }
        }
        .onAppear { Sound.shared.say("Your Glimmie friends!") }
    }
}
