import SwiftUI

// MARK: - The sticker book
//
// One book for the whole app, opened from the home screen (and from inside a game, at that game's page). Each
// game that has surprises gives its `GameEntry` a list of stickers: rare things she can come across by playing,
// like a pink sunflower or a frog that hops in when it rains. Nothing is locked or bought, nothing is a task:
// she finds a surprise, its sticker pops up and flies into the book, and the book shows the ones still to find
// as soft tinted mystery shapes. Nothing to read.
//
// Saves live in their own folder (`stickers`), so a game never touches another game's saves. A game only calls
// `StickerBook.shared.find(game:id:)`, which is cheap to call again and again.

/// One sticker. `draw` paints it centered in a square of the given side (any size; drawn for 100).
struct Sticker: Identifiable {
    let id: String
    let draw: (GraphicsContext, CGFloat) -> Void
}

final class StickerBook: ObservableObject {
    static let shared = StickerBook()
    static let folder = "stickers"
    static let buttonBumpDuration = 0.6
    static var landingWindow: Double { StickerToast.flight + buttonBumpDuration + 0.05 }

    struct PageProgress: Equatable {
        let found: Int
        let total: Int
        var isComplete: Bool { total > 0 && found >= total }
    }

    private struct Save: Codable {
        var found: [String]
        var unseen: [String]
    }

    /// "<game id>/<sticker id>" for each sticker she has found.
    @Published private(set) var found: Set<String>
    /// Found but not yet looked at in the book: the book button sparkles while there are any.
    @Published private(set) var unseen: Set<String>
    /// The latest find, for the pop-up that flies into the book.
    @Published private(set) var lastFind: (game: String, id: String, at: Date)?
    @Published private(set) var isToastActive = false
    @Published private(set) var isButtonBumping = false
    /// Screenshots and demos don't keep their finds.
    var demo = false

    private var toastWorkItem: DispatchWorkItem?
    private var bumpWorkItem: DispatchWorkItem?

    private init() {
        let s = GameStorage.load(Save.self, game: StickerBook.folder, file: "stickers.json")
        let savedFound = Set(s?.found ?? [])
        let savedUnseen = Set(s?.unseen ?? [])
        found = savedFound.filter { !GameStorage.isRetiredGameRecord($0) }
        unseen = savedUnseen.filter { !GameStorage.isRetiredGameRecord($0) }
        if found != savedFound || unseen != savedUnseen { save() }
    }

    static func key(_ game: String, _ id: String) -> String { "\(game)/\(id)" }

    func has(game: String, id: String) -> Bool { found.contains(StickerBook.key(game, id)) }

    /// She found it. Returns true the first time (when the sticker pops up and flies into the book).
    @discardableResult
    func find(game: String, id: String) -> Bool {
        let k = StickerBook.key(game, id)
        guard !found.contains(k) else { return false }
        let now = Date()
        found.insert(k)
        unseen.insert(k)
        lastFind = (game, id, now)
        isToastActive = true
        isButtonBumping = true
        scheduleFindSettle(at: now)
        Sound.shared.play(.fanfare, volume: 0.5)
        save()
        return true
    }

    private func scheduleFindSettle(at foundAt: Date) {
        toastWorkItem?.cancel()
        let toastWork = DispatchWorkItem { [weak self] in
            guard let self = self, self.lastFind?.at == foundAt else { return }
            self.isToastActive = false
        }
        toastWorkItem = toastWork
        DispatchQueue.main.asyncAfter(deadline: .now() + StickerToast.flight + 0.05, execute: toastWork)

        bumpWorkItem?.cancel()
        let bumpWork = DispatchWorkItem { [weak self] in
            guard let self = self, self.lastFind?.at == foundAt else { return }
            self.isButtonBumping = false
        }
        bumpWorkItem = bumpWork
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.landingWindow, execute: bumpWork)
    }

    func count(game: String) -> Int { found.filter { $0.hasPrefix(game + "/") }.count }

    func progress(game: String, stickers: [Sticker]) -> PageProgress {
        let foundCount = stickers.filter { has(game: game, id: $0.id) }.count
        return PageProgress(found: foundCount, total: stickers.count)
    }

    func isPageComplete(game: String, stickers: [Sticker]) -> Bool {
        progress(game: game, stickers: stickers).isComplete
    }

    func hasUnseen(game: String? = nil) -> Bool {
        guard let game else { return !unseen.isEmpty }
        return unseen.contains { $0.hasPrefix(game + "/") }
    }

    /// Returns the full sticker keys (`"<game>/<id>"`) currently unseen for `game`.
    func unseenKeys(game: String) -> Set<String> {
        unseen.filter { $0.hasPrefix(game + "/") }
    }

    /// Snapshots unseen sticker keys for `game` before marking that game's stickers as seen.
    @discardableResult
    func consumeUnseen(game: String) -> Set<String> {
        let snapshot = unseenKeys(game: game)
        if !snapshot.isEmpty {
            markSeen(game: game)
        }
        return snapshot
    }

    /// She opened this game's page: its new stickers aren't new anymore.
    func markSeen(game: String) {
        let before = unseen.count
        unseen = unseen.filter { !$0.hasPrefix(game + "/") }
        if unseen.count != before { save() }
    }

    func isToastAnimating(for game: String, at now: Date = Date()) -> Bool {
        guard isToastActive, let f = lastFind, f.game == game else { return false }
        let a = now.timeIntervalSince(f.at)
        return a >= 0 && a < StickerToast.flight
    }

    func isLandingBumpActive(for game: String?, at now: Date = Date()) -> Bool {
        guard isButtonBumping, let f = lastFind, game == nil || f.game == game else { return false }
        let a = now.timeIntervalSince(f.at)
        return a >= 0 && a < Self.landingWindow
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

    #if DEBUG
    /// Tests only: an empty sticker book that never saves.
    func resetForTests() {
        toastWorkItem?.cancel()
        toastWorkItem = nil
        bumpWorkItem?.cancel()
        bumpWorkItem = nil
        isToastActive = false
        isButtonBumping = false
        demo = true
        found = []
        unseen = []
        lastFind = nil
    }
    #endif
}

// MARK: - Drawing one sticker

/// A sticker in color with a white die-cut edge, or (not found yet) a softly tinted silhouette of it.
struct StickerArt: View {
    let sticker: Sticker
    let found: Bool
    var tint: Color? = nil

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
        } else if let tint {
            LinearGradient(
                colors: [tint.opacity(0.45), Theme.ink.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .mask { art }
            .shadow(color: tint.opacity(0.32), radius: 4, y: 1)
        } else {
            Theme.ink.opacity(0.18).mask { art }
        }
    }
}

// MARK: - The book's button

/// A round book button. It sparkles while there are new stickers to look at, and bounces when one flies in.
struct StickerBookButton: View {
    var game: String?
    var size: CGFloat = 72
    let action: () -> Void
    @ObservedObject private var book = StickerBook.shared

    init(game: String? = nil, size: CGFloat = 72, action: @escaping () -> Void) {
        self.game = game
        self.size = size
        self.action = action
    }

    var body: some View {
        let fresh = book.hasUnseen(game: game)
        let bumping = book.isLandingBumpActive(for: game)
        let animating = fresh || bumping
        Button {
            Sound.shared.play(.flip, volume: 0.7)
            Sound.shared.tap()
            action()
        } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animating)) { tl in
                let now = tl.date
                // a sticker lands in the book about 1.7 s after it is found
                let landed = bumping ? (book.lastFind.map { now.timeIntervalSince($0.at) - StickerToast.flight } ?? -10) : -10
                let bump = CGFloat(landed > 0 && landed < StickerBook.buttonBumpDuration
                                   ? sin(landed / StickerBook.buttonBumpDuration * .pi) * 0.3 : 0)
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
        .accessibilityLabel("Sticker Book")
    }
}

// MARK: - A new sticker pops up and flies into the book

/// Put over a game (in its 1024 x 834 controls layer). When she finds something, its sticker pops up big in the
/// middle with a burst of stars, then shrinks and flies into the book button at `target`.
struct StickerToast: View {
    let game: String
    let target: CGPoint
    var center = CGPoint(x: 512, y: 330)
    @ObservedObject private var book = StickerBook.shared

    static let flight = 1.7

    init(game: String, target: CGPoint, center: CGPoint = CGPoint(x: 512, y: 330)) {
        self.game = game
        self.target = target
        self.center = center
    }

    var body: some View {
        let active = book.isToastAnimating(for: game)
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !active)) { tl in
            if active, let f = book.lastFind, f.game == game, let s = StickerBook.sticker(game: f.game, id: f.id) {
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

// MARK: - Decorative book badges

private struct TabUnseenBadge: View {
    var active: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !active)) { tl in
            let t = active ? tl.date.timeIntervalSinceReferenceDate : 0
            ZStack {
                Circle()
                    .fill(Theme.lilac)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.lemon)
                    .rotationEffect(.radians(active ? sin(t * 2.4) * 0.18 : 0))
                    .scaleEffect(CGFloat(active ? 0.88 + 0.18 * sin(t * 5) : 1))
            }
            .frame(width: 26, height: 26)
            .shadow(color: Theme.ink.opacity(0.28), radius: 2, y: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Plump storybook golden crown with three pastel jewels, drawn vector-crisp at any size.
private struct StorybookCrown: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            var crown = Path()
            crown.move(to: CGPoint(x: w * 0.14, y: h * 0.82))
            crown.addLine(to: CGPoint(x: w * 0.08, y: h * 0.34))
            crown.addLine(to: CGPoint(x: w * 0.32, y: h * 0.56))
            crown.addLine(to: CGPoint(x: w * 0.50, y: h * 0.18))
            crown.addLine(to: CGPoint(x: w * 0.68, y: h * 0.56))
            crown.addLine(to: CGPoint(x: w * 0.92, y: h * 0.34))
            crown.addLine(to: CGPoint(x: w * 0.86, y: h * 0.82))
            crown.addQuadCurve(to: CGPoint(x: w * 0.14, y: h * 0.82), control: CGPoint(x: w * 0.50, y: h * 0.92))
            crown.closeSubpath()

            let gold = Gradient(colors: [Color(hex: 0xFFF3A8), Color(hex: 0xFFD452), Color(hex: 0xF5B324)])
            ctx.fill(crown, with: .linearGradient(gold, startPoint: CGPoint(x: w * 0.5, y: h * 0.14), endPoint: CGPoint(x: w * 0.5, y: h * 0.88)))
            let strokeWidth = max(1.5, min(w, h) * 0.065)
            ctx.stroke(crown, with: .color(Color(hex: 0xC98814)),
                       style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))

            // Peak pearls
            let tipR = min(w, h) * 0.075
            for pt in [CGPoint(x: w * 0.08, y: h * 0.30), CGPoint(x: w * 0.50, y: h * 0.14), CGPoint(x: w * 0.92, y: h * 0.30)] {
                let circle = Path(ellipseIn: CGRect(x: pt.x - tipR, y: pt.y - tipR, width: tipR * 2, height: tipR * 2))
                ctx.fill(circle, with: .color(Color(hex: 0xFFF6C2)))
                ctx.stroke(circle, with: .color(Color(hex: 0xC98814)), lineWidth: max(1, strokeWidth * 0.7))
            }

            // Three pastel crown jewels along the band
            let gemR = min(w, h) * 0.075
            let gems: [(CGPoint, Color)] = [
                (CGPoint(x: w * 0.30, y: h * 0.71), Theme.mint),
                (CGPoint(x: w * 0.50, y: h * 0.68), Theme.pink),
                (CGPoint(x: w * 0.70, y: h * 0.71), Theme.sky),
            ]
            for (pt, color) in gems {
                let gem = Path(ellipseIn: CGRect(x: pt.x - gemR, y: pt.y - gemR, width: gemR * 2, height: gemR * 2))
                ctx.fill(gem, with: .color(color))
                ctx.stroke(gem, with: .color(.white.opacity(0.85)), lineWidth: max(1, strokeWidth * 0.45))
            }
        }
    }
}

private struct TabCompleteBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFF2B2))
                .overlay(Circle().stroke(.white, lineWidth: 2))
            StorybookCrown()
                .frame(width: 17, height: 15)
        }
        .frame(width: 26, height: 26)
        .shadow(color: Theme.ink.opacity(0.25), radius: 2, y: 1)
        .allowsHitTesting(false)
    }
}

private struct NewStickerHalo: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(RadialGradient(
                    colors: [Color(hex: 0xFFF5B8).opacity(pulse ? 0.95 : 0.6), Color(hex: 0xFFE38A).opacity(0)],
                    center: .center,
                    startRadius: 10,
                    endRadius: 88
                ))
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color(hex: 0xFFB830), lineWidth: pulse ? 5.5 : 4)
                .shadow(color: Color(hex: 0xFFCA3A).opacity(pulse ? 0.85 : 0.4), radius: pulse ? 10 : 4)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct NewStickerBadge: View {
    let key: String
    @State private var pulse = false

    var body: some View {
        ZStack {
            SparkleBurst(colors: [Theme.lemon, Color(hex: 0xFFD45A), .white], count: 8, radius: 66)
                .id("new-\(key)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0xFFB830))
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
            .scaleEffect(pulse ? 1.14 : 0.94)
            .shadow(color: Color(hex: 0xC98814).opacity(0.35), radius: 3, y: 1)
            .offset(x: 6, y: -6)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct LockedHintBadge: View {
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.85))
            Circle()
                .fill(tint.opacity(0.32))
            Circle()
                .stroke(.white, lineWidth: 2)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink.opacity(0.55))
        }
        .frame(width: 28, height: 28)
        .overlay(alignment: .topTrailing) {
            Twinkle()
                .fill(Theme.lemon)
                .frame(width: 11, height: 11)
                .shadow(color: Theme.ink.opacity(0.25), radius: 1)
                .offset(x: 2, y: -2)
        }
        .shadow(color: tint.opacity(0.25), radius: 2, y: 1)
        .allowsHitTesting(false)
    }
}

// MARK: - The book itself

/// The open book: a tab for each game down the side, that game's stickers on the page.
struct StickerBookView: View {
    let close: () -> Void
    @ObservedObject private var book = StickerBook.shared
    @State private var page: String
    @State private var poke: [String: Date] = [:]
    @State private var highlighted: Set<String> = []
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
            DesignCanvas {
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
                    .accessibilityLabel("Close")
                    .offset(x: 18, y: -18)
                }
                .scaleEffect(shown ? 1 : 0.85)
                .opacity(shown ? 1 : 0)
            }
        }
        .onAppear {
            openPage(page, playSparkleIfComplete: true)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { shown = true }
        }
    }

    private func openPage(_ gameID: String, playSparkleIfComplete: Bool) {
        let newlySeen = book.consumeUnseen(game: gameID)
        if !newlySeen.isEmpty {
            highlighted.formUnion(newlySeen)
        }
        if playSparkleIfComplete,
           let entry = StickerBook.pages.first(where: { $0.id == gameID }),
           book.isPageComplete(game: entry.id, stickers: entry.stickers) {
            Sound.shared.play(.sparkle, volume: 0.45)
        }
    }

    private func triggerPoke(_ key: String) {
        let now = Date()
        poke[key] = now
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            if poke[key] == now {
                poke.removeValue(forKey: key)
            }
        }
    }

    private func shut() {
        Sound.shared.play(.flip, volume: 0.6)
        close()
    }

    private var tabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(StickerBook.pages) { g in
                        let selected = page == g.id
                        let unseen = book.hasUnseen(game: g.id)
                        let complete = book.isPageComplete(game: g.id, stickers: g.stickers)
                        Button {
                            guard page != g.id else { return }
                            Sound.shared.play(.flip, volume: 0.6)
                            openPage(g.id, playSparkleIfComplete: true)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { page = g.id }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(g.tint.gradient)
                                g.icon().padding(8)
                            }
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(selected ? Theme.pink : .white, lineWidth: selected ? 6 : 4))
                            .overlay(alignment: .topTrailing) {
                                if unseen {
                                    TabUnseenBadge(active: true)
                                        .offset(x: 7, y: -7)
                                }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if complete {
                                    TabCompleteBadge()
                                        .offset(x: 7, y: 7)
                                }
                            }
                            .scaleEffect(selected ? 1.06 : 0.94)
                            .shadow(color: Theme.ink.opacity(0.2), radius: 5, y: 3)
                        }
                        .buttonStyle(Squish())
                        .accessibilityLabel(g.title)
                        .id(g.id)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
            }
            .frame(width: 140)
            .frame(maxHeight: .infinity)
            .background(Theme.blush.opacity(0.6))
            .onAppear {
                proxy.scrollTo(page, anchor: .center)
            }
        }
    }

    private func starRows(for stickers: [Sticker], gameID: String) -> some View {
        let rowCount = max(1, (stickers.count + 17) / 18)
        let maxPerRow = max(1, (stickers.count + rowCount - 1) / rowCount)
        let rows: [[Sticker]] = stride(from: 0, to: stickers.count, by: maxPerRow).map {
            Array(stickers[$0..<min($0 + maxPerRow, stickers.count)])
        }
        let starSize: CGFloat = stickers.count > 14 ? 18 : 20
        let starSpacing: CGFloat = stickers.count > 14 ? 5 : 6
        return VStack(spacing: 4) {
            ForEach(0..<rows.count, id: \.self) { r in
                HStack(spacing: starSpacing) {
                    ForEach(rows[r]) { s in
                        let has = book.has(game: gameID, id: s.id)
                        Image(systemName: has ? "star.fill" : "star")
                            .font(.system(size: starSize, weight: .bold))
                            .foregroundStyle(has ? Theme.lemon : Theme.ink.opacity(0.2))
                            .shadow(color: has ? Theme.ink.opacity(0.25) : .clear, radius: 1, y: 1)
                    }
                }
            }
        }
    }

    private func completionHeader(for stickers: [Sticker], gameID: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                SparkleBurst(colors: [Theme.lemon, Theme.pink, Theme.mint, Theme.lilac, .white], count: 16, radius: 135)
                    .id("complete-\(gameID)")
                HStack(spacing: 6) {
                    Twinkle()
                        .fill(Theme.pink)
                        .frame(width: 16, height: 16)
                    StorybookCrown()
                        .frame(width: 48, height: 40)
                        .shadow(color: Color(hex: 0xC98814).opacity(0.25), radius: 3, y: 2)
                    Twinkle()
                        .fill(Theme.mint)
                        .frame(width: 16, height: 16)
                }
            }
            starRows(for: stickers, gameID: gameID)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xFFF9DC), Color(hex: 0xFFEDAA)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(Capsule().stroke(Color(hex: 0xFFD45A), lineWidth: 4))
        .shadow(color: Color(hex: 0xE2A726).opacity(0.28), radius: 8, y: 3)
    }

    @ViewBuilder private var pageView: some View {
        if let g = StickerBook.pages.first(where: { $0.id == page }) {
            let stickers = g.stickers
            let cols = stickers.count > 12 ? 5 : 4
            let complete = book.isPageComplete(game: g.id, stickers: stickers)
            VStack(spacing: 16) {
                if complete {
                    completionHeader(for: stickers, gameID: g.id)
                        .padding(.top, 20)
                        .padding(.horizontal, 30)
                } else {
                    starRows(for: stickers, gameID: g.id)
                        .padding(.top, 26)
                        .padding(.horizontal, 30)
                }
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: cols), spacing: 14) {
                        ForEach(stickers) { s in
                            cell(g, s, found: book.has(game: g.id, id: s.id))
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(g.id)
            .transition(.opacity)
        } else {
            Color.clear
        }
    }

    private func cell(_ game: GameEntry, _ s: Sticker, found: Bool) -> some View {
        let key = StickerBook.key(game.id, s.id)
        let isNew = found && highlighted.contains(key)
        let isPoked = poke[key] != nil
        return Button {
            if found {
                Sound.shared.play(.pop, volume: 0.7)
                Sound.shared.tap()
            } else {
                Sound.shared.play(.tap, volume: 0.4)
            }
            triggerPoke(key)
        } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !isPoked)) { tl in
                let a = isPoked ? (poke[key].map { tl.date.timeIntervalSince($0) } ?? 10) : 10
                let wiggleAmp = found ? 0.18 : 0.08
                let jig = a < 0.6 ? sin(a * 26) * wiggleAmp * (1 - a / 0.6) : 0
                let scalePop: CGFloat = found && a < 0.6 ? CGFloat(0.12 * sin(a / 0.6 * .pi)) : 0
                ZStack {
                    if found {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Theme.lemon, lineWidth: 4))
                    } else {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.78), game.tint.opacity(0.16)],
                                                 startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(game.tint.opacity(0.45), style: StrokeStyle(lineWidth: 3.5, dash: [10, 8])))
                            .shadow(color: game.tint.opacity(0.16), radius: 4, y: 2)
                    }
                    if isNew {
                        NewStickerHalo()
                    }
                    StickerArt(sticker: s, found: found, tint: found ? nil : game.tint)
                        .padding(14)
                        .rotationEffect(.radians(jig))
                        .scaleEffect(1 + scalePop)
                }
                .overlay {
                    if isNew {
                        NewStickerBadge(key: key)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !found {
                        LockedHintBadge(tint: game.tint)
                            .padding(8)
                    }
                }
                .frame(height: 132)
            }
        }
        .buttonStyle(Squish())
    }
}

// MARK: - Twinkles

/// Little four-point stars that come and go around something rare (a special plant, a rare fish).
enum Twinkles {
    static func draw(_ g: GraphicsContext, around p: CGPoint, radius: CGFloat, time t: CGFloat, count: Int, alpha: Double) {
        for i in 0..<count {
            let ph = t * 1.4 + CGFloat(i) * 2.1
            let k = abs(sin(ph))
            let a = CGFloat(i) * 2.4 + floor(ph / .pi) * 1.3
            let c = CGPoint(x: p.x + cos(a) * radius, y: p.y + sin(a) * radius * 0.8)
            let r = 4 + 6 * k
            var s = Path()
            s.move(to: CGPoint(x: c.x, y: c.y - r))
            s.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: c)
            s.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: c)
            s.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: c)
            s.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: c)
            g.fill(s, with: .color(Color(.sRGB, red: 1, green: 0.953, blue: 0.627, opacity: alpha * Double(0.35 + 0.65 * k))))
        }
    }
}
