import SwiftUI
import Combine

// MARK: - Frame reading (own key so it never collides with the Boutique's)

private let houseSpace = "house"

private struct HouseFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private extension View {
    func houseFrame(_ id: String) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: HouseFrameKey.self, value: [id: g.frame(in: .named(houseSpace))])
        })
    }
}

// MARK: - Tools

enum HouseTool: Equatable {
    case food(String)
    case sponge
    case accessory(String)
    case takeOff
    var key: String {
        switch self {
        case .food(let id): return "food_" + id
        case .sponge: return "sponge"
        case .accessory(let id): return "acc_" + id
        case .takeOff: return "off"
        }
    }
}

struct HouseDrag {
    var tool: HouseTool
    var start: CGPoint
    var location: CGPoint
    var returning = false
    var flying = false
    var lastBubble: CGPoint? = nil
}

// MARK: - Glimmie House

/// Second game mode: feed, bathe and dress the Glimmies she has hatched.
struct HouseView: View {
    @EnvironmentObject var game: GameState
    @StateObject private var house = HouseState()
    let onClose: () -> Void

    @State private var selected = 0
    @State private var mode: CareMode = .feed
    @State private var drag: HouseDrag? = nil
    @State private var frames: [String: CGRect] = [:]
    @State private var now = Date()

    // pet reactions
    @State private var bobUp = false
    @State private var squish = false
    @State private var jump = false
    @State private var spin = false
    @State private var wiggle = false
    @State private var hearts: [Int] = []
    @State private var sparkles: [Int] = []
    @State private var seq = 0
    @State private var confetti = 0

    // bath
    @State private var bubbles: [CGPoint] = []   // unit coords on the pet
    @State private var rinsing = false

    @State private var hintFor: String? = nil
    @State private var lastHint = Date.distantPast

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var owned: [Int] { game.owned.isEmpty ? [0] : game.owned.sorted() }
    private var care: PetCare { house.care(selected, now: now) }
    private var petName: String { Glimmies.all[selected].name }

    var body: some View {
        GeometryReader { geo in
            let trayWidth = min(330, geo.size.width * 0.27)
            ZStack {
                RoomBackground()

                HStack(spacing: 0) {
                    picker
                        .frame(width: 140)
                    stage(size: CGSize(width: geo.size.width - 140 - trayWidth - 116, height: geo.size.height))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    tray(height: geo.size.height)
                        .frame(width: trayWidth)
                        .padding(.vertical, 18)
                    tabs
                        .frame(width: 104)
                        .padding(.trailing, 12)
                }

                if confetti > 0 { Confetti().id(confetti) }

                if let d = drag {
                    toolArt(d.tool)
                        .frame(width: 140, height: 140)
                        .scaleEffect(d.returning ? 1 : 1.15)
                        .shadow(color: Theme.ink.opacity(d.returning ? 0.1 : 0.3), radius: d.returning ? 4 : 14, y: d.returning ? 2 : 12)
                        .position(d.location)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: houseSpace)
            .onPreferenceChange(HouseFrameKey.self) { frames = $0 }
        }
        .onAppear(perform: appear)
        .onReceive(ticker) { now = $0 }
    }

    // MARK: Picker (her hatched Glimmies)

    private var picker: some View {
        VStack(spacing: 14) {
            CandyButton(symbol: "xmark", color: .white, size: 64) { onClose() }
                .padding(.top, 18)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(owned, id: \.self) { id in
                        pickerButton(id)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func pickerButton(_ id: Int) -> some View {
        let c = house.care(id, now: now)
        let isSel = selected == id
        return Button { select(id) } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.white.opacity(isSel ? 0.95 : 0.55))
                    .overlay(Circle().stroke(isSel ? Theme.gold : Color.white, lineWidth: isSel ? 6 : 3))
                    .shadow(color: Theme.ink.opacity(isSel ? 0.3 : 0.12), radius: isSel ? 8 : 3, y: 3)
                GlimmieView(kind: id, bob: false)
                    .padding(10)
                if c.allHappy {
                    needBadge("💖")
                } else if c.lowestValue < 0.35 {
                    needBadge(c.lowest.emoji)
                }
            }
            .frame(width: 108, height: 108)
            .scaleEffect(isSel ? 1.06 : 0.94)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSel)
        }
        .buttonStyle(SquishStyle())
    }

    private func needBadge(_ emoji: String) -> some View {
        Text(emoji)
            .font(.system(size: 26))
            .frame(width: 42, height: 42)
            .background(Circle().fill(Color.white).shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 2))
            .offset(x: 6, y: -6)
    }

    // MARK: Stage

    private func stage(size: CGSize) -> some View {
        let c = care
        let petSize = max(220, min(size.height * 0.56, size.width * 0.82))
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                ForEach(Need.allCases) { n in
                    NeedMeter(need: n, value: c.value(n))
                        .onTapGesture { Sound.shared.play(.tap, volume: 0.5); Sound.shared.say(needLine(c, focus: n)) }
                }
            }
            .padding(.top, 22)

            Spacer(minLength: 0)

            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.8, blue: 0.88), Color(red: 0.98, green: 0.66, blue: 0.8)],
                                         center: .center, startRadius: 4, endRadius: petSize * 0.6))
                    .overlay(Ellipse().stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 5, dash: [14, 10])).padding(10))
                    .frame(width: petSize * 1.15, height: petSize * 0.3)
                    .offset(y: petSize * 0.42)

                petView(c, size: petSize)

                if !c.allHappy, c.lowestValue < 0.35, drag == nil, !rinsing {
                    thoughtBubble(c.lowest)
                        .offset(x: petSize * 0.46, y: -petSize * 0.42)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: petSize * 1.15)

            Spacer(minLength: 0)
        }
    }

    private func petView(_ c: PetCare, size s: CGFloat) -> some View {
        let hovering = drag.map { !$0.returning && !$0.flying && isOverPet($0.location) } ?? false
        return ZStack {
            ZStack {
                GlimmieView(kind: selected, bob: false)
                MudSpots(amount: c.clean < 0.55 ? min(0.8, (0.55 - c.clean) * 1.8) : 0, size: s)
                ForEach(Array(bubbles.enumerated()), id: \.offset) { i, b in
                    SoapBubble()
                        .frame(width: s * (0.12 + 0.05 * CGFloat(i % 3)), height: s * (0.12 + 0.05 * CGFloat(i % 3)))
                        .position(x: b.x * s, y: b.y * s)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
                if let id = c.wearing, let a = HouseCatalog.accessory(id) {
                    accessoryOnPet(a, size: s)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
                if rinsing { RinseRain().frame(width: s, height: s) }
            }
            .frame(width: s, height: s)
            .scaleEffect(x: squish ? 1.12 : 1, y: squish ? 0.88 : 1, anchor: .bottom)
            .rotationEffect(.degrees(spin ? 360 : (wiggle ? 6 : 0)))
            .offset(y: (jump ? -s * 0.12 : 0) + (bobUp ? -8 : 4))
            .shadow(color: hovering ? Color.white : .clear, radius: hovering ? 22 : 0)

            ForEach(hearts, id: \.self) { _ in FloatingHearts(height: s * 0.6) }
            ForEach(sparkles, id: \.self) { _ in SparkleBurst(count: 14, radius: s * 0.5) }
        }
        .frame(width: s, height: s)
        .houseFrame("pet")
        .contentShape(Rectangle())
        .onTapGesture { tickle() }
    }

    @ViewBuilder
    private func accessoryOnPet(_ a: PetAccessory, size s: CGFloat) -> some View {
        if let art = a.art {
            // Icons carry 22px of padding on a 220px item, so scale the frame up to match.
            let img = Art.image("I_" + art).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            Group {
                if a.tinted { img.colorMultiply(HouseCatalog.bowColor(for: selected)) } else { img }
            }
            .frame(width: s * a.width * 1.2)
            .position(x: s * a.x, y: s * a.y)
        } else {
            PetGlasses()
                .frame(width: s * a.width, height: s * 0.17)
                .position(x: s * a.x, y: s * a.y)
        }
    }

    private func thoughtBubble(_ n: Need) -> some View {
        ZStack(alignment: .bottomLeading) {
            Circle().fill(Color.white).frame(width: 18, height: 18).offset(x: -18, y: 22)
            Circle().fill(Color.white).frame(width: 30, height: 30).offset(x: -4, y: 4)
            Text(n.emoji)
                .font(.system(size: 54))
                .frame(width: 96, height: 96)
                .background(Circle().fill(Color.white))
        }
        .shadow(color: Theme.ink.opacity(0.18), radius: 6, y: 3)
        .scaleEffect(bobUp ? 1.05 : 0.97)
        .onTapGesture { Sound.shared.say(needLine(care, focus: n)) }
    }

    // MARK: Tray + tabs

    private var tabs: some View {
        VStack(spacing: 18) {
            ForEach(CareMode.allCases) { m in
                Button { pickMode(m, speak: true) } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(m.color)
                            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white, lineWidth: mode == m ? 6 : 3))
                            .shadow(color: Theme.ink.opacity(mode == m ? 0.3 : 0.15), radius: mode == m ? 8 : 4, y: 3)
                        Text(m.emoji).font(.system(size: 52))
                    }
                    .frame(width: 92, height: 92)
                    .scaleEffect(mode == m ? 1.08 : 0.94)
                    .offset(x: mode == m ? -8 : 0)
                }
                .buttonStyle(SquishStyle())
            }
        }
    }

    private func tray(height: CGFloat) -> some View {
        let cell = min(140, (height - 140) / 3)
        return VStack(spacing: 16) {
            switch mode {
            case .feed:
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(HouseCatalog.foods) { f in toolCell(.food(f.id), size: cell, active: false) }
                }
            case .bath:
                toolCell(.sponge, size: min(200, cell * 1.4), active: false)
                    .padding(.top, 10)
                // bubble counter: fills as she scrubs
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(bubbles.count >= (i + 1) * 3 ? Color(red: 0.55, green: 0.8, blue: 1) : Color.white.opacity(0.6))
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .frame(width: 26, height: 26)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bubbles.count)
                CandyButton(symbol: "shower.fill", color: Color(red: 0.62, green: 0.84, blue: 1.0), size: 110) { shower() }
                    .scaleEffect(bubbles.count >= 4 && !rinsing ? (bobUp ? 1.1 : 0.98) : 1)
                    .opacity(rinsing ? 0.5 : 1)
            case .dress:
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(HouseCatalog.accessories) { a in
                        toolCell(.accessory(a.id), size: cell, active: care.wearing == a.id)
                    }
                    toolCell(.takeOff, size: cell, active: false)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 40).stroke(mode.color, lineWidth: 6))
                .shadow(color: Theme.ink.opacity(0.15), radius: 10, y: 4)
        )
        .id(mode)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private func toolCell(_ t: HouseTool, size: CGFloat, active: Bool) -> some View {
        let isDragged = drag?.tool == t
        return toolArt(t)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(active ? Color.white.opacity(0.9) : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(active ? mode.color : .clear, lineWidth: 4))
            )
            .opacity(isDragged ? 0.25 : 1)
            .scaleEffect(hintFor == t.key ? 1.12 : 1)
            .rotationEffect(.degrees(hintFor == t.key ? 6 : 0))
            .animation(.spring(response: 0.25, dampingFraction: 0.35), value: hintFor)
            .houseFrame("tool_" + t.key)
            .contentShape(Rectangle())
            .onTapGesture { tapTool(t) }
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named(houseSpace))
                    .onChanged { v in dragChanged(t, v) }
                    .onEnded { v in dragEnded(v) }
            )
    }

    @ViewBuilder
    private func toolArt(_ t: HouseTool) -> some View {
        switch t {
        case .food(let id):
            EmojiSticker(emoji: HouseCatalog.food(id)?.emoji ?? "🍓")
        case .sponge:
            EmojiSticker(emoji: "🧽")
        case .accessory(let id):
            if let a = HouseCatalog.accessory(id), let art = a.art {
                StickerIcon(name: art, tint: a.tinted ? HouseCatalog.bowColor(for: selected) : nil)
                    .padding(6)
            } else {
                ZStack {
                    Circle().fill(Color.white).shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 4)
                    PetGlasses().aspectRatio(2.6, contentMode: .fit).padding(16)
                }
                .padding(8)
            }
        case .takeOff:
            ZStack {
                Circle().fill(Color.white).shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 4)
                Circle().fill(Color(red: 1, green: 0.88, blue: 0.93)).padding(14)
                Image(systemName: "xmark").font(.system(size: 46, weight: .heavy)).foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.6))
            }
            .padding(14)
        }
    }

    // MARK: Drag + tap

    private func isOverPet(_ p: CGPoint) -> Bool {
        guard let f = frames["pet"] else { return false }
        return f.insetBy(dx: -30, dy: -30).contains(p)
    }

    private func center(_ r: CGRect) -> CGPoint { CGPoint(x: r.midX, y: r.midY) }

    private func dragChanged(_ t: HouseTool, _ v: DragGesture.Value) {
        if rinsing && t == .sponge { return }
        let lifted = CGPoint(x: v.location.x, y: v.location.y - 30)
        if drag == nil || drag?.returning == true || drag?.tool != t {
            guard drag?.flying != true else { return }
            Sound.shared.play(.tap, volume: 0.5)
            Sound.shared.tapHaptic()
            drag = HouseDrag(tool: t, start: v.startLocation, location: lifted)
        }
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.5)) { drag?.location = lifted }
        if t == .sponge { scrub(at: lifted) }
    }

    private func dragEnded(_ v: DragGesture.Value) {
        guard var d = drag, !d.returning, !d.flying else { return }
        let lifted = CGPoint(x: v.location.x, y: v.location.y - 30)
        if d.tool != .sponge, isOverPet(lifted) || isOverPet(v.location) {
            drag = nil
            apply(d.tool)
            return
        }
        if d.tool != .sponge { Sound.shared.play(.boing, volume: 0.6) }
        d.returning = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            d.location = d.start
            drag = d
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            if drag?.returning == true { drag = nil }
        }
    }

    /// Tapping a snack or accessory sends it flying to the Glimmie, so dragging is optional.
    private func tapTool(_ t: HouseTool) {
        hintFor = t.key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { if hintFor == t.key { hintFor = nil } }
        if t == .sponge {
            Sound.shared.play(.tap, volume: 0.5)
            if Date().timeIntervalSince(lastHint) > 3 {
                lastHint = Date()
                Sound.shared.say("Rub \(petName) with the sponge!")
            }
            return
        }
        guard drag == nil else { return }
        guard let from = frames["tool_" + t.key], let pet = frames["pet"] else { apply(t); return }
        let target: CGPoint
        switch t {
        case .food: target = CGPoint(x: pet.midX, y: pet.minY + pet.height * 0.62)
        case .accessory(let id):
            let a = HouseCatalog.accessory(id)
            target = CGPoint(x: pet.minX + pet.width * (a?.x ?? 0.5), y: pet.minY + pet.height * (a?.y ?? 0.3))
        default: target = center(pet)
        }
        Sound.shared.play(.whoosh, volume: 0.5)
        drag = HouseDrag(tool: t, start: center(from), location: center(from), flying: true)
        DispatchQueue.main.async {
            withAnimation(.easeIn(duration: 0.4)) { drag?.location = target }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.43) {
            guard drag?.flying == true else { return }
            drag = nil
            apply(t)
        }
    }

    // MARK: Care actions

    private func apply(_ t: HouseTool) {
        let was = care.allHappy
        switch t {
        case .food(let id):
            guard let f = HouseCatalog.food(id) else { return }
            if care.tummy >= 0.97 {
                Sound.shared.play(.boing, volume: 0.6)
                Sound.shared.say("\(petName) is full! Maybe later!")
                shake()
                return
            }
            house.update(selected) { $0.tummy += 0.35; $0.love += 0.05 }
            munch()
            Sound.shared.say("Yum yum! " + f.loves)
        case .accessory(let id):
            guard let a = HouseCatalog.accessory(id) else { return }
            if care.wearing == id {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { house.update(selected) { $0.wearing = nil } }
                Sound.shared.play(.whoosh)
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    house.update(selected) { $0.wearing = id; $0.love += 0.35 }
                }
                Sound.shared.play(.pop)
                Sound.shared.play(.sparkle, volume: 0.5)
                burst()
                hop()
                Sound.shared.say("\(petName) loves the \(a.name)!")
            }
        case .takeOff:
            guard care.wearing != nil else { Sound.shared.play(.boing, volume: 0.5); return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { house.update(selected) { $0.wearing = nil } }
            Sound.shared.play(.whoosh)
        case .sponge:
            return
        }
        Sound.shared.tapHaptic()
        finish(wasHappy: was)
    }

    private func scrub(at p: CGPoint) {
        guard !rinsing, let f = frames["pet"], f.width > 0 else { return }
        let u = CGPoint(x: (p.x - f.minX) / f.width, y: (p.y - f.minY) / f.height)
        // only on the Glimmie's round body
        let dx = (u.x - 0.5) / 0.34, dy = (u.y - 0.55) / 0.36
        guard dx * dx + dy * dy <= 1 else { return }
        if let last = drag?.lastBubble, hypot(p.x - last.x, p.y - last.y) < f.width * 0.08 { return }
        drag?.lastBubble = p
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bubbles.append(u) }
        if bubbles.count % 2 == 1 { Sound.shared.play(.pop, volume: 0.45) }
        Sound.shared.tapHaptic()
        if bubbles.count == 1 { Sound.shared.say("Scrub scrub!") }
        if bubbles.count >= 16 { rinse() }
    }

    private func shower() {
        guard !rinsing else { return }
        if mode == .bath, bubbles.count >= 4 {
            rinse()
        } else {
            Sound.shared.play(.boing, volume: 0.5)
            Sound.shared.say("Rub on bubbles with the sponge first!")
        }
    }

    private func rinse() {
        guard !rinsing else { return }
        let was = care.allHappy
        rinsing = true
        if drag?.tool == .sponge { drag = nil }
        Sound.shared.play(.whoosh)
        Sound.shared.say("Rinse, rinse!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.4)) { bubbles.removeAll() }
            rinsing = false
            house.update(selected) { $0.clean = 1; $0.love += 0.1 }
            Sound.shared.play(.sparkle)
            Sound.shared.play(.ding, volume: 0.6)
            burst()
            hop()
            Sound.shared.say("Squeaky clean!")
            finish(wasHappy: was)
        }
    }

    private func tickle() {
        guard drag == nil, !rinsing else { return }
        let was = care.allHappy
        house.update(selected) { $0.love += 0.15 }
        Sound.shared.play(.boing, volume: 0.5)
        Sound.shared.tapHaptic()
        Sound.shared.say(["Hee hee!", "That tickles!", "I love you!", "Again! Again!", "You're my best friend!"].randomElement()!)
        seq += 1
        let id = seq
        hearts.append(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { hearts.removeAll { $0 == id } }
        hop()
        finish(wasHappy: was)
    }

    /// After any care: refresh, and celebrate the moment every need is full.
    private func finish(wasHappy: Bool) {
        now = Date()
        guard !wasHappy, care.allHappy else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            confetti += 1
            Sound.shared.play(.fanfare)
            withAnimation(.easeInOut(duration: 0.8)) { spin = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { spin = false }
            Sound.shared.say("\(petName) is so happy! Hooray!", interrupt: false)
        }
    }

    // MARK: Little animations

    private func munch() {
        Sound.shared.play(.pop)
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.22) {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { squish = true }
                if i > 0 { Sound.shared.play(.tap, volume: 0.7) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { squish = false }
                }
            }
        }
        burst()
    }

    private func hop() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { jump = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { jump = false }
        }
    }

    private func shake() {
        withAnimation(.easeInOut(duration: 0.08)) { wiggle = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.3)) { wiggle = false }
        }
    }

    private func burst() {
        seq += 1
        let id = seq
        sparkles.append(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { sparkles.removeAll { $0 == id } }
    }

    // MARK: Flow

    private func pickMode(_ m: CareMode, speak: Bool) {
        guard mode != m else { return }
        Sound.shared.play(.tap, volume: 0.6)
        if drag != nil { drag = nil }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { mode = m }
        if speak { Sound.shared.say(m.spoken) }
    }

    private func select(_ id: Int) {
        guard id != selected else {
            Sound.shared.say(needLine(care, focus: nil))
            return
        }
        Sound.shared.play(.ding, volume: 0.7)
        drag = nil
        rinsing = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            selected = id
            bubbles = []
        }
        let c = house.care(id)
        if !c.allHappy, c.lowestValue < 0.7 { pickMode(c.lowest.mode, speak: false) }
        Sound.shared.say("Hi! It's \(Glimmies.all[id].name)! " + needLine(c, focus: nil))
    }

    private func needLine(_ c: PetCare, focus: Need?) -> String {
        let n = petName
        if focus == nil, c.allHappy { return "\(n) is so happy!" }
        let need = focus ?? c.lowest
        let v = c.value(need)
        switch need {
        case .tummy:
            return v >= 0.95 ? "\(n)'s tummy is full!" : "\(n) is hungry! Let's find a yummy snack!"
        case .clean:
            return v >= 0.95 ? "\(n) is sparkly clean!" : "\(n) is messy! Rub on bubbles with the sponge!"
        case .love:
            return v >= 0.95 ? "\(n) feels so loved!" : "\(n) wants some love! Try a tickle, or something pretty to wear!"
        }
    }

    private func appear() {
        if !owned.contains(selected) { selected = owned.first ?? 0 }
        now = Date()
        let c = care
        if !c.allHappy, c.lowestValue < 0.7 { mode = c.lowest.mode }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bobUp = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            Sound.shared.say("Welcome to Glimmie House! " + needLine(care, focus: nil))
        }
    }
}

// MARK: - Pieces

/// A need shown as a picture plus a bar, readable without words.
struct NeedMeter: View {
    let need: Need
    let value: Double
    var body: some View {
        HStack(spacing: 8) {
            Text(need.emoji)
                .font(.system(size: 34))
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.white))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.7))
                Capsule()
                    .fill(LinearGradient(colors: [need.color.opacity(0.75), need.color], startPoint: .top, endPoint: .bottom))
                    .frame(width: max(24, 130 * value))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
            }
            .frame(width: 130, height: 26)
            .overlay(Capsule().stroke(Color.white, lineWidth: 3))
        }
        .padding(.leading, 6).padding(.trailing, 14).padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.5)).shadow(color: Theme.ink.opacity(0.15), radius: 5, y: 3))
    }
}

/// A big emoji on a white die-cut circle, sized to its frame.
struct EmojiSticker: View {
    let emoji: String
    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(Color.white).shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 4)
                Text(emoji).font(.system(size: d * 0.56))
            }
            .frame(width: d * 0.9, height: d * 0.9)
            .position(x: g.size.width / 2, y: g.size.height / 2)
        }
    }
}

struct PetGlasses: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let lens = min(h, w * 0.4)
            let rim = Color(red: 0.96, green: 0.38, blue: 0.64)
            HStack(spacing: 0) {
                glassLens(rim).frame(width: lens, height: lens)
                Capsule().fill(rim).frame(width: max(4, w - lens * 2), height: max(4, lens * 0.12))
                glassLens(rim).frame(width: lens, height: lens)
            }
            .frame(width: w, height: h)
        }
    }

    private func glassLens(_ rim: Color) -> some View {
        Circle()
            .fill(Color(red: 1, green: 0.6, blue: 0.82).opacity(0.5))
            .overlay(Circle().stroke(rim, lineWidth: 6))
            .overlay(
                Ellipse().fill(Color.white.opacity(0.75))
                    .frame(width: 14, height: 8).rotationEffect(.degrees(-30))
                    .offset(x: -10, y: -12)
            )
    }
}

struct SoapBubble: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color.white.opacity(0.35), Color(red: 0.85, green: 0.93, blue: 1).opacity(0.85)],
                                 center: .center, startRadius: 1, endRadius: 40))
            .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
            .overlay(
                Circle().fill(Color.white.opacity(0.9))
                    .frame(width: 9, height: 9)
                    .offset(x: -8, y: -8)
            )
            .shadow(color: Color(red: 0.5, green: 0.7, blue: 1).opacity(0.3), radius: 3)
    }
}

/// Muddy splotches that fade as the Glimmie gets clean.
struct MudSpots: View {
    let amount: Double
    let size: CGFloat
    private let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.36, 0.66, 0.12), (0.64, 0.46, 0.09), (0.57, 0.76, 0.1), (0.3, 0.45, 0.07)]
    var body: some View {
        ZStack {
            ForEach(0..<spots.count, id: \.self) { i in
                let s = spots[i]
                Ellipse()
                    .fill(Color(red: 0.55, green: 0.38, blue: 0.27))
                    .frame(width: size * s.2 * 1.3, height: size * s.2)
                    .rotationEffect(.degrees(Double(i) * 37))
                    .position(x: size * s.0, y: size * s.1)
            }
        }
        .frame(width: size, height: size)
        .blur(radius: 1.5)
        .opacity(amount)
        .allowsHitTesting(false)
    }
}

/// Water drops falling over the Glimmie while it is rinsed.
struct RinseRain: View {
    private struct Drop { let x, delay, speed, len: Double }
    @State private var drops: [Drop] = (0..<40).map { _ in
        Drop(x: .random(in: 0.1...0.9), delay: .random(in: 0...0.9), speed: .random(in: 0.9...1.4), len: .random(in: 14...26))
    }
    @State private var start = Date()
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                for d in drops {
                    let tt = (t - d.delay) * d.speed
                    guard tt > 0 else { continue }
                    let y = (tt.truncatingRemainder(dividingBy: 0.8)) / 0.8 * size.height * 1.1 - 20
                    let r = CGRect(x: d.x * size.width - 4, y: y, width: 8, height: d.len)
                    ctx.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(Color(red: 0.45, green: 0.72, blue: 1).opacity(0.75)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Hearts that float up and fade.
struct FloatingHearts: View {
    let height: CGFloat
    @State private var go = false
    @State private var parts: [(CGFloat, CGFloat, Double)] = (0..<7).map { _ in
        (.random(in: -90...90), .random(in: 26...46), .random(in: 0.7...1.0))
    }
    var body: some View {
        ZStack {
            ForEach(0..<parts.count, id: \.self) { i in
                let p = parts[i]
                Image(systemName: "heart.fill")
                    .font(.system(size: p.1))
                    .foregroundColor(i % 2 == 0 ? Color(red: 1, green: 0.45, blue: 0.7) : Color(red: 1, green: 0.7, blue: 0.85))
                    .shadow(color: .white, radius: 3)
                    .offset(x: p.0 * (go ? 1.3 : 0.4), y: go ? -height * CGFloat(p.2) : 0)
                    .opacity(go ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { go = true } }
    }
}

/// A cozy room: dotted wallpaper, a bunting garland and a wooden floor.
struct RoomBackground: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.86), Color(red: 1, green: 0.85, blue: 0.9)],
                               startPoint: .top, endPoint: .bottom)
                Canvas { ctx, size in
                    // wallpaper dots
                    let step: CGFloat = 54
                    var row = 0
                    var y: CGFloat = 20
                    while y < size.height * 0.72 {
                        var x: CGFloat = row % 2 == 0 ? 20 : 20 + step / 2
                        while x < size.width {
                            ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)),
                                     with: .color(Color.white.opacity(0.7)))
                            x += step
                        }
                        y += step * 0.8
                        row += 1
                    }
                    // bunting
                    let colors: [Color] = [Color(red: 1, green: 0.6, blue: 0.75), Color(red: 1, green: 0.85, blue: 0.45),
                                           Color(red: 0.6, green: 0.82, blue: 1), Color(red: 0.7, green: 0.9, blue: 0.7),
                                           Color(red: 0.8, green: 0.68, blue: 1)]
                    var string = Path()
                    string.move(to: CGPoint(x: 0, y: 8))
                    string.addQuadCurve(to: CGPoint(x: size.width, y: 8), control: CGPoint(x: size.width / 2, y: 70))
                    ctx.stroke(string, with: .color(Color.white), lineWidth: 3)
                    let flags = 16
                    for i in 0..<flags {
                        let t0 = (CGFloat(i) + 0.15) / CGFloat(flags), t1 = (CGFloat(i) + 0.85) / CGFloat(flags)
                        func pt(_ t: CGFloat) -> CGPoint {
                            let a = CGPoint(x: 0, y: 8), c = CGPoint(x: size.width / 2, y: 70), b = CGPoint(x: size.width, y: 8)
                            let u = 1 - t
                            return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
                        }
                        let p0 = pt(t0), p1 = pt(t1)
                        var flag = Path()
                        flag.move(to: p0)
                        flag.addLine(to: p1)
                        flag.addLine(to: CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2 + 34))
                        flag.closeSubpath()
                        ctx.fill(flag, with: .color(colors[i % colors.count]))
                    }
                }
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.85)).frame(height: 8)
                    LinearGradient(colors: [Color(red: 0.96, green: 0.8, blue: 0.68), Color(red: 0.9, green: 0.7, blue: 0.6)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: h * 0.28)
                        .overlay(
                            HStack(spacing: 0) {
                                ForEach(0..<8, id: \.self) { _ in
                                    Rectangle().fill(Color.clear).frame(maxWidth: .infinity)
                                        .overlay(Rectangle().fill(Color.white.opacity(0.18)).frame(width: 3), alignment: .trailing)
                                }
                            }
                        )
                }
                .frame(width: w, height: h)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
