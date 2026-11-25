import SwiftUI

struct GalleryView: View {
    @ObservedObject var store: LookStore
    let close: () -> Void
    let open: (Look) -> Void
    @State private var confirming: UUID?
    @State private var confirmToken = UUID()
    @State private var savedToPhotos: Set<UUID> = []
    @State private var savingToPhotos: Set<UUID> = []
    @State private var decorating: Look?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 22), count: 4)

    var body: some View {
        ZStack {
            Color(hex: 0xFFF1F6).ignoresSafeArea()
            DrawerBackground().opacity(0.6)
            DesignCanvas {
                VStack(spacing: 18) {
                    HStack {
                        RoundButton(symbol: "chevron.down", tint: Theme.pink, size: GameChromeLayout.buttonSize) {
                            Sound.shared.play(.whoosh, volume: 0.6)
                            close()
                        }
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(Color(hex: 0x46B7B0))
                        Spacer()
                        Color.clear.frame(width: GameChromeLayout.buttonSize, height: GameChromeLayout.buttonSize)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

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
            if let d = decorating {
                PhotoStudio(
                    look: d,
                    cancel: {
                        withAnimation(.spring(response: 0.4)) { decorating = nil }
                    },
                    done: { look in
                        store.update(look)
                        savedToPhotos.remove(look.id)
                        withAnimation(.spring(response: 0.4)) { decorating = nil }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }

    private func armDelete(_ id: UUID) {
        let token = UUID()
        confirmToken = token
        withAnimation(.spring(response: 0.3)) { confirming = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard confirmToken == token, confirming == id else { return }
            withAnimation(.spring(response: 0.3)) { confirming = nil }
        }
    }

    private func card(_ look: Look) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                Sound.shared.play(.pop)
                open(look)
            } label: {
                PhotoView(look: look)
                    .aspectRatio(PhotoBase.aspect, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white, lineWidth: 8))
                    .shadow(color: Theme.ink.opacity(0.2), radius: 10, y: 6)
            }
            .buttonStyle(Squish())

            Button {
                if confirming == look.id {
                    Sound.shared.play(.whoosh, volume: 0.6)
                    confirmToken = UUID()
                    withAnimation(.spring(response: 0.35)) {
                        confirming = nil
                        store.delete(look)
                    }
                } else {
                    Sound.shared.play(.tap)
                    armDelete(look.id)
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
        .overlay(alignment: .bottomLeading) {
            Button {
                guard !savingToPhotos.contains(look.id) else { return }
                savingToPhotos.insert(look.id)
                Sound.shared.tap()
                PhotoSaver.save(look) { ok in
                    savingToPhotos.remove(look.id)
                    if ok {
                        Sound.shared.play(.sparkle)
                        DressUpFind.photoQueen.unlock()
                        withAnimation(.spring(response: 0.3)) { _ = savedToPhotos.insert(look.id) }
                    } else {
                        Sound.shared.play(.tap, volume: 0.5)
                    }
                }
            } label: {
                Image(systemName: savedToPhotos.contains(look.id) ? "checkmark" : "square.and.arrow.down.fill")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(savedToPhotos.contains(look.id) ? Color(hex: 0x6CCB8B) : Color(hex: 0x46B7B0)))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .opacity(savingToPhotos.contains(look.id) ? 0.65 : 1)
            }
            .buttonStyle(Squish())
            .offset(x: -6, y: 8)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                Sound.shared.play(.whoosh, volume: 0.6)
                withAnimation(.spring(response: 0.4)) { decorating = look }
            } label: {
                Image(systemName: "star.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color(hex: 0xFFB23E)))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            }
            .buttonStyle(Squish())
            .offset(x: 6, y: 8)
        }
    }
}
