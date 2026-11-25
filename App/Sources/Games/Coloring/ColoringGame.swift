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
        id: ColoringGallery.gameID,
        title: "Coloring",
        tint: Color(hex: 0xC9B6FF),
        icon: { AnyView(ColoringIcon()) },
        play: { exit in AnyView(ColoringGameView(onExit: exit)) },
        stickers: ColoringFind.stickers
    )
}

struct ColoringGameView: View {
    let onExit: () -> Void

    private enum Screen { case book, studio, gallery, grownUp }
    @State private var screen: Screen = .book
    @State private var studio: ColoringStudio?
    @State private var category = ColoringCatalog.all.first?.id ?? ""
    @State private var showBook = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            DesignCanvas {
                ZStack {
                    switch screen {
                    case .book:
                        ColoringBookView(
                            category: $category,
                            onExit: onExit,
                            onStickerBook: openBook,
                            onPick: openPage,
                            onGallery: { go(.gallery) },
                            onGrownUp: { go(.grownUp) }
                        )
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
                            ColoringStudioView(
                                studio: studio,
                                onBack: closeStudio,
                                onDone: { closeStudio(); go(.gallery) },
                                onHome: exitFromStudio,
                                onStickerBook: openBook
                            )
                            .transition(.opacity)
                        }
                    case .gallery:
                        ColoringGalleryView(onBack: { go(.book) }, onOpen: { art in open(page: art.page, artwork: art) })
                            .transition(.opacity)
                    }

                    StickerToast(game: ColoringGallery.gameID, target: GameChromeLayout.stickerTarget)
                }
                .coinPurse(game: ColoringGallery.gameID)
            }
            .background(ColoringBackground())

            if showBook {
                StickerBookView(game: ColoringGallery.gameID) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
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

    private func openBook() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showBook = true
        }
    }

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

    private func exitFromStudio() {
        studio?.saveIfNeeded()
        studio = nil
        onExit()
    }
}

// MARK: - The book (page picker)

struct ColoringBookView: View {
    @Binding var category: String
    let onExit: () -> Void
    var onStickerBook: (() -> Void)? = nil
    let onPick: (String) -> Void
    let onGallery: () -> Void
    let onGrownUp: () -> Void
    @ObservedObject private var custom = ColoringCustom.shared

    private var all: [ColoringCategory] { ColoringCatalog.all }
    private var current: ColoringCategory? { all.first { $0.id == category } }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                HomeButton(size: GameChromeLayout.buttonSize, action: onExit)
                if let onStickerBook {
                    StickerBookButton(game: ColoringGallery.gameID, size: GameChromeLayout.buttonSize, action: onStickerBook)
                }
                Spacer()
                ColoringIcon().frame(width: 66, height: 66)
                Spacer()
                HStack(spacing: 12) {
                    CoinCounter(game: ColoringGallery.gameID, height: GameChromeLayout.buttonSize)
                    GrownUpButton(action: onGrownUp)
                    ColoringButton(icon: "doc.fill", tint: Theme.sky, size: GameChromeLayout.buttonSize) { onPick(ColoringCatalog.blank) }
                    ColoringButton(icon: "photo.on.rectangle.angled", tint: Theme.pink, size: GameChromeLayout.buttonSize, action: onGallery)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            HStack(alignment: .top, spacing: 16) {
                GameTrayCard(cornerRadius: 28, paddingH: 6, paddingV: 8) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(all) { c in
                                Button {
                                    Sound.shared.play(.tap, volume: 0.5)
                                    withAnimation(.spring(response: 0.3)) { category = c.id }
                                } label: {
                                    CategoryTabIcon(category: c)
                                        .frame(width: 80, height: 80)
                                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(c.cover == nil ? c.tint : .white))
                                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(category == c.id ? Theme.pink : .white, lineWidth: category == c.id ? 5.5 : 3.5))
                                        .scaleEffect(category == c.id ? 1.07 : 1)
                                        .shadow(color: Theme.ink.opacity(0.18), radius: 4, y: 3)
                                }
                                .buttonStyle(Squish())
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                    }
                }
                .frame(width: 108)

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
            .padding(.bottom, 12)
        }
    }
}

/// A category tab: its symbol, or for a grown-up tab the first page's picture.
private struct CategoryTabIcon: View {
    let category: ColoringCategory
    var body: some View {
        if let cover = category.cover, let img = ColoringCatalog.thumbnail(cover) {
            Image(uiImage: img).resizable().scaledToFill().frame(width: 80, height: 80)
        } else {
            Image(systemName: category.icon)
                .font(.system(size: 32, weight: .bold))
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
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white)
            if let img = ColoringCatalog.thumbnail(page) {
                Image(uiImage: img).resizable().scaledToFit().padding(10)
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(tint, lineWidth: 6))
        .shadow(color: Theme.ink.opacity(0.18), radius: 6, y: 4)
    }
}

// MARK: - Look

/// The drawer tile picture: a paint palette with a brush.
struct ColoringIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 200
            var g = ctx
            g.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 200 * s) / 2)
            g.scaleBy(x: s, y: s)

            let palette = Self.palettePath()
            var thickness = g
            thickness.translateBy(x: 0, y: 7)
            StorybookArt.fillAndStroke(
                thickness,
                palette,
                fill: StorybookArt.shade(for: 0xF7DFC2, factor: 0.84),
                stroke: StorybookArt.outline(for: 0xF7DFC2),
                width: 5.5
            )

            StorybookArt.fillAndStroke(
                g,
                palette,
                fill: StorybookArt.color(0xFBF0DF),
                stroke: StorybookArt.outline(for: 0xF7DFC2),
                width: 5
            )
            StorybookArt.highlight(g, in: CGRect(x: 42, y: 40, width: 42, height: 14), opacity: 0.5)

            var thumbCtx = g
            thumbCtx.translateBy(x: 76, y: 138)
            thumbCtx.rotate(by: .degrees(-12))
            let hole = Path(ellipseIn: CGRect(x: -14, y: -10.5, width: 28, height: 21))
            StorybookArt.fillAndStroke(
                thumbCtx,
                hole,
                fill: StorybookArt.color(0xD8CAFF),
                stroke: StorybookArt.outline(for: 0xF7DFC2),
                width: 4
            )

            let blobs: [(CGPoint, CGSize, UInt32)] = [
                (CGPoint(x: 52, y: 92), CGSize(width: 26, height: 22), 0xFF7FB3),
                (CGPoint(x: 68, y: 62), CGSize(width: 25, height: 22), 0xFFB07C),
                (CGPoint(x: 102, y: 54), CGSize(width: 26, height: 22), 0xFFE27A),
                (CGPoint(x: 136, y: 66), CGSize(width: 25, height: 22), 0x8DE0C4),
                (CGPoint(x: 148, y: 96), CGSize(width: 24, height: 21), 0x82C0FF),
            ]
            for (center, sz, hex) in blobs {
                let shadowRect = CGRect(
                    x: center.x - sz.width / 2 + 1.5,
                    y: center.y - sz.height / 2 + 2.5,
                    width: sz.width,
                    height: sz.height
                )
                g.fill(
                    Path(ellipseIn: shadowRect),
                    with: .color(StorybookArt.shade(for: 0xF7DFC2, factor: 0.84).opacity(0.65))
                )
                let rect = CGRect(
                    x: center.x - sz.width / 2,
                    y: center.y - sz.height / 2,
                    width: sz.width,
                    height: sz.height
                )
                StorybookArt.shape(g, Path(ellipseIn: rect), hex: hex, width: 3.2)
                StorybookArt.highlight(
                    g,
                    in: CGRect(
                        x: rect.minX + sz.width * 0.2,
                        y: rect.minY + sz.height * 0.18,
                        width: sz.width * 0.3,
                        height: sz.height * 0.24
                    ),
                    opacity: 0.65
                )
            }

            var brush = g
            brush.translateBy(x: 98, y: 104)
            brush.rotate(by: .degrees(38))

            let handle = Self.brushHandlePath()
            var brushShadow = brush
            brushShadow.translateBy(x: 2, y: 6)
            brushShadow.fill(handle, with: .color(StorybookArt.shade(for: 0xF7DFC2, factor: 0.78).opacity(0.45)))

            StorybookArt.shape(brush, handle, hex: 0xFF8FB8, width: 4)
            StorybookArt.highlight(brush, in: CGRect(x: 46, y: -6.5, width: 42, height: 4.5), opacity: 0.5)

            let bristles = Self.bristlesPath()
            brush.fill(bristles, with: .color(StorybookArt.color(0xFFF3E2)))

            var paintTip = brush
            paintTip.clip(to: bristles)
            var dip = Path()
            dip.move(to: CGPoint(x: -6, y: -14))
            dip.addLine(to: CGPoint(x: 11, y: -14))
            dip.addQuadCurve(to: CGPoint(x: 9, y: 0), control: CGPoint(x: 14, y: -6))
            dip.addQuadCurve(to: CGPoint(x: 11, y: 14), control: CGPoint(x: 5, y: 7))
            dip.addLine(to: CGPoint(x: -6, y: 14))
            dip.closeSubpath()
            paintTip.fill(dip, with: .color(StorybookArt.color(0xFF6FA8)))

            brush.stroke(
                bristles,
                with: .color(StorybookArt.outline(for: 0xD8A880)),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
            )
            var tipEdge = brush
            tipEdge.clip(to: dip)
            tipEdge.stroke(
                bristles,
                with: .color(StorybookArt.outline(for: 0xFF6FA8)),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
            )
            StorybookArt.highlight(brush, in: CGRect(x: 3, y: -4.2, width: 7, height: 3.0), opacity: 0.6)

            let ferrule = Path(roundedRect: CGRect(x: 20, y: -8, width: 18, height: 16), cornerRadius: 4)
            StorybookArt.fillAndStroke(
                brush,
                ferrule,
                fill: StorybookArt.color(0xFFE7A8),
                stroke: StorybookArt.outline(for: 0xE6B85C),
                width: 3.5
            )
            StorybookArt.highlight(brush, in: CGRect(x: 23, y: -5.5, width: 12, height: 3.5), opacity: 0.65)

            StorybookArt.sparkle(g, at: CGPoint(x: 168, y: 40), radius: 11, color: Theme.lemon)
            StorybookArt.sparkle(g, at: CGPoint(x: 32, y: 164), radius: 8, color: .white, opacity: 0.9)
        }
    }

    private static func palettePath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 26, y: 98))
        p.addCurve(to: CGPoint(x: 94, y: 34), control1: CGPoint(x: 26, y: 54), control2: CGPoint(x: 54, y: 34))
        p.addCurve(to: CGPoint(x: 170, y: 84), control1: CGPoint(x: 138, y: 34), control2: CGPoint(x: 170, y: 52))
        p.addCurve(to: CGPoint(x: 138, y: 120), control1: CGPoint(x: 170, y: 108), control2: CGPoint(x: 154, y: 116))
        p.addCurve(to: CGPoint(x: 156, y: 154), control1: CGPoint(x: 124, y: 124), control2: CGPoint(x: 166, y: 134))
        p.addCurve(to: CGPoint(x: 88, y: 170), control1: CGPoint(x: 144, y: 172), control2: CGPoint(x: 116, y: 170))
        p.addCurve(to: CGPoint(x: 26, y: 98), control1: CGPoint(x: 48, y: 170), control2: CGPoint(x: 26, y: 140))
        p.closeSubpath()
        return p
    }

    private static func brushHandlePath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 36, y: -7))
        p.addCurve(to: CGPoint(x: 100, y: -9.5), control1: CGPoint(x: 58, y: -9), control2: CGPoint(x: 84, y: -11))
        p.addCurve(to: CGPoint(x: 100, y: 9.5), control1: CGPoint(x: 111, y: -8), control2: CGPoint(x: 111, y: 8))
        p.addCurve(to: CGPoint(x: 36, y: 7), control1: CGPoint(x: 84, y: 11), control2: CGPoint(x: 58, y: 9))
        p.closeSubpath()
        return p
    }

    private static func bristlesPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -4, y: 0))
        p.addCurve(to: CGPoint(x: 22, y: -9), control1: CGPoint(x: 4, y: -10), control2: CGPoint(x: 15, y: -11))
        p.addLine(to: CGPoint(x: 22, y: 9))
        p.addCurve(to: CGPoint(x: -4, y: 0), control1: CGPoint(x: 15, y: 11), control2: CGPoint(x: 4, y: 10))
        p.closeSubpath()
        return p
    }
}

struct ColoringBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0xFFF1F8), Color(hex: 0xEDE6FF), Color(hex: 0xE3F4FF)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}
