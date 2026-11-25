import SwiftUI

enum FairiesGame {
    static let entry = GameEntry(
        id: FairiesSim.gameID,
        title: "Fairies",
        tint: Color(hex: 0xFFA6D6),
        icon: { AnyView(FairiesTileIcon()) },
        play: { exit in AnyView(FairiesView(exit: exit)) },
        stickers: FairiesFind.stickers
    )
}

// MARK: - Drawer Tile Icon

private struct FairiesTileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let k = min(size.width, size.height) / 300
            g.translateBy(x: (size.width - 300 * k) / 2, y: (size.height - 300 * k) / 2)
            g.scaleBy(x: k, y: k)
            FairiesArt.drawTileIcon(g)
        }
    }
}

// MARK: - Seamless Full-Bleed Backdrop

private struct FairiesBackdropFill: View {
    let mode: FairiesMode
    let isNightMode: Bool

    var body: some View {
        let colors: [Color] = {
            if mode == .meadow {
                return [Color(hex: 0xFFE6F6), Color(hex: 0xE8F8FF), Color(hex: 0x9DE0B4)]
            }
            if isNightMode {
                return [Color(hex: 0x3D3268), Color(hex: 0x5A478E), Color(hex: 0x4A3A7A)]
            }
            return [Color(hex: 0xFFE0F2), Color(hex: 0xF3E6FF), Color(hex: 0xFFEBF5)]
        }()
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .animation(.easeInOut(duration: 0.4), value: isNightMode)
    }
}

// MARK: - Main Fairies View

struct FairiesView: View {
    let exit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sim = FairiesSim()
    @State private var showBook = false
    @State private var wandDragStarted = false
    @State private var treatDragKind: MeadowTreatKind?
    @State private var treatDragStarted = false
    @State private var trayDragFairy: FairyKind?
    @State private var sceneDragActor: CompactFairyActor?
    @State private var sceneDragStarted = false
    @State private var meadowTouchStarted = false

    var body: some View {
        let paused = showBook || scenePhase != .active
        ZStack {
            GameStage(background: { FairiesBackdropFill(mode: sim.mode, isNightMode: sim.isNightMode) }) {
                ZStack {
                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: paused)) { tl in
                        Canvas { ctx, _ in
                            sim.step(tl.date)
                            FairiesArt.drawScene(ctx, sim: sim)
                        }
                    }
                    .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                    .contentShape(Rectangle())
                    .gesture(sceneGesture)

                    if sim.mode == .compact, sim.draggingCompactFairy != nil, sim.compactDragStartedInRoom {
                        ReturnDropBadge(hovered: sim.compactReturnHovered)
                            .position(FGeo.returnBadgeCenter)
                            .allowsHitTesting(false)
                            .transition(.scale.combined(with: .opacity))
                    }

                    bottomDock
                        .position(x: GameChromeLayout.width / 2, y: GameChromeLayout.dockY)

                    GameTopBar(
                        gameID: FairiesSim.gameID,
                        showStickerBook: true,
                        showCoins: true,
                        onExit: {
                            sim.save()
                            exit()
                        },
                        onStickerBook: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showBook = true
                            }
                        },
                        center: {
                            modeTogglePill
                        }
                    )

                    StickerToast(game: FairiesSim.gameID, target: GameChromeLayout.stickerTarget)
                }
                .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                .coordinateSpace(name: "fairies")
                .coinPurse(game: FairiesSim.gameID)
            }

            if showBook {
                StickerBookView(game: FairiesSim.gameID) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .defersSystemGestures(on: .bottom)
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                sim.save()
                sim.resetClock()
            }
        }
        .onChange(of: showBook) { open in
            if !open {
                sim.resetClock()
            }
        }
        .onDisappear {
            sim.save()
        }
    }

    // MARK: - Top Bar Pictorial Mode Toggle (Zero Words)

    private var modeTogglePill: some View {
        HStack(spacing: 10) {
            modeButton(
                target: .meadow,
                selectedTint: Theme.mint.opacity(0.65),
                showBadge: false,
                label: "Sparkle Meadow"
            ) { ctx in
                FairiesArt.drawMeadowModeIcon(ctx)
            }
            modeButton(
                target: .compact,
                selectedTint: Theme.blush,
                showBadge: sim.hasCompactBadge,
                label: "Jewel Compact"
            ) { ctx in
                FairiesArt.drawCompactModeIcon(ctx)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.cream.opacity(0.96)))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 3.5))
        .shadow(color: Theme.ink.opacity(0.18), radius: 8, y: 4)
    }

    private func modeButton(
        target: FairiesMode,
        selectedTint: Color,
        showBadge: Bool,
        label: String,
        draw: @escaping (GraphicsContext) -> Void
    ) -> some View {
        let isSelected = sim.mode == target
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                sim.switchMode(target)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? selectedTint : .white)
                Canvas { ctx, sz in
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                    draw(g)
                }
                .allowsHitTesting(false)
            }
            .frame(width: 58, height: 58)
            .overlay(Circle().stroke(isSelected ? Theme.pink : Theme.blush, lineWidth: isSelected ? 4 : 2.5))
            .overlay(alignment: .topTrailing) {
                if showBadge {
                    ZStack {
                        Circle().fill(Color(hex: 0xFFB830))
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: 4, y: -4)
                }
            }
            .scaleEffect(isSelected ? 1.05 : 0.94)
        }
        .buttonStyle(Squish())
        .accessibilityLabel(label)
    }

    // MARK: - Lifted Bottom Dock (y = GameChromeLayout.dockY = 740)

    @ViewBuilder
    private var bottomDock: some View {
        if sim.mode == .meadow {
            meadowDock
        } else {
            compactDock
        }
    }

    private var meadowDock: some View {
        GameTrayCard(cornerRadius: 34, paddingH: 14, paddingV: 10) {
            HStack(spacing: 12) {
                wandDockTile

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Theme.blush)
                    .frame(width: 3, height: 54)

                if sim.activeTreatLureFairy != nil {
                    HStack(spacing: 12) {
                        ForEach(sim.availableMeadowTreats) { treat in
                            meadowTreatDockTile(treat)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    HStack(spacing: 6) {
                        ForEach(FairyKind.allCases) { kind in
                            meadowCollectionBadge(kind)
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: sim.activeTreatLureFairy != nil)
    }

    private var wandDockTile: some View {
        GameDockTile(
            size: 74,
            selected: sim.wandHeld,
            pulsing: !sim.wandHeld,
            tint: Theme.blush.opacity(0.42),
            cornerRadius: 22
        ) {
            if !sim.wandHeld {
                Canvas { ctx, sz in
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                    FairiesArt.drawWandIcon(g)
                }
                .allowsHitTesting(false)
            }
        }
        .opacity(sim.wandHeld ? 0.35 : 1)
        .contentShape(Rectangle())
        .gesture(wandDockGesture)
        .accessibilityLabel("Magic Wand")
    }

    private func meadowTreatDockTile(_ treat: MeadowTreatKind) -> some View {
        let isDraggingThis = sim.draggingMeadowTreat == treat
        return GameDockTile(
            size: 72,
            selected: isDraggingThis,
            pulsing: !isDraggingThis,
            tint: Color(hex: treat.accentHex, alpha: 0.2),
            cornerRadius: 22
        ) {
            if !isDraggingThis {
                Canvas { ctx, sz in
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                    g.scaleBy(x: 1.05, y: 1.05)
                    FairiesArt.drawTreatIcon(g, kind: treat)
                }
                .allowsHitTesting(false)
            }
        }
        .opacity(isDraggingThis ? 0.35 : 1)
        .contentShape(Rectangle())
        .gesture(meadowTreatGesture(treat))
        .accessibilityLabel(treat.rawValue)
    }

    private func meadowCollectionBadge(_ kind: FairyKind) -> some View {
        let collected = sim.befriended.contains(kind)
        let isPinned = sim.pinnedFairy == kind
        return Button {
            if collected {
                sim.selectFairy(kind)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    sim.switchMode(.compact)
                }
            } else {
                Sound.shared.play(.tap, volume: 0.4)
                Sound.shared.tap()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(collected ? Color(hex: kind.palette.wingInner) : Theme.blush.opacity(0.35))
                Canvas { ctx, sz in
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                    if collected {
                        g.translateBy(x: 0, y: 4)
                        FairiesArt.drawFairy(g, kind: kind, mood: .happy, accessory: sim.accessories[kind], time: 0.2, scale: 0.56, blinkSeed: 0)
                    } else {
                        let silhouette = FairiesArt.heartPath(center: CGPoint(x: 0, y: 1), size: 28)
                        g.fill(silhouette, with: .color(Theme.pink.opacity(0.32)))
                        StorybookArt.sparkle(g, at: CGPoint(x: 9, y: -9), radius: 5, color: .white.opacity(0.85))
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(width: 56, height: 56)
            .overlay(Circle().stroke(collected ? Color(hex: kind.palette.emblem).opacity(0.75) : Theme.blush, lineWidth: collected ? 3 : 2))
            .overlay(alignment: .topTrailing) {
                if isPinned {
                    pinCornerBadge
                }
            }
        }
        .buttonStyle(Squish())
    }

    private var compactDock: some View {
        let trayWidth = min(CGFloat(472), CGFloat(max(1, sim.befriended.count)) * 72 + 12)
        return GameTrayCard(cornerRadius: 34, paddingH: 14, paddingV: 10) {
            HStack(spacing: 11) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sim.befriended) { fairy in
                            compactFairyTile(fairy)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                }
                .frame(width: trayWidth, height: 74)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Theme.blush)
                    .frame(width: 3, height: 54)

                HStack(spacing: 6) {
                    ForEach(FairyAccessory.allCases) { acc in
                        accessoryTile(acc)
                    }
                }

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Theme.blush)
                    .frame(width: 3, height: 54)

                starPinButton
            }
        }
    }

    private func compactFairyTile(_ fairy: FairyKind) -> some View {
        let isSelected = sim.selectedFairy == fairy
        let isDraggingThis = sim.draggingCompactFairy == fairy && !sim.compactDragStartedInRoom
        let isInRoom = sim.activeCompactFairies.contains(fairy)
        let isPinned = sim.pinnedFairy == fairy

        return GameDockTile(
            size: 64,
            selected: isSelected,
            tint: Color(hex: fairy.palette.wingInner),
            cornerRadius: 20
        ) {
            if !isDraggingThis {
                Canvas { ctx, sz in
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2 + 5)
                    FairiesArt.drawFairy(g, kind: fairy, mood: .happy, accessory: sim.accessories[fairy], time: 0.25, scale: 0.64, blinkSeed: 0)
                }
                .allowsHitTesting(false)
            }
        }
        .opacity(isDraggingThis ? 0.35 : 1)
        .overlay(alignment: .topTrailing) {
            if isPinned {
                pinCornerBadge
            }
        }
        .overlay(alignment: .bottomLeading) {
            if isInRoom {
                Circle()
                    .fill(Theme.mint)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: 3, y: -3)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            sim.selectFairy(fairy, readyToPlace: true)
        }
        .simultaneousGesture(compactTrayFairyGesture(fairy))
    }

    private func accessoryTile(_ accessory: FairyAccessory) -> some View {
        let worn = sim.accessories[sim.selectedFairy] == accessory
        return Button {
            sim.toggleAccessory(accessory)
        } label: {
            GameDockTile(
                size: 54,
                selected: worn,
                tint: worn ? Theme.blush.opacity(0.65) : .white,
                cornerRadius: 18
            ) {
                Canvas { ctx, sz in
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                    FairiesArt.drawAccessoryIcon(g, accessory: accessory)
                }
                .allowsHitTesting(false)
            }
        }
        .buttonStyle(Squish())
    }

    private var starPinButton: some View {
        let pinned = sim.pinnedFairy == sim.selectedFairy
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                _ = sim.togglePin()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        pinned
                            ? LinearGradient(colors: [Color(hex: 0xFFF2A6), Color(hex: 0xFFC93C)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.white, Theme.cream], startPoint: .top, endPoint: .bottom)
                    )
                Image(systemName: pinned ? "star.fill" : "star")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(pinned ? .white : Color(hex: 0xE6A424))
                    .shadow(color: pinned ? Color(hex: 0xB9770E).opacity(0.45) : .clear, radius: 2, y: 1)
            }
            .frame(width: 62, height: 62)
            .overlay(Circle().stroke(pinned ? Color(hex: 0xFFB830) : Color(hex: 0xFFD97D), lineWidth: pinned ? 4.5 : 3))
            .shadow(color: Color(hex: 0xE2A726).opacity(pinned ? 0.42 : 0.16), radius: pinned ? 8 : 4, y: 3)
            .scaleEffect(pinned ? 1.07 : 1)
        }
        .buttonStyle(Squish())
        .accessibilityLabel("Pin Fairy Companion")
    }

    private var pinCornerBadge: some View {
        ZStack {
            Circle().fill(Color(hex: 0xFFB830))
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: 20, height: 20)
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .offset(x: 4, y: -4)
        .allowsHitTesting(false)
    }

    // MARK: - Gestures

    private var wandDockGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("fairies"))
            .onChanged { v in
                let p = v.location
                let moved = hypot(v.translation.width, v.translation.height)
                if !wandDragStarted {
                    guard moved >= 12 else { return }
                    wandDragStarted = true
                    sim.beginWand(finger: p, lifted: Self.liftedWand(p))
                } else {
                    sim.moveWand(finger: p, lifted: Self.liftedWand(p))
                }
            }
            .onEnded { _ in
                if !wandDragStarted {
                    sim.triggerWandTapMagic()
                } else {
                    sim.endWand()
                }
                wandDragStarted = false
            }
    }

    private func meadowTreatGesture(_ treat: MeadowTreatKind) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("fairies"))
            .onChanged { v in
                let moved = hypot(v.translation.width, v.translation.height)
                if !treatDragStarted {
                    guard moved >= 12 else { return }
                    treatDragStarted = true
                    treatDragKind = treat
                    sim.beginMeadowTreatDrag(treat, at: Self.liftedFairy(v.location))
                } else if treatDragKind == treat {
                    sim.updateMeadowTreatDrag(to: Self.liftedFairy(v.location))
                }
            }
            .onEnded { v in
                if treatDragStarted && treatDragKind == treat {
                    sim.endMeadowTreatDrag(at: Self.liftedFairy(v.location))
                } else {
                    _ = sim.serveMeadowTreat(treat, from: v.location)
                }
                treatDragStarted = false
                treatDragKind = nil
            }
    }

    private func compactTrayFairyGesture(_ fairy: FairyKind) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("fairies"))
            .onChanged { v in
                let p = v.location
                if trayDragFairy == nil {
                    guard v.translation.height < -10, abs(v.translation.height) >= abs(v.translation.width) * 0.45 else { return }
                    trayDragFairy = fairy
                    sim.beginCompactDrag(fairy: fairy, fromSpot: nil, at: Self.liftedFairy(p), fromRoom: false)
                }
                guard trayDragFairy == fairy else { return }
                sim.updateCompactDrag(to: Self.liftedFairy(p))
            }
            .onEnded { v in
                guard trayDragFairy == fairy else { return }
                sim.endCompactDrag(at: Self.liftedFairy(v.location))
                trayDragFairy = nil
            }
    }

    private var sceneGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("fairies"))
            .onChanged { v in
                if sim.mode == .meadow {
                    let isStart = !meadowTouchStarted
                    meadowTouchStarted = true
                    sim.meadowTouchMoved(to: v.location, isStart: isStart)
                    return
                }
                let moved = hypot(v.translation.width, v.translation.height)
                if !sceneDragStarted {
                    if sceneDragActor == nil {
                        sceneDragActor = sim.nearestCompactActor(to: v.startLocation, maxRadius: 58)
                    }
                    guard moved >= 12, let actor = sceneDragActor else { return }
                    sceneDragStarted = true
                    sim.beginCompactDrag(fairy: actor.kind, fromSpot: actor.currentSpot, at: Self.liftedFairy(v.location), fromRoom: true)
                } else {
                    sim.updateCompactDrag(to: Self.liftedFairy(v.location))
                }
            }
            .onEnded { v in
                if sim.mode == .meadow {
                    let moved = hypot(v.translation.width, v.translation.height)
                    sim.meadowTouchEnded(at: v.location, movedDistance: moved)
                    meadowTouchStarted = false
                    return
                }
                if sceneDragStarted {
                    sim.endCompactDrag(at: Self.liftedFairy(v.location))
                } else {
                    sim.tapCompact(at: v.location)
                }
                sceneDragStarted = false
                sceneDragActor = nil
            }
    }

    private static func liftedWand(_ finger: CGPoint) -> CGPoint {
        FingerLift.point(finger, lift: FingerLift.tool, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
    }

    private static func liftedFairy(_ finger: CGPoint) -> CGPoint {
        FingerLift.point(finger, lift: FingerLift.item, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
    }
}
