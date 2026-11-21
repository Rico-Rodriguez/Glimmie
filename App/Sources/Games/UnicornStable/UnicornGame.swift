import SwiftUI

enum UnicornGame {
    static let id = "unicornstable"
    static let entry = GameEntry(
        id: id, title: "Unicorn Stable", tint: Theme.blush,
        icon: { AnyView(UnicornPicture(look: UnicornLook())) },
        play: { exit in AnyView(UnicornStableView(exit: exit)) },
        stickers: MeadowVisitor.allCases.map(\.sticker)
    )
}

private enum StableTool: String, CaseIterable {
    case brush, sponge, comb, braid, feed

    var symbol: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .sponge: return "bubbles.and.sparkles.fill"
        case .comb: return "comb.fill"
        case .braid: return "ribbon.fill"
        case .feed: return "carrot.fill"
        }
    }

    var color: Color {
        switch self {
        case .brush: return Theme.pink
        case .sponge: return Theme.sky
        case .comb: return Theme.mint
        case .braid: return Theme.lilac
        case .feed: return Theme.peach
        }
    }

    var sound: SFX {
        switch self {
        case .brush, .comb: return .whoosh
        case .sponge: return .bubble
        case .braid: return .sparkle
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
        case .coat: return [0xFFF8F1, 0xFFD1DB, 0xCFEAFF, 0xF0CFAB, 0xF3EDF9, 0xADDCC6]
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
        var nextStretch = 0
    }

    let exit: () -> Void
    @State private var save = GameStorage.load(Save.self, game: UnicornGame.id, file: "stable.json") ?? Save()
    @State private var tray: StableTray = .care
    @State private var tool: StableTool?
    @State private var finger: CGPoint?
    @State private var book = false
    @State private var riding = ProcessInfo.processInfo.arguments.contains("-unicornMeadow")
    @State private var ride = MeadowRide()
    @State private var reaction = 0
    @State private var effectPoint = CGPoint(x: 512, y: 360)
    @State private var effect: StableTool?
    @State private var lastRub: CGPoint?
    @State private var landing = 0
    @State private var splashed = false
    @State private var rideMotion: Date?
    @State private var jumped = false
    @State private var meadowOffset: CGFloat = 0
    @State private var bubbles: [CGPoint] = []
    @State private var sheen = 0

    private let petFrame = CGRect(x: 207, y: 114, width: 610, height: 490)
    private let workArea = CGRect(x: 290, y: 187, width: 495, height: 376)

    var body: some View {
        DesignCanvas {
            ZStack {
                if riding { meadow } else { barn }
                HStack(spacing: 16) {
                    HomeButton(action: exit)
                    Spacer()
                    CoinCounter(game: UnicornGame.id)
                    StickerBookButton(game: UnicornGame.id) { book = true }
                    RoundButton(symbol: riding ? "house.lodge.fill" : "leaf.fill", tint: Theme.mint) { toggleRide() }
                        .accessibilityLabel(riding ? "Return to stable" : "Ride in the meadow")
                }
                .padding(.horizontal, 26)
                .position(x: 512, y: 63)
                StickerToast(game: UnicornGame.id, target: CGPoint(x: 874, y: 63))
                if book {
                    StickerBookView(game: UnicornGame.id) { book = false }
                        .zIndex(1)
                }
            }
            .frame(width: 1024, height: 834)
            .coordinateSpace(name: UnicornGame.id)
            .coinPurse(game: UnicornGame.id)
        }
        .background((riding ? Theme.sky : Theme.cream).ignoresSafeArea())
    }

    private var barn: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xFFE6D8), Theme.cream], startPoint: .top, endPoint: .bottom)
            RoundedRectangle(cornerRadius: 84)
                .fill(LinearGradient(colors: [Theme.sky, Theme.mint], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 84).strokeBorder(.white, lineWidth: 16))
                .frame(width: 680, height: 460)
                .position(x: 512, y: 345)
            HStack(spacing: 686) {
                Image(systemName: "heart.fill").foregroundStyle(Theme.peach)
                Image(systemName: "sparkles").foregroundStyle(Theme.lilac)
            }
            .font(.system(size: 56, weight: .bold))
            .position(x: 512, y: 282)
            Ellipse().fill(Color(hex: 0xBDA0BF, alpha: 0.25)).frame(width: 474, height: 59)
                .position(x: 512, y: 555)
            UnicornPicture(look: save.look)
                .frame(width: petFrame.width, height: petFrame.height)
                .position(x: petFrame.midX, y: petFrame.midY)
                .scaleEffect(effect == .feed && reaction.isMultiple(of: 2) ? 1.025 : 1)
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(width: petFrame.width, height: petFrame.height)
                .position(x: petFrame.midX, y: petFrame.midY)
                .gesture(careGesture)
                .accessibilityLabel("Care for your unicorn")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { react(at: CGPoint(x: 548, y: 375), using: tool) }
            careEffect
            controls.position(x: 512, y: 703)
            if let finger, let tool {
                heldTool(tool, finger: finger)
                    .allowsHitTesting(false)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                ForEach(StableTray.allCases, id: \.self) { item in
                    chip(item.symbol, label: item.rawValue.capitalized, color: Theme.lilac, selected: item == tray, size: 59) {
                        tray = item
                        tool = nil
                        Sound.shared.play(.flip)
                    }
                }
            }
            HStack(spacing: 19) {
                if tray == .care {
                    ForEach(StableTool.allCases, id: \.self) { item in
                        chipLabel(item.symbol, color: item.color, selected: item == tool, size: 103)
                            .contentShape(Circle())
                            .gesture(selectTool(item))
                            .accessibilityLabel(item.rawValue.capitalized)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { pick(item) }
                    }
                } else if let key = tray.keyPath {
                    ForEach(Array(tray.colors.enumerated()), id: \.offset) { index, color in
                        chip("", label: "\(tray.rawValue.capitalized) color \(index + 1)", color: Color(hex: color),
                             selected: save.look[keyPath: key] == color, size: 94) {
                            save.look[keyPath: key] = color
                            persist()
                            react(at: CGPoint(x: 532, y: 355), using: nil, sound: .sparkle)
                        }
                    }
                } else {
                    ForEach(UnicornGear.available, id: \.self) { gear in
                        chip(gear.symbol, label: gear == .none ? "Remove gear" : gear.rawValue.capitalized,
                             color: Theme.peach, selected: save.look.gear == gear, size: 103) {
                            save.look.gear = gear
                            persist()
                            react(at: CGPoint(x: 532, y: 355), using: nil, sound: .sparkle)
                        }
                    }
                }
            }
            .frame(height: 110)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 13)
        .background(Theme.blush, in: RoundedRectangle(cornerRadius: 48))
        .overlay(RoundedRectangle(cornerRadius: 48).strokeBorder(.white, lineWidth: 6))
    }

    private func chip(_ symbol: String, label: String, color: Color, selected: Bool = false, size: CGFloat,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) { chipLabel(symbol, color: color, selected: selected, size: size) }
            .buttonStyle(Squish())
            .accessibilityLabel(label)
    }

    private func chipLabel(_ symbol: String, color: Color, selected: Bool, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(color.gradient)
            if !symbol.isEmpty {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .overlay(Circle().strokeBorder(selected ? Theme.pink : .white, lineWidth: selected ? 8 : 5))
        .frame(width: size, height: size)
        .shadow(color: Theme.ink.opacity(0.18), radius: 3, y: 4)
    }

    private var careGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(UnicornGame.id))
            .onChanged { value in
                guard let tool, moved(value.translation) else { return }
                drag(tool, to: value.location)
            }
            .onEnded { value in
                if !moved(value.translation), workArea.contains(value.location) {
                    react(at: value.location, using: tool)
                }
                finishDrag()
            }
    }

    private func selectTool(_ item: StableTool) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(UnicornGame.id))
            .onChanged { value in
                guard moved(value.translation) else { return }
                tool = item
                drag(item, to: value.location)
            }
            .onEnded { value in
                if !moved(value.translation) { pick(item) }
                finishDrag()
            }
    }

    private func moved(_ distance: CGSize) -> Bool { hypot(distance.width, distance.height) > 10 }

    private func pick(_ item: StableTool) {
        tool = tool == item ? nil : item
        Sound.shared.play(.pop)
        Sound.shared.tap()
    }

    private func workPoint(_ tool: StableTool, finger: CGPoint) -> CGPoint {
        let lift = tool == .sponge ? FingerLift.grip : FingerLift.tool
        return FingerLift.point(finger, lift: lift, top: 100, bottom: 834, width: 1024)
    }

    private func drag(_ item: StableTool, to point: CGPoint) {
        finger = point
        let tip = workPoint(item, finger: point)
        guard workArea.contains(tip) else { return }
        if let lastRub, hypot(lastRub.x - tip.x, lastRub.y - tip.y) < 57 { return }
        lastRub = tip
        react(at: tip, using: item)
    }

    private func finishDrag() {
        finger = nil
        lastRub = nil
    }

    private func heldTool(_ item: StableTool, finger: CGPoint) -> some View {
        let tip = workPoint(item, finger: finger)
        let x = finger.x - tip.x
        let y = finger.y - tip.y
        return ZStack {
            if item == .brush || item == .comb {
                Capsule().fill(item.color).frame(width: hypot(x, y), height: 20)
                    .rotationEffect(.radians(Double(atan2(y, x))))
                    .position(x: tip.x + x / 2, y: tip.y + y / 2)
            }
            chipLabel(item.symbol, color: item.color, selected: false, size: 64)
                .rotationEffect(.degrees(-17))
                .position(tip)
        }
    }

    private var careEffect: some View {
        let colors: [Color] = effect == .sponge ? [.white, Theme.sky, Theme.lilac] : [.white, Theme.pink, Theme.lemon]
        return ZStack {
            ForEach(bubbles.indices, id: \.self) { index in
                let point = bubbles[index]
                Circle().fill(.white.opacity(0.49))
                    .overlay(Circle().strokeBorder(Theme.sky, lineWidth: 3))
                    .frame(width: 33 + CGFloat(index % 4) * 8, height: 33 + CGFloat(index % 4) * 8)
                    .position(x: point.x - 27 + CGFloat(index % 3) * 23, y: point.y - 21)
            }
            if reaction > 0 {
                if effect == .feed {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 57, weight: .bold))
                        .foregroundStyle(Theme.pink)
                        .shadow(color: .white, radius: 0, x: 0, y: 3)
                        .position(x: 733, y: 231)
                } else {
                    SparkleBurst(colors: colors, count: 12 + sheen, radius: 92)
                        .id(reaction)
                        .position(effectPoint)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func react(at point: CGPoint, using item: StableTool?, sound: SFX = .pop) {
        if item == .sponge {
            if bubbles.count == 12 { bubbles.removeFirst() }
            bubbles.append(point)
            sheen = 0
        } else if item == .brush {
            bubbles.removeAll { hypot($0.x - point.x, $0.y - point.y) < 105 }
            sheen = min(10, sheen + 2)
        }
        if item == .braid, !save.look.braided {
            save.look.braided = true
            persist()
        } else if item == .comb, save.look.braided {
            save.look.braided = false
            persist()
        }
        effect = item
        effectPoint = point
        reaction += 1
        Sound.shared.play(item?.sound ?? sound, volume: 0.68)
        Sound.shared.tap()
    }

    private var meadow: some View {
        ZStack {
            MeadowBackdrop(offset: meadowOffset)
            Ellipse().fill(Color(hex: 0x966F73, alpha: 0.24)).frame(width: 375, height: 42)
                .position(x: 394, y: 555)
            TimelineView(.animation(minimumInterval: 1 / 30, paused: rideMotion == nil)) { timeline in
                let elapsed = rideMotion.map { timeline.date.timeIntervalSince($0) } ?? 1
                let progress = max(0, min(1, elapsed / 0.52))
                let lift = progress < 1 ? CGFloat(sin(progress * .pi)) * (jumped ? 103 : 21) : 0
                let stride = progress < 1 ? CGFloat(sin(progress * .pi * (jumped ? 1 : 4))) * 30 : 0
                UnicornPicture(look: save.look, stride: stride)
                    .frame(width: 475, height: 400)
                    .position(x: 391, y: 375 - lift)
            }
            if let stop = ride.stop {
                visitor(stop.visitor)
            } else {
                Image(systemName: ride.needsJump ? "water.waves" : "star.fill")
                    .font(.system(size: ride.needsJump ? 105 : 82, weight: .bold))
                    .foregroundStyle(ride.needsJump ? Color(hex: 0x5DAFE8) : Theme.lemon)
                    .shadow(color: .white, radius: 0, x: 0, y: 4)
                    .position(x: 771, y: ride.needsJump ? 550 : 461)
                    .accessibilityLabel(ride.needsJump ? "Puddle ahead" : "Star ahead")
            }
            if landing > 0 {
                SparkleBurst(colors: splashed ? [.white, Theme.sky, Theme.mint] : [.white, Theme.lemon], radius: 94)
                    .id(landing)
                    .position(x: 600, y: splashed ? 544 : 410)
            }
            HStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(index < ride.stars ? Color(hex: 0xFFBF39) : .white.opacity(0.67))
                }
            }
            .accessibilityLabel("\(ride.stars) stars")
            .position(x: 512, y: 152)
            if ride.stop != nil {
                chip("arrow.right", label: "Ride onward", color: Theme.mint, size: 124) {
                    ride.continueRide()
                    Sound.shared.play(.whoosh)
                }
                .position(x: 512, y: 704)
            } else {
                HStack(spacing: 38) {
                    chip("arrow.right", label: "Gallop", color: Theme.mint, size: 124) { move(jump: false) }
                    chip("arrow.up", label: "Jump", color: Theme.lilac, size: 124) { move(jump: true) }
                }
                .position(x: 512, y: 704)
            }
        }
        .clipped()
        .task(id: rideMotion) {
            guard rideMotion != nil else { return }
            do { try await Task.sleep(nanoseconds: 550_000_000) } catch { return }
            guard !Task.isCancelled else { return }
            rideMotion = nil
        }
    }

    private func visitor(_ guest: MeadowVisitor) -> some View {
        Button {
            Sound.shared.play(.sparkle)
            book = true
        } label: {
            StickerArt(sticker: guest.sticker, found: true)
                .frame(width: 236, height: 220)
                .background(.white.opacity(0.45), in: Circle())
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "sparkles").font(.system(size: 47, weight: .bold)).foregroundStyle(Theme.lemon)
                }
        }
        .buttonStyle(Squish())
        .accessibilityLabel("\(guest.name) sticker")
        .position(x: 764, y: 395)
    }

    private func toggleRide() {
        finishDrag()
        if !riding {
            ride = MeadowRide(stretch: save.nextStretch)
            landing = 0
            rideMotion = nil
            meadowOffset = 0
        }
        withAnimation(.easeInOut(duration: 0.22)) { riding.toggle() }
        Sound.shared.play(.whoosh)
    }

    private func move(jump: Bool) {
        guard ride.stop == nil else { return }
        splashed = ride.move(jump: jump)
        landing += 1
        jumped = jump
        rideMotion = Date()
        withAnimation(.easeOut(duration: 0.30)) {
            meadowOffset += 108
        }
        Sound.shared.play(splashed ? .bubble : (jump ? .boing : .ding), volume: 0.72)
        Sound.shared.tap()
        if let stop = ride.stop {
            save.nextStretch = (ride.stretch + 1) % MeadowRide.route.count
            persist()
            StickerBook.shared.find(game: UnicornGame.id, id: stop.visitor.rawValue)
            Coins.shared.earn(max(1, stop.stars / 2), game: UnicornGame.id, from: CGPoint(x: 741, y: 443))
        }
    }

    private func persist() { GameStorage.save(save, game: UnicornGame.id, file: "stable.json") }
}

private struct MeadowBackdrop: View {
    let offset: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Theme.sky, Color(hex: 0xE6F8FC)], startPoint: .top, endPoint: .bottom)
            Circle().fill(Color(hex: 0xFFF1B1)).frame(width: 126).position(x: 795, y: 196)
            Canvas { g, _ in
                for i in 0..<7 {
                    let x = CGFloat(i * 235) - 250 - (offset * 0.4).truncatingRemainder(dividingBy: 235)
                    let y = CGFloat(252 + (i % 3) * 37)
                    g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 467, height: 365)), with: .color(Theme.mint))
                }
                g.fill(Path(roundedRect: CGRect(x: -90, y: 486, width: 1204, height: 439), cornerRadius: 131),
                       with: .color(Color(hex: 0xA2DAB0)))
                g.fill(Path(ellipseIn: CGRect(x: -150, y: 498, width: 1324, height: 213)),
                       with: .color(Color(hex: 0xF6D2AF)))
                for i in 0..<19 {
                    let x = CGFloat(i * 69) - 105 - offset.truncatingRemainder(dividingBy: 69)
                    let y = CGFloat(593 + (i % 4) * 48)
                    let color = i.isMultiple(of: 2) ? Theme.pink : Theme.lemon
                    g.fill(Twinkle().path(in: CGRect(x: x, y: y, width: 24, height: 24)), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
