import SwiftUI

struct StoryStage: View {
    let me: Look
    let friends: [Look]
    let close: () -> Void

    private struct Actor: Identifiable {
        let id = UUID()
        var look: Look?
        var thing: String?
        var x: Double
        var y: Double
        var flip = false
        var lift = false
        var happy = false
    }

    @State private var bg: String
    @State private var actors: [Actor]
    @State private var selectedActor: UUID?
    @State private var tab = 0
    @State private var moving: (id: UUID, x: Double, y: Double)?
    @State private var overBin = false
    @State private var flash = false
    @State private var snapBurst = 0

    init(me: Look, friends: [Look], close: @escaping () -> Void) {
        self.me = me
        self.friends = friends
        self.close = close
        _bg = State(initialValue: me.bg)
        var cast = [Actor(look: me, x: 0.36, y: 0.96)]
        if let f = friends.first { cast.append(Actor(look: f, x: 0.66, y: 0.9, flip: true)) }
        _actors = State(initialValue: cast)
        _selectedActor = State(initialValue: cast.first?.id)
    }

    private static let stageHeight: CGFloat = 620
    private static let trayHeight: CGFloat = 196
    private let art = DressUpArt.shared

    var body: some View {
        ZStack {
            SceneView(bg: bg)
                .ignoresSafeArea()
                .id(bg)
                .transition(.opacity)
            SceneLife(bg: bg)
                .ignoresSafeArea()
                .id("life." + bg)
            DesignCanvas {
                VStack(spacing: 0) {
                    GeometryReader { g in stage(g.size) }
                        .frame(height: Self.stageHeight)
                    tray
                        .frame(height: Self.trayHeight)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }
                .overlay(alignment: .top) {
                    HStack(spacing: 14) {
                        RoundButton(symbol: "chevron.down", tint: Theme.pink, size: GameChromeLayout.buttonSize) {
                            Sound.shared.play(.whoosh, volume: 0.6)
                            close()
                        }
                        Spacer()
                        if !actors.isEmpty {
                            RoundButton(symbol: "arrow.left.and.right", tint: Color(hex: 0x9B79E0), size: GameChromeLayout.buttonSize) {
                                flipSelected()
                            }
                        }
                        RoundButton(symbol: "camera.fill", tint: Color(hex: 0xF45C9A), size: GameChromeLayout.buttonSize) {
                            snapStage()
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                }
            }
            if flash {
                Color.white.ignoresSafeArea().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: bg)
    }

    // MARK: The stage

    private func depth(_ y: Double) -> CGFloat { 0.62 + 0.42 * CGFloat(max(0, min(1, (y - 0.35) / 0.65))) }

    private func stage(_ size: CGSize) -> some View {
        ZStack {
            ForEach(actors.sorted { $0.y < $1.y }) { a in actorView(a, in: size) }
            if snapBurst > 0 {
                TwinkleBurst(colors: [.white, Theme.lemon, Theme.pink], count: 16, radius: 220)
                    .id(snapBurst)
                    .position(x: size.width / 2, y: size.height * 0.45)
            }
            if moving != nil {
                Image(systemName: overBin ? "trash.fill" : "trash")
                    .font(.system(size: overBin ? 40 : 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 90, height: 90)
                    .background(Circle().fill(overBin ? Color(hex: 0xE8475A) : Theme.ink.opacity(0.45)))
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .position(binCenter(size))
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func binCenter(_ size: CGSize) -> CGPoint { CGPoint(x: size.width - 80, y: size.height - 70) }

    private func actorView(_ a: Actor, in size: CGSize) -> some View {
        let k = depth(a.y)
        let box = DressUpView.stageBox
        let dollH: CGFloat = 440 * k
        let w: CGFloat = a.look != nil ? dollH * box.width / box.height : (a.thing?.hasPrefix("pet:") == true ? 190 : 120) * k
        let h: CGFloat = a.look != nil ? dollH : w
        let isSelected = selectedActor == a.id
        return ZStack(alignment: .bottom) {
            if isSelected {
                Ellipse()
                    .fill(Theme.lemon.opacity(0.42))
                    .overlay(Ellipse().stroke(.white.opacity(0.85), lineWidth: 2.5))
                    .frame(width: max(64, w * 0.62), height: max(18, 22 * k))
                    .offset(y: 4)
            }
            Group {
                if let l = a.look {
                    DollView(look: l, expression: a.happy ? .happy : .normal, box: box)
                } else if let t = a.thing {
                    StickerView(kind: t, look: me)
                }
            }
            .frame(width: w, height: h)
            .scaleEffect(x: a.flip ? -1 : 1, y: 1)
            .scaleEffect(moving?.id == a.id ? 1.08 : 1, anchor: .bottom)
            .offset(y: a.lift ? -36 * k : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { flip(a.id) }
        .onTapGesture { poke(a.id) }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { v in
                    guard let i = index(a.id) else { return }
                    if moving?.id != a.id {
                        selectedActor = a.id
                        moving = (a.id, actors[i].x, actors[i].y)
                        Sound.shared.play(.tap, volume: 0.6)
                    }
                    guard let m = moving else { return }
                    actors[i].x = m.x + v.translation.width / size.width
                    actors[i].y = m.y + v.translation.height / size.height
                    let bin = inBin(actors[i], size)
                    if bin != overBin { withAnimation(.spring(response: 0.25)) { overBin = bin } }
                }
                .onEnded { _ in drop(a.id, size) }
        )
        .position(x: size.width * a.x, y: size.height * a.y - h / 2)
    }

    private func index(_ id: UUID) -> Int? { actors.firstIndex { $0.id == id } }

    private func inBin(_ a: Actor, _ size: CGSize) -> Bool {
        let c = binCenter(size)
        let dx = a.x * size.width - c.x, dy = a.y * size.height - c.y
        return dx * dx + dy * dy < 90 * 90
    }

    private func drop(_ id: UUID, _ size: CGSize) {
        defer { withAnimation(.spring(response: 0.3)) { moving = nil; overBin = false } }
        guard let i = index(id) else { return }
        if inBin(actors[i], size) || actors[i].x < -0.05 || actors[i].x > 1.05 {
            Sound.shared.play(.whoosh, volume: 0.7)
            _ = withAnimation(.spring(response: 0.3)) {
                actors.remove(at: i)
                if selectedActor == id { selectedActor = actors.last?.id }
            }
            return
        }
        Sound.shared.play(.pop, volume: 0.6)
        withAnimation(.spring(response: 0.3)) {
            actors[i].x = min(0.97, max(0.03, actors[i].x))
            actors[i].y = min(1.0, max(0.12, actors[i].y))
        }
    }

    /// Single tap: select, hop and smile without flipping direction.
    private func poke(_ id: UUID) {
        guard let i = index(id) else { return }
        selectedActor = id
        Sound.shared.play(actors[i].look != nil ? .boing : .bubble, volume: 0.7)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
            actors[i].lift = true
            actors[i].happy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard let j = index(id) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                actors[j].lift = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let j = index(id) { actors[j].happy = false }
        }
    }

    /// Double tap or flip button: turn the actor around cleanly.
    private func flip(_ id: UUID) {
        guard let i = index(id) else { return }
        selectedActor = id
        Sound.shared.play(.whoosh, volume: 0.65)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
            actors[i].flip.toggle()
            actors[i].lift = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            guard let j = index(id) else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                actors[j].lift = false
            }
        }
    }

    private func flipSelected() {
        if let id = selectedActor, index(id) != nil {
            flip(id)
        } else if let last = actors.last?.id {
            flip(last)
        }
    }

    private func snapStage() {
        Sound.shared.play(.fanfare, volume: 0.8)
        Sound.shared.tap()
        snapBurst += 1
        DressUpFind.storyDirector.unlock()
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.35)) { flash = false }
        }
        for i in actors.indices {
            let id = actors[i].id
            withAnimation(.spring(response: 0.24, dampingFraction: 0.5)) {
                actors[i].lift = true
                actors[i].happy = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let j = index(id) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { actors[j].lift = false }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                if let j = index(id) { actors[j].happy = false }
            }
        }
    }

    private func bringOn(look: Look? = nil, thing: String? = nil) {
        Sound.shared.play(.sparkle, volume: 0.7)
        Sound.shared.tap()
        var a = Actor(look: look, thing: thing, x: .random(in: 0.2...0.8), y: look != nil ? .random(in: 0.8...0.98) : .random(in: 0.45...0.95))
        a.flip = a.x > 0.5
        selectedActor = a.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            actors.append(a)
            if actors.count > 16 { actors.removeFirst(actors.count - 16) }
        }
    }

    // MARK: The tray: scenes, friends, props

    private var tray: some View {
        HStack(spacing: 14) {
            VStack(spacing: 8) {
                tabButton(0, symbol: "photo.fill", tint: Color(hex: 0x46B7B0))
                tabButton(1, symbol: "person.2.fill", tint: Color(hex: 0xF45C9A))
                tabButton(2, symbol: "star.fill", tint: Color(hex: 0xFFC93C))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    switch tab {
                    case 0: scenes
                    case 1: people
                    default: props
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Theme.cream.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(Theme.blush, lineWidth: 4))
        .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
    }

    private func tabButton(_ i: Int, symbol: String, tint: Color) -> some View {
        Button {
            Sound.shared.play(.tap)
            tab = i
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(tab == i ? .white : tint)
                .frame(width: 78, height: 48)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tab == i ? Theme.pink.opacity(0.9) : Theme.blush.opacity(0.7)))
        }
        .buttonStyle(Squish())
    }

    private func card<Content: View>(selected: Bool = false, width: CGFloat = 120, @ViewBuilder _ content: () -> Content,
                                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            content()
                .frame(width: width, height: 148)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: 0xFFF7FA)))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(selected ? Theme.pink : Color(hex: 0xF5DDE8), lineWidth: selected ? 6 : 3))
        }
        .buttonStyle(Squish())
    }

    @ViewBuilder private var scenes: some View {
        ForEach(art.category("bg")?.items ?? [], id: \.self) { id in
            card(selected: bg == id, width: 170) {
                SceneView(bg: id)
            } action: {
                Sound.shared.play(.ding, volume: 0.7)
                bg = id
            }
        }
    }

    @ViewBuilder private var people: some View {
        ForEach([me] + friends.prefix(30)) { l in
            card {
                DollView(look: l, box: CGRect(x: 110, y: 30, width: 380, height: 540))
                    .padding(6)
            } action: { bringOn(look: l) }
        }
    }

    @ViewBuilder private var props: some View {
        ForEach(Stickers.all(for: me).filter { $0 != "mypet" }, id: \.self) { kind in
            card(width: 110) {
                StickerView(kind: kind, look: me).padding(18)
            } action: { bringOn(thing: kind) }
        }
    }
}
