import SwiftUI

// MARK: - Coloring (a game in the drawer)
//
// A coloring book: pick a page, fill areas with a tap (solid, glitter, patterns, rainbow),
// paint with markers, crayons, colored pencils, watercolor, glitter glue, rainbow pens or stamps
// (each behaves like the real tool on paper, see Brushes.swift), add stickers, undo,
// and keep everything in a gallery. Every page and tool is free and open. No voice.
//
// Pages are public-domain line art from Openclipart, listed in art/coloring/imported.json
// and built with tools/import_coloring.py.

enum ColoringGame {
    static let entry = GameEntry(
        id: "coloring",
        title: "Coloring",
        tint: Color(hex: 0xC9B6FF),
        icon: { AnyView(ColoringIcon()) },
        play: { exit in AnyView(ColoringGameView(onExit: exit)) }
    )
}

struct ColoringGameView: View {
    let onExit: () -> Void

    private enum Screen { case book, studio, gallery, grownUp }
    @State private var screen: Screen = .book
    @State private var studio: ColoringStudio?
    @State private var category = ColoringCatalog.all.first?.id ?? ""
    @Environment(\.scenePhase) private var phase

    var body: some View {
        DesignCanvas {
            ZStack {
                switch screen {
                case .book:
                    ColoringBookView(category: $category, onExit: onExit, onPick: openPage, onGallery: { go(.gallery) },
                                     onGrownUp: { go(.grownUp) })
                        .transition(.opacity)
                case .grownUp:
                    ColoringGrownUpView(onDone: { tab in
                        if let tab { category = tab }
                        if !ColoringCatalog.all.contains(where: { $0.id == category }) { category = ColoringCatalog.all.first?.id ?? "" }
                        go(.book)
                    })
                    .transition(.opacity)
                case .studio:
                    if let studio {
                        ColoringStudioView(studio: studio, onBack: closeStudio, onDone: { closeStudio(); go(.gallery) })
                            .transition(.opacity)
                    }
                case .gallery:
                    ColoringGalleryView(onBack: { go(.book) }, onOpen: { art in open(page: art.page, artwork: art) })
                        .transition(.opacity)
                }
            }
        }
        .background(ColoringBackground())
        .onChange(of: phase) { p in if p != .active { studio?.saveIfNeeded() } }
        .onAppear {
            // For simulator screenshots: a blank page with a sample of every brush.
            if ProcessInfo.processInfo.arguments.contains("-coloringDemo") {
                studio = ColoringStudio(page: ColoringCatalog.blank, demo: true)
                screen = .studio
            }
        }
    }

    private func go(_ s: Screen) { withAnimation(.easeInOut(duration: 0.3)) { screen = s } }

    private func openPage(_ page: String) { open(page: page, artwork: nil) }

    private func open(page: String, artwork: ColoringArtwork?) {
        Sound.shared.play(.pop, volume: 0.7)
        studio = ColoringStudio(page: page, artwork: artwork)
        go(.studio)
    }

    private func closeStudio() {
        studio?.saveIfNeeded()
        go(.book)
        studio = nil
    }
}

// MARK: - The book (page picker)

struct ColoringBookView: View {
    @Binding var category: String
    let onExit: () -> Void
    let onPick: (String) -> Void
    let onGallery: () -> Void
    let onGrownUp: () -> Void
    @ObservedObject private var custom = ColoringCustom.shared

    private var all: [ColoringCategory] { ColoringCatalog.all }
    private var current: ColoringCategory? { all.first { $0.id == category } }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                HomeButton(action: onExit)
                Spacer()
                ColoringIcon().frame(width: 74, height: 74)
                Spacer()
                GrownUpButton(action: onGrownUp)
                ColoringButton(icon: "doc.fill", tint: Theme.sky) { onPick(ColoringCatalog.blank) }
                ColoringButton(icon: "photo.on.rectangle.angled", tint: Theme.pink, action: onGallery)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            HStack(alignment: .top, spacing: 16) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(all) { c in
                            Button {
                                Sound.shared.play(.tap, volume: 0.5)
                                withAnimation(.spring(response: 0.3)) { category = c.id }
                            } label: {
                                CategoryTabIcon(category: c)
                                    .frame(width: 84, height: 84)
                                    .background(RoundedRectangle(cornerRadius: 24).fill(c.cover == nil ? c.tint : .white))
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(category == c.id ? Theme.ink : .white, lineWidth: category == c.id ? 6 : 4))
                                    .scaleEffect(category == c.id ? 1.08 : 1)
                                    .shadow(color: Theme.ink.opacity(0.2), radius: 4, y: 3)
                            }
                            .buttonStyle(Squish())
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
                .frame(width: 110)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 300), spacing: 20)], spacing: 20) {
                        ForEach(current?.pages ?? [], id: \.self) { page in
                            Button { onPick(page) } label: {
                                ColoringPageTile(page: page, tint: current?.tint ?? Theme.lilac)
                            }
                            .buttonStyle(Squish())
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.trailing, 20)
                    .id(category)
                }
            }
            .padding(.leading, 16)
        }
    }
}

/// A category tab: its symbol, or for a grown-up tab the first page's picture.
private struct CategoryTabIcon: View {
    let category: ColoringCategory
    var body: some View {
        if let cover = category.cover, let img = ColoringCatalog.thumbnail(cover) {
            Image(uiImage: img).resizable().scaledToFill().frame(width: 84, height: 84)
        } else {
            Image(systemName: category.icon)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

/// The grown-ups' door: a small gear that only opens when held for 1.5 seconds.
struct GrownUpButton: View {
    let action: () -> Void
    @State private var holding = false
    var body: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(Circle().fill(Theme.ink.opacity(holding ? 0.8 : 0.35)))
            .overlay(Circle().trim(from: 0, to: holding ? 1 : 0).stroke(.white, lineWidth: 4).rotationEffect(.degrees(-90))
                .animation(.linear(duration: holding ? 1.5 : 0.1), value: holding))
            .onLongPressGesture(minimumDuration: 1.5, pressing: { holding = $0 }, perform: {
                holding = false
                Sound.shared.play(.ding, volume: 0.5)
                action()
            })
    }
}

private struct ColoringPageTile: View {
    let page: String
    let tint: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(.white)
            if let img = ColoringCatalog.thumbnail(page) {
                Image(uiImage: img).resizable().scaledToFit().padding(10)
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(tint, lineWidth: 6))
        .shadow(color: Theme.ink.opacity(0.18), radius: 6, y: 4)
    }
}

// MARK: - Look

/// The drawer tile picture: a paint palette with a brush.
struct ColoringIcon: View {
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Image(systemName: "paintpalette.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: s * 0.72, weight: .bold))
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: s * 0.36, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .offset(x: s * 0.26, y: s * 0.24)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

struct ColoringBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0xFFF1F8), Color(hex: 0xEDE6FF), Color(hex: 0xE3F4FF)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}
