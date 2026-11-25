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

private struct FairiesBackdropFill: View {
    let station: FairyStation
    let isNightMode: Bool
    let hasHanbokTea: Bool

    var body: some View {
        let colors: [Color] = {
            switch station {
            case .stage:
                if isNightMode {
                    return [Color(hex: 0x3D3268), Color(hex: 0x5A478E), Color(hex: 0x4A3A7A)]
                }
                return [Color(hex: 0xFFE0F2), Color(hex: 0xF3E6FF), Color(hex: 0xFFEBF5)]
            case .salon:
                return [Color(hex: 0xFFE4F4), Color(hex: 0xF6EAFF), Color(hex: 0xFFF0F8)]
            case .teaTable:
                if hasHanbokTea {
                    return [Color(hex: 0xE8FBF4), Color(hex: 0xFFF3F8), Color(hex: 0xFFF6E8)]
                }
                return [Color(hex: 0xFFEAF6), Color(hex: 0xFFF5EC), Color(hex: 0xEBF8FF)]
            }
        }()
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .animation(.easeInOut(duration: 0.35), value: isNightMode)
    }
}

private final class FairiesSimHolder: ObservableObject {
    let sim = FairiesSim()
}

struct FairiesView: View {
    let exit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var holder = FairiesSimHolder()
    @State private var uiState: FairiesUIState?
    @State private var showBook = false
    @State private var lastBrushColor: WingBrushColor = .rosePearl
    @State private var lastGlitterHex: UInt32 = FairySalonTool.glitterPalette[0]
    @State private var lastStampKind: WingStampKind = .dewdrop
    @State private var trayDragFairy: FairyKind?
    @State private var dockSugarDrag: SugarStarKind?
    @State private var dockSugarStarted = false
    @State private var dockTreatDrag: FairyTeaTreatKind?
    @State private var dockTreatStarted = false

    private var sim: FairiesSim { holder.sim }
    private var state: FairiesUIState { uiState ?? holder.sim.currentUIState() }

    var body: some View {
        let current = state
        let paused = showBook || scenePhase != .active

        ZStack {
            GameStage(background: {
                FairiesBackdropFill(
                    station: current.station,
                    isNightMode: current.isNightMode,
                    hasHanbokTea: current.hasHanbokTea
                )
            }) {
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

                    if current.station == .stage,
                       current.draggingCompactFairy != nil,
                       current.compactDragStartedInRoom {
                        ReturnDropBadge(hovered: current.compactReturnHovered)
                            .position(FGeo.returnBadgeCenter)
                            .allowsHitTesting(false)
                            .transition(.scale.combined(with: .opacity))
                    }

                    if current.station == .salon || current.station == .teaTable {
                        sideFairyRail(current)
                            .position(x: 54, y: 400)
                    }

                    bottomDock(current)
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
                            stationTogglePill(current)
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
        .onAppear {
            sim.onUIStateChange = { next in
                uiState = next
            }
            uiState = sim.currentUIState()
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                resetLocalDrags()
                sim.cancelTransientGestures()
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

    // MARK: - Top Bar 3-Station Pictorial Toggle

    private func stationTogglePill(_ current: FairiesUIState) -> some View {
        HStack(spacing: 10) {
            stationButton(target: .stage, current: current, tint: Theme.blush, label: "Compact Stage")
            stationButton(target: .salon, current: current, tint: Theme.lilac.opacity(0.65), label: "Wing Salon")
            stationButton(target: .teaTable, current: current, tint: Theme.mint.opacity(0.65), label: "Pixie Tea")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.cream.opacity(0.96)))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 3.5))
        .shadow(color: Theme.ink.opacity(0.18), radius: 8, y: 4)
    }

    private func stationButton(target: FairyStation, current: FairiesUIState, tint: Color, label: String) -> some View {
        let isSelected = current.station == target
        return Button {
            resetLocalDrags()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.74)) {
                sim.selectStation(target)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? tint : .white)
                Canvas { ctx, sz in
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                    FairiesArt.drawStationIcon(g, station: target)
                }
                .allowsHitTesting(false)
            }
            .frame(width: 58, height: 58)
            .overlay(Circle().stroke(isSelected ? Theme.pink : Theme.blush, lineWidth: isSelected ? 4 : 2.5))
            .scaleEffect(isSelected ? 1.06 : 0.94)
        }
        .buttonStyle(Squish())
        .accessibilityLabel(label)
    }

    // MARK: - Left Vertical Fairy Selector (Salon & Tea Table)

    private func sideFairyRail(_ current: FairiesUIState) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(FairyKind.allCases) { fairy in
                    let isSelected = current.selectedFairy == fairy
                    let isPinned = current.pinnedFairy == fairy
                    Button {
                        sim.selectFairy(fairy)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: fairy.palette.wingInner))
                            Canvas { ctx, sz in
                                _ = current.wingDesignVersion
                                var g = ctx
                                g.translateBy(x: sz.width / 2, y: sz.height / 2 + 4)
                                FairiesArt.drawFairy(
                                    g,
                                    kind: fairy,
                                    mood: .happy,
                                    accessory: current.accessories[fairy],
                                    wingDesign: sim.wingDesigns[fairy],
                                    time: 0.2,
                                    scale: 0.56,
                                    blinkSeed: 0
                                )
                            }
                            .allowsHitTesting(false)
                        }
                        .frame(width: 54, height: 54)
                        .overlay(Circle().stroke(isSelected ? Theme.pink : Theme.blush, lineWidth: isSelected ? 4 : 2))
                        .overlay(alignment: .topTrailing) {
                            if isPinned {
                                pinCornerBadge
                            }
                        }
                        .scaleEffect(isSelected ? 1.06 : 0.94)
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel(fairy.rawValue)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
        }
        .frame(width: 68, height: 420)
        .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Theme.cream.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Theme.blush, lineWidth: 3))
        .shadow(color: Theme.ink.opacity(0.14), radius: 8, y: 4)
    }

    // MARK: - Lifted Bottom Dock (y = 740)

    @ViewBuilder
    private func bottomDock(_ current: FairiesUIState) -> some View {
        switch current.station {
        case .stage:
            stageDock(current)
        case .salon:
            salonDock(current)
        case .teaTable:
            teaDock(current)
        }
    }

    private func stageDock(_ current: FairiesUIState) -> some View {
        GameTrayCard(cornerRadius: 34, paddingH: 14, paddingV: 10) {
            HStack(spacing: 11) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FairyKind.allCases) { fairy in
                            compactFairyTile(fairy, current: current)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                }
                .scrollDisabled(trayDragFairy != nil)
                .frame(width: 472, height: 74)

                dockDivider

                HStack(spacing: 6) {
                    ForEach(FairyAccessory.allCases) { acc in
                        accessoryTile(acc, current: current)
                    }
                }

                dockDivider

                starPinButton(current, size: 62)
            }
        }
    }

    private func compactFairyTile(_ fairy: FairyKind, current: FairiesUIState) -> some View {
        let isSelected = current.selectedFairy == fairy
        let isDraggingThis = current.draggingCompactFairy == fairy && !current.compactDragStartedInRoom
        let isInRoom = current.activeCompactFairies.contains(fairy)
        let isPinned = current.pinnedFairy == fairy

        return GameDockTile(
            size: 64,
            selected: isSelected,
            tint: Color(hex: fairy.palette.wingInner),
            cornerRadius: 20
        ) {
            if !isDraggingThis {
                Canvas { ctx, sz in
                    _ = current.wingDesignVersion
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2 + 5)
                    FairiesArt.drawFairy(
                        g,
                        kind: fairy,
                        mood: .happy,
                        accessory: current.accessories[fairy],
                        wingDesign: sim.wingDesigns[fairy],
                        transform: current.activeTransforms[fairy],
                        time: 0.25,
                        scale: 0.64,
                        blinkSeed: 0
                    )
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

    private func accessoryTile(_ accessory: FairyAccessory, current: FairiesUIState) -> some View {
        let worn = current.accessories[current.selectedFairy] == accessory
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
        .accessibilityLabel(accessory.rawValue)
    }

    // MARK: - Salon Dock

    @ViewBuilder
    private func salonDock(_ current: FairiesUIState) -> some View {
        if current.salonTool == .wandBuilder {
            wandBuilderDock(current)
        } else {
            wingPainterDock(current)
        }
    }

    private func wingPainterDock(_ current: FairiesUIState) -> some View {
        let (isBrush, isGlitter, isStamp, isWipe): (Bool, Bool, Bool, Bool) = {
            switch current.salonTool {
            case .brush: return (true, false, false, false)
            case .glitter: return (false, true, false, false)
            case .stamp: return (false, false, true, false)
            case .wipe: return (false, false, false, true)
            case .wandBuilder: return (false, false, false, false)
            }
        }()

        return GameTrayCard(cornerRadius: 34, paddingH: 14, paddingV: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    salonModeButton(selected: isBrush, tint: Theme.blush.opacity(0.55), label: "Wing Brush") {
                        sim.selectSalonTool(.brush(lastBrushColor))
                    } icon: { ctx in
                        FairiesArt.drawBrushToolIcon(ctx, colorHex: lastBrushColor.baseHex)
                    }
                    salonModeButton(selected: isGlitter, tint: Theme.lemon.opacity(0.55), label: "Glitter Shaker") {
                        sim.selectSalonTool(.glitter(lastGlitterHex))
                    } icon: { ctx in
                        FairiesArt.drawGlitterToolIcon(ctx, hex: lastGlitterHex)
                    }
                    salonModeButton(selected: isStamp, tint: Theme.sky.opacity(0.45), label: "Dewdrop Stamps") {
                        sim.selectSalonTool(.stamp(lastStampKind))
                    } icon: { ctx in
                        FairyWingPainter.drawStamp(ctx, kind: lastStampKind, radius: 17)
                    }
                    salonModeButton(selected: isWipe, tint: Theme.mint.opacity(0.55), label: "Wipe") {
                        sim.selectSalonTool(.wipe)
                    } icon: { ctx in
                        FairiesArt.drawWipeToolIcon(ctx)
                    }
                    salonModeButton(selected: false, tint: Theme.lilac.opacity(0.55), label: "Wand Builder") {
                        sim.selectSalonTool(.wandBuilder)
                    } icon: { ctx in
                        FairiesArt.drawWandBuilderToolIcon(ctx)
                    }
                }

                dockDivider

                salonSubSwatches(current)

                dockDivider

                HStack(spacing: 8) {
                    Button {
                        _ = sim.undoSalonAction()
                    } label: {
                        ZStack {
                            Circle().fill(current.canUndoWingStroke ? .white : Theme.cream)
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(current.canUndoWingStroke ? Theme.pink : Theme.ink.opacity(0.28))
                        }
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(Theme.blush, lineWidth: 3))
                    }
                    .buttonStyle(Squish())
                    .disabled(!current.canUndoWingStroke)
                    .accessibilityLabel("Undo")

                    starPinButton(current, size: 54)
                }
            }
        }
    }

    @ViewBuilder
    private func salonSubSwatches(_ current: FairiesUIState) -> some View {
        switch current.salonTool {
        case .brush(let activeColor):
            HStack(spacing: 6) {
                ForEach(WingBrushColor.allCases) { swatch in
                    let selected = activeColor == swatch
                    Button {
                        lastBrushColor = swatch
                        sim.selectSalonTool(.brush(swatch))
                    } label: {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(hex: swatch.shimmerHex), Color(hex: swatch.baseHex)],
                                    center: UnitPoint(x: 0.35, y: 0.3),
                                    startRadius: 2,
                                    endRadius: 24
                                )
                            )
                            .frame(width: 46, height: 46)
                            .overlay(Circle().stroke(selected ? Theme.pink : .white, lineWidth: selected ? 4.5 : 3))
                            .shadow(color: Theme.ink.opacity(selected ? 0.25 : 0.12), radius: 4, y: 2)
                            .scaleEffect(selected ? 1.12 : 0.96)
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel(swatch.rawValue)
                }
            }

        case .glitter(let activeHex):
            HStack(spacing: 8) {
                ForEach(FairySalonTool.glitterPalette, id: \.self) { hex in
                    let selected = activeHex == hex
                    Button {
                        lastGlitterHex = hex
                        sim.selectSalonTool(.glitter(hex))
                    } label: {
                        ZStack {
                            Circle().fill(Color(hex: hex, alpha: 0.35))
                            Canvas { ctx, sz in
                                var g = ctx
                                g.translateBy(x: sz.width / 2, y: sz.height / 2)
                                StorybookArt.sparkle(g, at: .zero, radius: 15, color: Color(hex: hex))
                                StorybookArt.sparkle(g, at: .zero, radius: 7, color: .white)
                            }
                            .allowsHitTesting(false)
                        }
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(selected ? Theme.pink : .white, lineWidth: selected ? 4.5 : 3))
                        .scaleEffect(selected ? 1.1 : 0.96)
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel("Glitter")
                }
            }

        case .stamp(let activeKind):
            HStack(spacing: 8) {
                ForEach(WingStampKind.allCases) { kind in
                    let selected = activeKind == kind
                    Button {
                        lastStampKind = kind
                        sim.selectSalonTool(.stamp(kind))
                    } label: {
                        GameDockTile(size: 52, selected: selected, tint: .white, cornerRadius: 18) {
                            Canvas { ctx, sz in
                                var g = ctx
                                g.translateBy(x: sz.width / 2, y: sz.height / 2)
                                FairyWingPainter.drawStamp(g, kind: kind, radius: 16)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel(kind.rawValue)
                }
            }

        case .wipe:
            Button {
                sim.clearCurrentWings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 22)
                .frame(height: 52)
                .background(Capsule().fill(Theme.sky))
                .overlay(Capsule().stroke(.white, lineWidth: 3.5))
                .shadow(color: Theme.ink.opacity(0.18), radius: 5, y: 3)
            }
            .buttonStyle(Squish())
            .accessibilityLabel("Clear Wings")

        case .wandBuilder:
            EmptyView()
        }
    }

    private func wandBuilderDock(_ current: FairiesUIState) -> some View {
        let wand = current.currentWand
        return GameTrayCard(cornerRadius: 34, paddingH: 12, paddingV: 10) {
            HStack(spacing: 10) {
                salonModeButton(selected: false, tint: Theme.blush.opacity(0.55), label: "Wing Brush") {
                    sim.selectSalonTool(.brush(lastBrushColor))
                } icon: { ctx in
                    FairiesArt.drawBrushToolIcon(ctx, colorHex: lastBrushColor.baseHex)
                }

                dockDivider

                HStack(spacing: 5) {
                    ForEach(WandTopper.allCases) { topper in
                        Button {
                            sim.setWandTopper(topper)
                        } label: {
                            GameDockTile(size: 46, selected: wand.topper == topper, tint: .white, cornerRadius: 15) {
                                Canvas { ctx, sz in
                                    var g = ctx
                                    g.translateBy(x: sz.width / 2, y: sz.height / 2 + 1)
                                    g.scaleBy(x: 0.65, y: 0.65)
                                    FairyWingPainter.drawWandTopper(g, topper: topper)
                                }
                                .allowsHitTesting(false)
                            }
                        }
                        .buttonStyle(Squish())
                        .accessibilityLabel(topper.rawValue)
                    }
                }

                dockDivider

                HStack(spacing: 5) {
                    ForEach(WandShaft.allCases) { shaft in
                        Button {
                            sim.setWandShaft(shaft)
                        } label: {
                            GameDockTile(size: 46, selected: wand.shaft == shaft, tint: .white, cornerRadius: 15) {
                                Canvas { ctx, sz in
                                    var g = ctx
                                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                                    FairiesArt.drawWandShaftIcon(g, shaft: shaft)
                                }
                                .allowsHitTesting(false)
                            }
                        }
                        .buttonStyle(Squish())
                        .accessibilityLabel(shaft.rawValue)
                    }
                }

                dockDivider

                HStack(spacing: 5) {
                    ForEach(WandRibbon.allCases) { ribbon in
                        Button {
                            sim.setWandRibbon(ribbon)
                        } label: {
                            GameDockTile(size: 46, selected: wand.ribbon == ribbon, tint: .white, cornerRadius: 15) {
                                Canvas { ctx, sz in
                                    var g = ctx
                                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                                    FairiesArt.drawWandRibbonIcon(g, ribbon: ribbon)
                                }
                                .allowsHitTesting(false)
                            }
                        }
                        .buttonStyle(Squish())
                        .accessibilityLabel(ribbon.rawValue)
                    }
                }

                dockDivider

                starPinButton(current, size: 50)
            }
        }
    }

    private func salonModeButton(
        selected: Bool,
        tint: Color,
        label: String,
        action: @escaping () -> Void,
        icon: @escaping (GraphicsContext) -> Void
    ) -> some View {
        Button(action: action) {
            GameDockTile(size: 54, selected: selected, tint: selected ? tint : .white, cornerRadius: 18) {
                Canvas { ctx, sz in
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                    icon(g)
                }
                .allowsHitTesting(false)
            }
        }
        .buttonStyle(Squish())
        .accessibilityLabel(label)
    }

    // MARK: - Pixie Tea Table Dock

    private func teaDock(_ current: FairiesUIState) -> some View {
        let isTransformed = current.tea.stage == .transformed
        let canTapServe = current.tea.canServe || isTransformed

        return GameTrayCard(cornerRadius: 34, paddingH: 14, paddingV: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(SugarStarKind.allCases) { star in
                        teaSugarTile(star, current: current)
                    }
                }

                dockDivider

                HStack(spacing: 8) {
                    ForEach(FairyTeaTreatKind.allCases) { treat in
                        teaTreatTile(treat, current: current)
                    }
                }

                dockDivider

                Button {
                    if isTransformed {
                        sim.startNextTeaOrder()
                    } else {
                        _ = sim.serveTea()
                    }
                } label: {
                    GameDockTile(
                        size: 66,
                        selected: canTapServe,
                        pulsing: canTapServe,
                        tint: canTapServe ? Theme.lemon : .white,
                        cornerRadius: 22
                    ) {
                        Canvas { ctx, sz in
                            var g = ctx
                            g.translateBy(x: sz.width / 2, y: sz.height / 2)
                            if isTransformed {
                                StorybookArt.sparkle(g, at: .zero, radius: 18, color: .white)
                                StorybookArt.heart(g, at: CGPoint(x: 12, y: -12), size: 14, color: Theme.pink)
                            } else {
                                FairiesArt.drawServeBellIcon(g)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
                .buttonStyle(Squish())
                .opacity(canTapServe ? 1 : 0.48)
                .accessibilityLabel("Serve Tea")

                starPinButton(current, size: 58)
            }
        }
    }

    private func teaSugarTile(_ star: SugarStarKind, current: FairiesUIState) -> some View {
        let wished = current.tea.wish.sugarStar == star && !current.tea.sugarStars.contains(star)
        return GameDockTile(
            size: 62,
            selected: wished,
            tint: Color(hex: star.colorHex, alpha: 0.18),
            cornerRadius: 20
        ) {
            Canvas { ctx, sz in
                var g = ctx
                g.translateBy(x: sz.width / 2, y: sz.height / 2)
                FairiesArt.drawSugarStarIcon(g, star: star)
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(teaSugarGesture(star))
        .accessibilityLabel(star.rawValue)
    }

    private func teaTreatTile(_ treat: FairyTeaTreatKind, current: FairiesUIState) -> some View {
        let wished = current.tea.wish.treat == treat && current.tea.platedTreat != treat
        return GameDockTile(
            size: 62,
            selected: wished,
            tint: Color(hex: treat.accentHex, alpha: 0.18),
            cornerRadius: 20
        ) {
            Canvas { ctx, sz in
                var g = ctx
                g.translateBy(x: sz.width / 2, y: sz.height / 2)
                FairiesArt.drawTeaTreatIcon(g, treat: treat)
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(teaTreatGesture(treat))
        .accessibilityLabel(treat.rawValue)
    }

    // MARK: - Shared Controls

    private var dockDivider: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Theme.blush)
            .frame(width: 3, height: 50)
    }

    private func starPinButton(_ current: FairiesUIState, size: CGFloat) -> some View {
        let pinned = current.pinnedFairy == current.selectedFairy
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
                    .font(.system(size: size * 0.45, weight: .black))
                    .foregroundStyle(pinned ? .white : Color(hex: 0xE6A424))
                    .shadow(color: pinned ? Color(hex: 0xB9770E).opacity(0.45) : .clear, radius: 2, y: 1)
            }
            .frame(width: size, height: size)
            .overlay(Circle().stroke(pinned ? Color(hex: 0xFFB830) : Color(hex: 0xFFD97D), lineWidth: pinned ? 4 : 3))
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

    private func resetLocalDrags() {
        trayDragFairy = nil
        dockSugarDrag = nil
        dockSugarStarted = false
        dockTreatDrag = nil
        dockTreatStarted = false
    }

    // MARK: - Gestures

    private var sceneGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("fairies"))
            .onChanged { v in
                sim.handleSceneDragChanged(start: v.startLocation, current: v.location)
            }
            .onEnded { v in
                let moved = hypot(v.translation.width, v.translation.height)
                sim.handleSceneDragEnded(at: v.location, isTap: moved < 12)
            }
    }

    private func compactTrayFairyGesture(_ fairy: FairyKind) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("fairies"))
            .onChanged { v in
                let p = v.location
                if trayDragFairy == nil {
                    guard v.translation.height < -10, abs(v.translation.height) >= abs(v.translation.width) * 0.45 else { return }
                    trayDragFairy = fairy
                    sim.beginDockFairyDrag(fairy, finger: p)
                }
                guard trayDragFairy == fairy else { return }
                sim.updateDockFairyDrag(finger: p)
            }
            .onEnded { v in
                guard trayDragFairy == fairy else { return }
                sim.endDockFairyDrag(finger: v.location)
                trayDragFairy = nil
            }
    }

    private func teaSugarGesture(_ star: SugarStarKind) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("fairies"))
            .onChanged { v in
                let moved = hypot(v.translation.width, v.translation.height)
                if !dockSugarStarted {
                    guard moved >= 12 else { return }
                    dockSugarStarted = true
                    dockSugarDrag = star
                    sim.beginDockSugarDrag(star, finger: v.location)
                } else if dockSugarDrag == star {
                    sim.updateDockSugarDrag(finger: v.location)
                }
            }
            .onEnded { v in
                if dockSugarStarted && dockSugarDrag == star {
                    sim.endDockSugarDrag(finger: v.location)
                } else {
                    _ = sim.addSugarStar(star)
                }
                dockSugarStarted = false
                dockSugarDrag = nil
            }
    }

    private func teaTreatGesture(_ treat: FairyTeaTreatKind) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("fairies"))
            .onChanged { v in
                let moved = hypot(v.translation.width, v.translation.height)
                if !dockTreatStarted {
                    guard moved >= 12 else { return }
                    dockTreatStarted = true
                    dockTreatDrag = treat
                    sim.beginDockTreatDrag(treat, finger: v.location)
                } else if dockTreatDrag == treat {
                    sim.updateDockTreatDrag(finger: v.location)
                }
            }
            .onEnded { v in
                if dockTreatStarted && dockTreatDrag == treat {
                    sim.endDockTreatDrag(finger: v.location)
                } else {
                    _ = sim.plateTreat(treat)
                }
                dockTreatStarted = false
                dockTreatDrag = nil
            }
    }
}
