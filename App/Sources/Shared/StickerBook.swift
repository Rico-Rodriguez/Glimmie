import SwiftUI

// MARK: - The sticker book
//
// One book for the whole app, opened from the home screen (and from inside a game, at that game's page). Each
// game that has surprises gives its `GameEntry` a list of stickers: rare things she can come across by playing,
// like a pink sunflower or a frog that hops in when it rains. Nothing is locked or bought, nothing is a task:
// she finds a surprise, its sticker pops up and flies into the book, and the book shows the ones still to find
// as soft grey shapes. Nothing to read.
//
// Saves live in their own folder (`stickers`), so a game never touches another game's saves. A game only calls
// `StickerBook.shared.find(game:id:)`, which is cheap to call again and again.

/// One sticker. `draw` paints it centered in a square of the given side (any size; drawn for 100).
struct Sticker: Identifiable {
    let id: String
    let draw: (GraphicsContext, CGFloat) -> Void
}

final class StickerBook {
    static let shared = StickerBook()
    static let folder = "stickers"

    private struct Save: Codable {
        var found: [String]
        var unseen: [String]
    }

    /// "<game id>/<sticker id>" for each sticker she has found.
    private(set) var found: Set<String>
    /// Found but not yet looked at in the book: the book button sparkles while there are any.
    private(set) var unseen: Set<String>
    /// The latest find, for the pop-up that flies into the book.
    private(set) var lastFind: (game: String, id: String, at: Date)?
    /// Screenshots and demos don't keep their finds.
    var demo = false

    private init() {
        let s = GameStorage.load(Save.self, game: StickerBook.folder, file: "stickers.json")
        found = Set(s?.found ?? [])
        unseen = Set(s?.unseen ?? [])
    }

    static func key(_ game: String, _ id: String) -> String { "\(game)/\(id)" }

    func has(game: String, id: String) -> Bool { found.contains(StickerBook.key(game, id)) }

    /// She found it. Returns true the first time (when the sticker pops up and flies into the book).
    @discardableResult
    func find(game: String, id: String) -> Bool {
        let k = StickerBook.key(game, id)
        guard !found.contains(k) else { return false }
        found.insert(k)
        unseen.insert(k)
        lastFind = (game, id, Date())
        Sound.shared.play(.fanfare, volume: 0.5)
        save()
        return true
    }

    func count(game: String) -> Int { found.filter { $0.hasPrefix(game + "/") }.count }

    func hasUnseen(game: String? = nil) -> Bool {
        guard let game else { return !unseen.isEmpty }
        return unseen.contains { $0.hasPrefix(game + "/") }
    }

    /// She opened this game's page: its new stickers aren't new anymore.
    func markSeen(game: String) {
        let before = unseen.count
        unseen = unseen.filter { !$0.hasPrefix(game + "/") }
        if unseen.count != before { save() }
    }

    private func save() {
        guard !demo else { return }
        GameStorage.save(Save(found: found.sorted(), unseen: unseen.sorted()), game: StickerBook.folder, file: "stickers.json")
    }

    /// Which games have stickers, in drawer order.
    static var pages: [GameEntry] { GameRegistry.all.filter { !$0.stickers.isEmpty } }

    static func sticker(game: String, id: String) -> Sticker? {
        GameRegistry.all.first { $0.id == game }?.stickers.first { $0.id == id }
    }
}

// MARK: - Drawing one sticker

/// A sticker in color with a white die-cut edge, or (not found yet) a soft grey shape of it.
struct StickerArt: View {
    let sticker: Sticker
    let found: Bool

    var body: some View {
        let art = Canvas { ctx, size in
            var g = ctx
            let side = min(size.width, size.height)
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: side / 100, y: side / 100)
            sticker.draw(g, 100)
        }
        if found {
            art
                .shadow(color: .white, radius: 0, x: 2.5, y: 0)
                .shadow(color: .white, radius: 0, x: -2.5, y: 0)
                .shadow(color: .white, radius: 0, x: 0, y: 2.5)
                .shadow(color: .white, radius: 0, x: 0, y: -2.5)
                .shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 2)
        } else {
            Theme.ink.opacity(0.16).mask { art }
        }
    }
}

// MARK: - The book's button

/// A round book button. It sparkles while there are new stickers to look at, and bounces when one flies in.
struct StickerBookButton: View {
    var game: String?
    var size: CGFloat = 72
    let action: () -> Void

    var body: some View {
        Button {
            Sound.shared.play(.flip, volume: 0.7)
            Sound.shared.tap()
            action()
        } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                let now = tl.date
                let book = StickerBook.shared
                let fresh = book.hasUnseen(game: game)
                // a sticker lands in the book about 1.7 s after it is found
                let landed = book.lastFind.map { now.timeIntervalSince($0.at) - StickerToast.flight } ?? -10
                let bump = CGFloat(landed > 0 && landed < 0.6 ? sin(landed / 0.6 * .pi) * 0.3 : 0)
                let t = now.timeIntervalSinceReferenceDate
                ZStack {
                    Circle().fill(Theme.lilac)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                    if fresh {
                        Image(systemName: "sparkle")
                            .font(.system(size: size * 0.3, weight: .heavy))
                            .foregroundStyle(Theme.lemon)
                            .shadow(color: Theme.ink.opacity(0.3), radius: 1)
                            .rotationEffect(.radians(t * 1.5))
                            .scaleEffect(CGFloat(0.8 + 0.25 * sin(t * 5)))
                            .offset(x: size * 0.36, y: -size * 0.36)
                    }
                }
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.white, lineWidth: 5))
                .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 4)
                .scaleEffect(1 + bump)
            }
        }
        .buttonStyle(Squish())
    }
}

// MARK: - A new sticker pops up and flies into the book

/// Put over a game (in its 1024 x 834 controls layer). When she finds something, its sticker pops up big in the
/// middle with a burst of stars, then shrinks and flies into the book button at `target`.
struct StickerToast: View {
    let game: String
    let target: CGPoint
    var center = CGPoint(x: 512, y: 330)

    static let flight = 1.7

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
            let book = StickerBook.shared
            if let f = book.lastFind, f.game == game, let s = StickerBook.sticker(game: f.game, id: f.id) {
                let a = tl.date.timeIntervalSince(f.at)
                if a >= 0 && a < StickerToast.flight {
                    toast(s, CGFloat(a))
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private func toast(_ s: Sticker, _ a: CGFloat) -> some View {
        // pop in (0...0.35), hold and wiggle (...1.05), fly into the book (...1.7)
        let pop = min(1, a / 0.35)
        let popScale = 1 + 0.25 * sin(pop * .pi) // overshoots a little
        let fly = max(0, min(1, (a - 1.05) / CGFloat(StickerToast.flight - 1.05)))
        let e = fly * fly * (3 - 2 * fly)
        let x = center.x + (target.x - center.x) * e
        let y = center.y + (target.y - center.y) * e - 120 * sin(e * .pi)
        let scale = (pop < 1 ? pop * popScale : 1) * (1 - 0.8 * e)
        let wiggle = a > 0.35 && a < 1.05 ? sin((a - 0.35) * 18) * 0.12 * (1 - (a - 0.35) / 0.7) : 0
        ZStack {
            // a burst of stars behind it
            ForEach(0..<10, id: \.self) { i in
                let ang = CGFloat(i) / 10 * 2 * .pi
                let r = 40 + 120 * min(1, a / 0.7)
                Image(systemName: "star.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(i % 2 == 0 ? Theme.lemon : Theme.pink)
                    .offset(x: cos(ang) * r, y: sin(ang) * r)
                    .opacity(Double(max(0, 1 - a / 0.9)))
            }
            Circle()
                .fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 30, endRadius: 140))
                .frame(width: 280, height: 280)
                .opacity(Double((1 - e) * 0.9))
            StickerArt(sticker: s, found: true)
                .frame(width: 190, height: 190)
                .rotationEffect(.radians(Double(wiggle)))
        }
        .scaleEffect(max(0.01, scale))
        .position(x: x, y: y)
    }
}

// MARK: - The book itself

/// The open book: a tab for each game down the side, that game's stickers on the page.
struct StickerBookView: View {
    let close: () -> Void
    @State private var page: String
    @State private var poke: [String: Date] = [:]
    @State private var shown = false

    init(game: String? = nil, close: @escaping () -> Void) {
        self.close = close
        let pages = StickerBook.pages
        let start = game.flatMap { g in pages.first { $0.id == g } } ?? pages.first { StickerBook.shared.hasUnseen(game: $0.id) } ?? pages.first
        _page = State(initialValue: start?.id ?? "")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: shut)
            HStack(spacing: 0) {
                tabs
                pageView
            }
            .frame(width: 940, height: 680)
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.35), radius: 20, y: 10)
            .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous).stroke(.white, lineWidth: 8))
            .overlay(alignment: .topTrailing) {
                Button(action: shut) {
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 66, height: 66)
                        .background(Circle().fill(Theme.pink))
                        .overlay(Circle().stroke(.white, lineWidth: 5))
                        .shadow(color: Theme.ink.opacity(0.25), radius: 5, y: 3)
                }
                .buttonStyle(Squish())
                .offset(x: 18, y: -18)
            }
            .scaleEffect(shown ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { shown = true }
            StickerBook.shared.markSeen(game: page)
        }
    }

    private func shut() {
        Sound.shared.play(.flip, volume: 0.6)
        close()
    }

    private var tabs: some View {
        VStack(spacing: 16) {
            ForEach(StickerBook.pages) { g in
                Button {
                    guard page != g.id else { return }
                    Sound.shared.play(.flip, volume: 0.6)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { page = g.id }
                    StickerBook.shared.markSeen(game: g.id)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous).fill(g.tint.gradient)
                        g.icon().padding(8)
                    }
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(page == g.id ? Theme.pink : .white, lineWidth: page == g.id ? 6 : 4))
                    .scaleEffect(page == g.id ? 1.06 : 0.94)
                    .shadow(color: Theme.ink.opacity(0.2), radius: 5, y: 3)
                }
                .buttonStyle(Squish())
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 22)
        .frame(maxHeight: .infinity)
        .background(Theme.blush.opacity(0.6))
    }

    @ViewBuilder private var pageView: some View {
        if let g = StickerBook.pages.first(where: { $0.id == page }) {
            let stickers = g.stickers
            let cols = stickers.count > 12 ? 5 : 4
            let book = StickerBook.shared
            VStack(spacing: 18) {
                // how many she has: a star for each sticker, filled in for the found ones
                HStack(spacing: 6) {
                    ForEach(stickers) { s in
                        Image(systemName: book.has(game: g.id, id: s.id) ? "star.fill" : "star")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(book.has(game: g.id, id: s.id) ? Theme.lemon : Theme.ink.opacity(0.2))
                            .shadow(color: book.has(game: g.id, id: s.id) ? Theme.ink.opacity(0.25) : .clear, radius: 1, y: 1)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: cols), spacing: 14) {
                    ForEach(stickers) { s in
                        cell(g.id, s, found: book.has(game: g.id, id: s.id))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 30)
            .padding(.horizontal, 30)
            .id(g.id)
            .transition(.opacity)
        } else {
            Color.clear
        }
    }

    private func cell(_ game: String, _ s: Sticker, found: Bool) -> some View {
        let key = StickerBook.key(game, s.id)
        return Button {
            guard found else {
                Sound.shared.play(.tap, volume: 0.4)
                return
            }
            Sound.shared.play(.pop, volume: 0.7)
            Sound.shared.tap()
            poke[key] = Date()
        } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: poke[key].map { Date().timeIntervalSince($0) > 0.7 } ?? true)) { tl in
                let a = poke[key].map { tl.date.timeIntervalSince($0) } ?? 10
                let jig = a < 0.6 ? sin(a * 26) * 0.18 * (1 - a / 0.6) : 0
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(found ? Color.white : Color.white.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(found ? Theme.lemon : Theme.ink.opacity(0.12),
                                    style: StrokeStyle(lineWidth: 4, dash: found ? [] : [10, 8])))
                    StickerArt(sticker: s, found: found)
                        .padding(14)
                        .rotationEffect(.radians(jig))
                        .scaleEffect(CGFloat(1 + (a < 0.6 ? 0.12 * sin(a / 0.6 * .pi) : 0)))
                }
                .frame(height: 132)
            }
        }
        .buttonStyle(Squish())
    }
}
