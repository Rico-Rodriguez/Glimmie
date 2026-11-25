import SwiftUI

// MARK: - Waiting room: every patient on a cushion chair, with a thought bubble of what's wrong.

struct VetLobbyView: View {
    static let seatBottomPadding: CGFloat = 58

    @ObservedObject var clinic: VetClinic
    let onExit: () -> Void
    let onPick: (String) -> Void

    @State private var showBook = false

    var body: some View {
        ZStack {
            GameStage(background: {
                Canvas { ctx, size in VetDraw.room("lobby", size: size, in: ctx) }
            }) {
                ZStack {
                    VStack(spacing: 0) {
                        Spacer(minLength: 108)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .bottom, spacing: 18) {
                                ForEach(Array(clinic.animals.enumerated()), id: \.element) { i, a in
                                    VetSeat(clinic: clinic, animal: a, index: i) {
                                        Sound.shared.play(.pop, volume: 0.7)
                                        VetSound.shared.play(.hop, volume: 0.6)
                                        Sound.shared.tap()
                                        onPick(a)
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                            .padding(.bottom, Self.seatBottomPadding)
                        }
                    }

                    GameTopBar(
                        gameID: PetVetGame.id,
                        showStickerBook: true,
                        showCoins: true,
                        onExit: onExit,
                        onStickerBook: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showBook = true
                            }
                        },
                        center: {
                            VetSign()
                        },
                        trailing: {
                            EmptyView()
                        }
                    )

                    StickerToast(game: PetVetGame.id, target: GameChromeLayout.stickerTarget)
                }
                .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                .coinPurse(game: PetVetGame.id)
            }

            if showBook {
                StickerBookView(game: PetVetGame.id) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .defersSystemGestures(on: .bottom)
    }
}

/// The clinic sign at the top: a heart with a cross.
private struct VetSign: View {
    @State private var beat = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 72, height: 72)
                .overlay(Circle().stroke(Theme.pink.opacity(0.55), lineWidth: 5))
                .shadow(color: Theme.ink.opacity(0.18), radius: 6, y: 4)
            Image(systemName: "heart.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.pink)
            Image(systemName: "cross.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -1)
        }
        .scaleEffect(beat ? 1.07 : 0.96)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                beat = true
            }
        }
    }
}

private struct VetSeat: View {
    @ObservedObject var clinic: VetClinic
    let animal: String
    let index: Int
    let tap: () -> Void
    @State private var bob = false

    var body: some View {
        let visit = clinic.visit(animal)
        let sick = !visit.healed && !visit.spots.isEmpty
        Button(action: tap) {
            ZStack(alignment: .bottom) {
                VetPropPicture(prop: "seat", units: 320)
                    .frame(width: 280, height: 280)
                VetPatientPicture(
                    animal: animal,
                    face: sick ? (visit.has(.cold) || visit.has(.tummy) ? .poorly : .sad) : .giggle,
                    stickers: clinic.stickers(animal)
                )
                .frame(width: 240, height: 264)
                .offset(y: bob ? -6 : 0)
                .offset(y: -110)
            }
            .frame(width: 250, height: 420)
            .overlay(alignment: .topTrailing) {
                if sick {
                    VetThought(icons: Array(visit.openAilments.prefix(3)).map(\.icon))
                        .offset(x: 10, y: 0)
                } else {
                    VetHappyBadge()
                        .offset(x: 6, y: 4)
                }
            }
            .overlay(alignment: .bottom) {
                if clinic.healedCount(animal) > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(5, clinic.healedCount(animal)), id: \.self) { _ in
                            Image(systemName: "heart.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.pink)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.cream.opacity(0.95)))
                    .overlay(Capsule().stroke(Theme.blush, lineWidth: 2.5))
                    .padding(.bottom, 14)
                }
            }
        }
        .buttonStyle(Squish())
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2 + Double(index % 4) * 0.15)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index % 5) * 0.2)
            ) {
                bob = true
            }
        }
    }
}

/// A cloud-shaped thought bubble with the patient's problems drawn inside.
private struct VetThought: View {
    let icons: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(icons.enumerated()), id: \.offset) { _, p in
                VetPropPicture(prop: p).frame(width: 52, height: 52)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack(alignment: .bottomLeading) {
                Capsule()
                    .fill(.white)
                    .overlay(Capsule().stroke(Theme.blush, lineWidth: 3))
                    .shadow(color: Theme.ink.opacity(0.15), radius: 5, y: 3)
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(Theme.blush, lineWidth: 2.5))
                    .frame(width: 18, height: 18)
                    .offset(x: 14, y: 16)
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(Theme.blush, lineWidth: 2))
                    .frame(width: 10, height: 10)
                    .offset(x: 4, y: 30)
            }
        )
    }
}

/// Warm badge showing a healed patient is ready for happy checkups, treats, and bows.
private struct VetHappyBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.pink)
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.lemon)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Theme.cream)
                .overlay(Capsule().stroke(Theme.mint, lineWidth: 3))
                .shadow(color: Theme.ink.opacity(0.14), radius: 4, y: 2)
        )
    }
}
