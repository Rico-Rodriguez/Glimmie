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
    @State private var viewingScene: PlayhousePhoto?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 22), count: 4)

    private enum Entry: Identifiable {
        case portrait(Look)
        case playhouse(PlayhousePhoto)

        var id: UUID {
            switch self {
            case .portrait(let l): return l.id
            case .playhouse(let p): return p.id
            }
        }

        var saved: Date {
            switch self {
            case .portrait(let l): return l.saved
            case .playhouse(let p): return p.saved
            }
        }
    }

    private var entries: [Entry] {
        (store.gallery.map(Entry.portrait) + store.playhousePhotos.map(Entry.playhouse))
            .sorted { $0.saved > $1.saved }
    }

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

                    if entries.isEmpty {
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
                                ForEach(entries) { entry in
                                    switch entry {
                                    case .portrait(let look):
                                        card(look)
                                    case .playhouse(let photo):
                                        playhouseCard(photo)
                                    }
                                }
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
            if let scenePhoto = viewingScene {
                playhouseLightbox(scenePhoto)
                    .transition(.opacity)
                    .zIndex(2)
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

            deleteButton(id: look.id) {
                store.delete(look)
            }
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
                saveBadge(id: look.id)
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

    private func playhouseCard(_ photo: PlayhousePhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                Sound.shared.play(.pop)
                withAnimation(.spring(response: 0.35)) { viewingScene = photo }
            } label: {
                ZStack {
                    Color(hex: 0xFFFDF8)
                    if let uiImage = photo.loadImage() {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "theatermasks.fill")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(Theme.lilac)
                    }
                }
                .aspectRatio(PhotoBase.aspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white, lineWidth: 8))
                .shadow(color: Theme.ink.opacity(0.2), radius: 10, y: 6)
            }
            .buttonStyle(Squish())

            deleteButton(id: photo.id) {
                store.deletePlayhousePhoto(photo)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Button {
                guard !savingToPhotos.contains(photo.id), let img = photo.loadImage() else { return }
                savingToPhotos.insert(photo.id)
                Sound.shared.tap()
                PhotoSaver.save(image: img) { ok in
                    savingToPhotos.remove(photo.id)
                    if ok {
                        Sound.shared.play(.sparkle)
                        DressUpFind.photoQueen.unlock()
                        withAnimation(.spring(response: 0.3)) { _ = savedToPhotos.insert(photo.id) }
                    } else {
                        Sound.shared.play(.tap, volume: 0.5)
                    }
                }
            } label: {
                saveBadge(id: photo.id)
            }
            .buttonStyle(Squish())
            .offset(x: -6, y: 8)
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "house.fill")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color(hex: 0x9B79E0)))
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .offset(x: 6, y: 8)
                .allowsHitTesting(false)
        }
    }

    private func playhouseLightbox(_ photo: PlayhousePhoto) -> some View {
        ZStack {
            Theme.ink.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    Sound.shared.play(.whoosh, volume: 0.5)
                    withAnimation(.spring(response: 0.35)) { viewingScene = nil }
                }
            DesignCanvas {
                VStack(spacing: 18) {
                    HStack {
                        RoundButton(symbol: "xmark", tint: Theme.pink, size: GameChromeLayout.buttonSize) {
                            Sound.shared.play(.whoosh, volume: 0.5)
                            withAnimation(.spring(response: 0.35)) { viewingScene = nil }
                        }
                        Spacer()
                        RoundButton(
                            symbol: savedToPhotos.contains(photo.id) ? "checkmark" : "square.and.arrow.down.fill",
                            tint: savedToPhotos.contains(photo.id) ? Color(hex: 0x6CCB8B) : Color(hex: 0x46B7B0),
                            size: GameChromeLayout.buttonSize
                        ) {
                            guard !savingToPhotos.contains(photo.id), let img = photo.loadImage() else { return }
                            savingToPhotos.insert(photo.id)
                            Sound.shared.tap()
                            PhotoSaver.save(image: img) { ok in
                                savingToPhotos.remove(photo.id)
                                if ok {
                                    Sound.shared.play(.sparkle)
                                    DressUpFind.photoQueen.unlock()
                                    withAnimation(.spring(response: 0.3)) { _ = savedToPhotos.insert(photo.id) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)

                    Spacer()
                    if let uiImage = photo.loadImage() {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 860, maxHeight: 620)
                            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(.white, lineWidth: 12))
                            .shadow(color: Theme.ink.opacity(0.32), radius: 20, y: 10)
                    }
                    Spacer()
                }
            }
        }
    }

    private func deleteButton(id: UUID, performDelete: @escaping () -> Void) -> some View {
        Button {
            if confirming == id {
                Sound.shared.play(.whoosh, volume: 0.6)
                confirmToken = UUID()
                withAnimation(.spring(response: 0.35)) {
                    confirming = nil
                    performDelete()
                }
            } else {
                Sound.shared.play(.tap)
                armDelete(id)
            }
        } label: {
            Image(systemName: confirming == id ? "trash.fill" : "xmark")
                .font(.system(size: confirming == id ? 24 : 18, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: confirming == id ? 58 : 42, height: confirming == id ? 58 : 42)
                .background(Circle().fill(confirming == id ? Color(hex: 0xE8475A) : Theme.ink.opacity(0.35)))
                .overlay(Circle().stroke(.white, lineWidth: 3))
        }
        .buttonStyle(Squish())
        .offset(x: 8, y: -8)
    }

    private func saveBadge(id: UUID) -> some View {
        Image(systemName: savedToPhotos.contains(id) ? "checkmark" : "square.and.arrow.down.fill")
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(Circle().fill(savedToPhotos.contains(id) ? Color(hex: 0x6CCB8B) : Color(hex: 0x46B7B0)))
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .opacity(savingToPhotos.contains(id) ? 0.65 : 1)
    }
}
