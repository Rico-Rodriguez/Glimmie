import SwiftUI

/// Saved looks. Tap one to dress her in it again; the little x deletes it (after a second tap to be sure).
struct GalleryView: View {
    @ObservedObject var store: LookStore
    let close: () -> Void
    let open: (Look) -> Void
    @State private var confirming: UUID?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 22), count: 4)

    var body: some View {
        ZStack {
            Color(hex: 0xFFF1F6).ignoresSafeArea()
            DrawerBackground().opacity(0.6)
            DesignCanvas {
                VStack(spacing: 18) {
                    HStack {
                        RoundButton(symbol: "chevron.down", tint: Theme.pink) {
                            Sound.shared.play(.whoosh, volume: 0.6)
                            close()
                        }
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(Color(hex: 0x46B7B0))
                        Spacer()
                        Color.clear.frame(width: 72, height: 72)
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 22)

                    if store.gallery.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 90, weight: .bold))
                                .foregroundStyle(Color(hex: 0xF45C9A).opacity(0.8))
                            Image(systemName: "arrow.up")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundStyle(Theme.pink.opacity(0.5))
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: columns, spacing: 22) {
                                ForEach(store.gallery) { look in card(look) }
                            }
                            .padding(.horizontal, 30)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
        }
    }

    private func card(_ look: Look) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                Sound.shared.play(.pop)
                open(look)
            } label: {
                ZStack(alignment: .bottom) {
                    SceneView(bg: look.bg)
                    DollView(look: look)
                        .padding(.top, 14)
                }
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white, lineWidth: 8))
                .shadow(color: Theme.ink.opacity(0.2), radius: 10, y: 6)
            }
            .buttonStyle(Squish())

            Button {
                if confirming == look.id {
                    Sound.shared.play(.whoosh, volume: 0.6)
                    withAnimation(.spring(response: 0.35)) { store.delete(look) }
                    confirming = nil
                } else {
                    Sound.shared.play(.tap)
                    withAnimation(.spring(response: 0.3)) { confirming = look.id }
                }
            } label: {
                Image(systemName: confirming == look.id ? "trash.fill" : "xmark")
                    .font(.system(size: confirming == look.id ? 24 : 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: confirming == look.id ? 58 : 42, height: confirming == look.id ? 58 : 42)
                    .background(Circle().fill(confirming == look.id ? Color(hex: 0xE8475A) : Theme.ink.opacity(0.35)))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            }
            .buttonStyle(Squish())
            .offset(x: 8, y: -8)
        }
    }
}
