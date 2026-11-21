import SwiftUI

enum UnicornGame {
    static let id = "unicornstable"
    static let entry = GameEntry(
        id: id, title: "Unicorn Stable", tint: Theme.blush,
        icon: { AnyView(UnicornPortrait(look: UnicornLook())) },
        play: { exit in AnyView(UnicornStableView(exit: exit)) },
        stickers: MeadowVisitor.allCases.map(\.sticker)
    )
}

private extension CareTool {
    var symbol: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .sponge: return "bubbles.and.sparkles.fill"
        case .rinse: return "drop.fill"
        case .feed: return "carrot.fill"
        }
    }

    var color: Color {
        switch self {
        case .brush: return Color(hex: 0xAE654F)
        case .sponge: return Color(hex: 0x7870AA)
        case .rinse: return Color(hex: 0x357E9C)
        case .feed: return Color(hex: 0xCC691E)
        }
    }

    var sound: SFX {
        switch self {
        case .brush, .rinse: return .whoosh
        case .sponge: return .bubble
        case .feed: return .pop
        }
    }
}

private enum StableTray: String, CaseIterable {
    case care, coat, mane, horn, gear

    var symbol: String {
        switch self {
        case .care: return "heart.fill"
        case .coat: return "paintpalette.fill"
        case .mane: return "wind"
        case .horn: return "sparkles"
        case .gear: return "ribbon.fill"
        }
    }

    var colors: [UInt32] {
        switch self {
        case .coat: return [0xFFF8F1, 0xFFD1DB, 0xCFEAFF, 0xF0CFAB, 0xE4D1F3, 0xADDCC6]
        case .mane: return [0xF59FC4, 0xBAA4F3, 0x91D5E1, 0xF8B07D, 0xE8CF71, 0x8BD4AD]
        case .horn: return [0xFFC858, 0xFF9BBE, 0xB89EF8, 0x87D7E9, 0xB8EBB4, 0xFFF5C4]
        default: return []
        }
    }

    var keyPath: WritableKeyPath<UnicornLook, UInt32>? {
        switch self {
        case .coat: return \UnicornLook.coat
        case .mane: return \UnicornLook.mane
        case .horn: return \UnicornLook.horn
        default: return nil
        }
    }
}

private struct UnicornStableView: View {
    private struct Save: Codable {
        var look = UnicornLook()
        var care: StableCare?
    }

    private struct Reaction: Equatable {
        let tool: CareTool?
        let point: CGPoint
        let time = Date()
    }

    let exit: () -> Void
    @State private var save = GameStorage.load(Save.self, game: UnicornGame.id, file: "stable.json") ?? Save()
    @State private var tray: StableTray = .care
    @State private var tool: CareTool?
    @State private var finger: CGPoint?
    @State private var lastSpot: CareSpot?
    @State private var reaction: Reaction?
    @State private var book = false
    @State private var meadow = ProcessInfo.processInfo.arguments.contains("-unicornMeadow")
    @State private var pathX: CGFloat = 483
    @State private var guest: MeadowVisitor?
    @State private var strollStarted: Date?

    private let artFrame = CGRect(x: 200, y: 95, width: 640, height: 549)
    private var care: StableCare { save.care ?? StableCare() }

    var body: some View {
        DesignCanvas {
            ZStack {
                if meadow { meadowScene } else { stableScene }
                HStack(spacing: 16) {
                    HomeButton(action: exit)
                    Spacer()
                    CoinCounter(game: UnicornGame.id, height: 62)
                    StickerBookButton(game: UnicornGame.id, size: 66) { book = true }
                    RoundButton(symbol: meadow ? "house.lodge.fill" : "leaf.fill", tint: Color(hex: 0x74935F)) {
                        Sound.shared.play(.whoosh)
                        finishDrag()
                        guest = nil
                        withAnimation(.easeInOut(duration: 0.28)) { meadow.toggle() }
                    }
                    .accessibilityLabel(meadow ? "Return to the stable" : "Visit the meadow")
                }
                .padding(.horizontal, 28)
                .position(x: 512, y: 58)
                StickerToast(game: UnicornGame.id, target: CGPoint(x: 875, y: 58))
                if book {
                    StickerBookView(game: UnicornGame.id) { book = false }.zIndex(2)
                }
            }
            .frame(width: 1024, height: 834)
            .coordinateSpace(name: UnicornGame.id)
            .coinPurse(game: UnicornGame.id)
        }
        .background(Color(hex: meadow ? 0xCFD9AF : 0xAEA688).ignoresSafeArea())
    }

    private var stableScene: some View {
        ZStack {
            scenery("stable", color: Color(hex: 0xD5C59C))
            Ellipse().fill(Color(hex: 0x674833, alpha: 0.29)).blur(radius: 16)
                .frame(width: 430, height: 45).position(x: artFrame.midX, y: 625)
            AnimatedUnicorn(look: save.look, reaction: reaction?.time, motion: motion)
                .frame(width: artFrame.width, height: artFrame.height)
                .position(x: artFrame.midX, y: artFrame.midY)
            marks
            Rectangle().fill(.clear)
                .contentShape(Rectangle())
                .frame(width: artFrame.width, height: artFrame.height)
                .position(x: artFrame.midX, y: artFrame.midY)
                .gesture(careGesture())
                .accessibilityLabel("Care for your unicorn")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    if let tool, let spot = CareSpot.allCases.first(where: { care.spots(for: tool).contains($0) }) {
                        use(tool, at: spot)
                    } else { pet(at: point(.shoulder)) }
                }
            checklist.position(x: 113, y: 373)
            controls.position(x: 512, y: 732)
            effects
            if let finger, let tool { heldTool(tool, finger: finger).allowsHitTesting(false) }
        }
    }

    private var motion: UnicornMotion {
        switch reaction?.tool {
        case .feed: return .nibble
        case .rinse, .sponge: return .shake
        case .brush: return .lean
        case nil: return .nuzzle
        }
    }

    private func scenery(_ name: String, color: Color) -> some View {
        ZStack {
            color
            if let art = UnicornIllustration.source(name) {
                Image(uiImage: art).resizable().scaledToFill()
            }
            LinearGradient(colors: [.black.opacity(0.25), .clear, .clear], startPoint: .top, endPoint: .bottom)
        }
        .frame(width: 1024, height: 834)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var checklist: some View {
        VStack(spacing: 16) {
            checklistItem(.brush, done: care.groomed)
            checklistItem(care.dirt.isEmpty ? .rinse : .sponge, done: care.washed)
            checklistItem(.feed, done: care.fed)
            if care.complete {
                actionChip("arrow.counterclockwise", label: "Start another care round", color: Color(hex: 0x897247), size: 54) {
                    save.care = StableCare()
                    persist()
                    pick(.brush)
                }
            }
        }
        .padding(15)
        .background(Color(hex: 0xFFF4D8).opacity(0.94), in: RoundedRectangle(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32).strokeBorder(.white.opacity(0.65), lineWidth: 3))
        .shadow(color: .black.opacity(0.2), radius: 11, y: 4)
    }

    private func checklistItem(_ item: CareTool, done: Bool) -> some View {
        actionChip(done ? "checkmark" : item.symbol, label: done ? "\(item.rawValue.capitalized) done" : item.rawValue.capitalized,
                   color: done ? Color(hex: 0x567745) : item.color, size: 65, selected: tool == item && !done) { pick(item) }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 13) {
                ForEach(StableTray.allCases, id: \.self) { tab in
                    actionChip(tab.symbol, label: tab.rawValue.capitalized, color: Color(hex: 0x785675),
                               size: 51, selected: tab == tray) {
                        tray = tab
                        tool = nil
                        Sound.shared.play(.flip)
                    }
                }
            }
            HStack(spacing: 18) {
                if tray == .care {
                    ForEach(CareTool.allCases, id: \.self) { item in
                        chip(item.symbol, color: item.color, size: 88, selected: tool == item)
                            .contentShape(Circle())
                            .gesture(careGesture(from: item))
                            .accessibilityLabel(item.rawValue.capitalized)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { pick(item) }
                    }
                    actionChip("ribbon.fill", label: save.look.braided ? "Untie the mane" : "Tie the mane",
                               color: Color(hex: 0x825C91), size: 88, selected: save.look.braided) {
                        save.look.braided.toggle()
                        persist()
                        pet(at: point(.mane))
                    }
                } else if let key = tray.keyPath {
                    ForEach(tray.colors, id: \.self) { color in
                        actionChip("", label: "\(tray.rawValue.capitalized) color", color: Color(hex: color),
                                   size: 77, selected: save.look[keyPath: key] == color) {
                            save.look[keyPath: key] = color
                            persist()
                            pet(at: point(.shoulder))
                        }
                    }
                } else {
                    ForEach(UnicornGear.available, id: \.self) { gear in
                        actionChip(gear.symbol, label: gear == .none ? "Remove gear" : gear.rawValue.capitalized,
                                   color: Color(hex: 0x936580), size: 88, selected: save.look.gear == gear) {
                            save.look.gear = gear
                            persist()
                            pet(at: point(.mane))
                        }
                    }
                }
            }
            .frame(height: 96)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 11)
        .background(Color(hex: 0xFFF4DA).opacity(0.97), in: RoundedRectangle(cornerRadius: 36))
        .overlay(RoundedRectangle(cornerRadius: 36).strokeBorder(.white.opacity(0.8), lineWidth: 4))
        .shadow(color: .black.opacity(0.22), radius: 12, y: 4)
    }

    private func actionChip(_ symbol: String, label: String, color: Color, size: CGFloat, selected: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) { chip(symbol, color: color, size: size, selected: selected) }
            .buttonStyle(Squish())
            .accessibilityLabel(label)
    }

    private func chip(_ symbol: String, color: Color, size: CGFloat, selected: Bool) -> some View {
        ZStack {
            Circle().fill(symbol.isEmpty ? color : Color(hex: 0xFFFDF2))
            if !symbol.isEmpty {
                Image(systemName: symbol).font(.system(size: size * 0.43, weight: .bold)).foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(selected ? Color(hex: 0xB67A52) : Color(hex: 0xEEE0BF), lineWidth: selected ? 6 : 3))
    }

    private func point(_ spot: CareSpot) -> CGPoint {
        let anchor = UnicornIllustration.anchor(spot)
        let fit = UnicornIllustration.fitted(in: artFrame)
        return CGPoint(x: fit.minX + anchor.x * fit.width, y: fit.minY + anchor.y * fit.height)
    }

    private var marks: some View {
        ZStack {
            ForEach(CareSpot.allCases, id: \.self) { spot in
                let location = point(spot)
                let target = tool.map { care.spots(for: $0).contains(spot) } ?? false
                ZStack {
                    if target {
                        Circle().strokeBorder(.white.opacity(0.88), style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                    if care.burrs.contains(spot) {
                        Image(systemName: "leaf.fill").font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x977141)).rotationEffect(.degrees(-28))
                    } else if care.dirt.contains(spot) {
                        mud
                    } else if care.soap.contains(spot) {
                        bubbles
                    }
                }
                .frame(width: 71, height: 71).position(location)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var mud: some View {
        ZStack {
            Ellipse().fill(Color(hex: 0x91654A, alpha: 0.64)).frame(width: 33, height: 18).rotationEffect(.degrees(-19))
            Ellipse().fill(Color(hex: 0x6B4739, alpha: 0.49)).frame(width: 12, height: 8).offset(x: -17, y: -8)
            Ellipse().fill(Color(hex: 0xA67858, alpha: 0.55)).frame(width: 10, height: 7).offset(x: 14, y: 11)
        }
    }

    private var bubbles: some View {
        ZStack {
            ForEach(0..<7) { index in
                let size = CGFloat(15 + (index * 7) % 20)
                Circle().fill(RadialGradient(colors: [.white, Theme.sky.opacity(0.77), Theme.lilac.opacity(0.58)],
                                             center: .topLeading, startRadius: 3, endRadius: size))
                    .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                    .frame(width: size, height: size)
                    .offset(x: CGFloat(index * 11 % 41 - 20), y: CGFloat(index * 9 % 26 - 13))
            }
        }
    }

    private var effects: some View {
        Group {
            if let reaction {
                let colors = reaction.tool == .rinse ? [.white, Theme.sky, Theme.mint] : [.white, Theme.lemon, Theme.blush]
                SparkleBurst(colors: colors, count: care.complete ? 18 : 9, radius: care.complete ? 140 : 65)
                    .id(reaction.time).position(reaction.point)
                if let tool = reaction.tool {
                    CareEffect(tool: tool).id(reaction.time).position(reaction.point)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func careGesture(from item: CareTool? = nil) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(UnicornGame.id))
            .onChanged { value in
                guard hypot(value.translation.width, value.translation.height) > 10, let active = item ?? tool else { return }
                if let item { tool = item }
                finger = value.location
                let tip = liftedTip(value.location, tool: active)
                if let spot = closest(to: tip, for: active, radius: 56), spot != lastSpot {
                    lastSpot = spot
                    use(active, at: spot)
                } else if closest(to: tip, for: active, radius: 66) == nil { lastSpot = nil }
            }
            .onEnded { value in
                if hypot(value.translation.width, value.translation.height) <= 10 {
                    if let item { pick(item) }
                    else if let tool, let spot = closest(to: value.location, for: tool, radius: 76) { use(tool, at: spot) }
                    else if tool == nil { pet(at: value.location) }
                }
                finishDrag()
            }
    }

    private func closest(to location: CGPoint, for tool: CareTool, radius: CGFloat) -> CareSpot? {
        var distance = radius
        var result: CareSpot?
        let targets = care.spots(for: tool)
        for spot in CareSpot.allCases where targets.contains(spot) {
            let p = point(spot)
            let d = hypot(location.x - p.x, location.y - p.y)
            if d < distance { result = spot; distance = d }
        }
        return result
    }

    private func liftedTip(_ finger: CGPoint, tool: CareTool) -> CGPoint {
        FingerLift.point(finger, lift: tool == .sponge ? FingerLift.grip : FingerLift.tool, top: 90, bottom: 834, width: 1024)
    }

    private func heldTool(_ tool: CareTool, finger: CGPoint) -> some View {
        let tip = liftedTip(finger, tool: tool)
        let dx = finger.x - tip.x, dy = finger.y - tip.y
        return ZStack {
            if tool == .brush || tool == .rinse {
                Capsule().fill(tool.color.opacity(0.86)).frame(width: hypot(dx, dy), height: 17)
                    .rotationEffect(.radians(Double(atan2(dy, dx))))
                    .position(x: (finger.x + tip.x) / 2, y: (finger.y + tip.y) / 2)
            }
            chip(tool.symbol, color: tool.color, size: 58, selected: false).position(tip)
        }
    }

    private func finishDrag() { finger = nil; lastSpot = nil }

    private func pick(_ item: CareTool) {
        tool = tool == item && tray == .care ? nil : item
        tray = .care
        Sound.shared.play(.pop)
        Sound.shared.tap()
    }

    private func use(_ item: CareTool, at spot: CareSpot) {
        var updated = care
        guard updated.use(item, at: spot) else { return }
        save.care = updated
        persist()
        reaction = Reaction(tool: item, point: point(spot))
        Sound.shared.play(item.sound, volume: 0.68)
        Sound.shared.tap()
        if updated.complete {
            tool = nil
            Sound.shared.play(.fanfare, volume: 0.60)
            Coins.shared.earn(3, game: UnicornGame.id, from: point(.shoulder))
        }
    }

    private func pet(at p: CGPoint) {
        reaction = Reaction(tool: nil, point: p)
        Sound.shared.play(.sparkle, volume: 0.55)
        Sound.shared.tap()
    }

    private var meadowScene: some View {
        ZStack {
            scenery("meadow", color: Theme.mint)
            Rectangle().fill(.clear).contentShape(Rectangle())
                .gesture(SpatialTapGesture(coordinateSpace: .named(UnicornGame.id)).onEnded { value in
                    walk(toward: value.location.x)
                    guest = nil
                })
            Ellipse().fill(Color(hex: 0x526445, alpha: 0.34)).blur(radius: 9)
                .frame(width: 248, height: 34).position(x: pathX, y: 682)
            AnimatedUnicorn(look: save.look, reaction: strollStarted, motion: .stroll)
                .frame(width: 430, height: 348).position(x: pathX, y: 512)
                .allowsHitTesting(false)
            ForEach(Array(MeadowVisitor.allCases.enumerated()), id: \.element) { index, visitor in
                let found = StickerBook.shared.has(game: UnicornGame.id, id: visitor.rawValue)
                let stationX: CGFloat = 174 + CGFloat(index) * 225
                actionChip(found ? "checkmark" : "sparkles", label: found ? visitor.name : "Explore the meadow",
                           color: Color(hex: 0x637D4F), size: 76) {
                    walk(toward: stationX)
                    guest = visitor
                    if StickerBook.shared.find(game: UnicornGame.id, id: visitor.rawValue) {
                        Coins.shared.earn(1, game: UnicornGame.id, from: CGPoint(x: stationX, y: 735))
                    }
                }
                .position(x: stationX, y: 752 - CGFloat(index % 2) * 38)
            }
            if let guest {
                Button { book = true } label: {
                    StickerArt(sticker: guest.sticker, found: true).frame(width: 136, height: 136)
                        .background(.white.opacity(0.84), in: Circle())
                }
                .buttonStyle(Squish()).accessibilityLabel("Open the \(guest.name) sticker")
                .position(x: pathX, y: 235)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func walk(toward x: CGFloat) {
        strollStarted = Date()
        withAnimation(.easeInOut(duration: 0.75)) { pathX = max(232, min(792, x)) }
        Sound.shared.play(.whoosh, volume: 0.42)
    }

    private func persist() { GameStorage.save(save, game: UnicornGame.id, file: "stable.json") }
}

private struct CareEffect: View {
    let tool: CareTool
    @State private var moved = false
    @State private var faded = false

    var body: some View {
        ZStack {
            switch tool {
            case .feed:
                Image(systemName: "carrot.fill")
                    .font(.system(size: 49, weight: .bold))
                    .foregroundStyle(tool.color)
                    .rotationEffect(.degrees(-32))
                    .scaleEffect(moved ? 0.13 : 1)
                    .offset(x: moved ? 0 : 68, y: moved ? 0 : 39)
                Image(systemName: "heart.fill")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Theme.pink)
                    .offset(y: moved ? -67 : -19)
                    .opacity(moved && !faded ? 1 : 0)
            case .rinse:
                ForEach(0..<7) { index in
                    let direction = Double(index) / 7 * .pi
                    Image(systemName: "drop.fill")
                        .font(.system(size: CGFloat(12 + index % 3 * 5), weight: .semibold))
                        .foregroundStyle(Theme.sky.gradient)
                        .rotationEffect(.radians(direction - .pi / 2))
                        .offset(x: moved ? 60 * cos(direction) : 0, y: moved ? 58 * sin(direction) + 10 : 0)
                }
            case .brush, .sponge:
                EmptyView()
            }
        }
        .opacity(faded ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: 0.40)) { moved = true }
            withAnimation(.easeIn(duration: 0.31).delay(0.32)) { faded = true }
        }
        .accessibilityHidden(true)
    }
}
