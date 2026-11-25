import SwiftUI

// MARK: - Full-bleed Unpacking room backdrop

struct UnpackingRoomBackdrop: View {
    let roomID: UnpackingRoomID

    var body: some View {
        Canvas { ctx, size in
            let map = GameStageMap(size: size)
            var g = ctx
            g.scaleBy(x: map.scale, y: map.scale)
            let logical = CGSize(width: size.width / map.scale, height: size.height / map.scale)
            let floorLineY = (map.origin.y / map.scale) + 556
            UnpackingRoomArt.backdrop(roomID, g, size: logical, floorLineY: floorLineY)
        }
    }
}

// MARK: - Pictorial Box + Sparkle Mode Icon

struct UnpackingModeIcon: View {
    let selected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(selected ? .white : Theme.ink.opacity(0.68))
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(selected ? Theme.lemon : Theme.pink)
                .offset(x: 6, y: -5)
        }
    }
}

// MARK: - Room Picker Card (3 x 2 Grid)

struct UnpackingRoomCard: View {
    let roomID: UnpackingRoomID
    let saved: SavedUnpackingRoom?
    let done: Bool
    let glow: Bool
    let tap: () -> Void

    @State private var bob = false

    var body: some View {
        Button(action: tap) {
            ZStack(alignment: .topTrailing) {
                Canvas { ctx, size in
                    let sx = size.width / GameChromeLayout.width
                    let sy = size.height / GameChromeLayout.height
                    var c = ctx
                    c.scaleBy(x: sx, y: sy)
                    UnpackingRenderer.thumbnail(roomID: roomID, saved: saved, in: c)
                }
                .frame(width: 294, height: 238)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(glow ? Theme.pink : .white, lineWidth: glow ? 5.5 : 4.5)
                )
                .shadow(color: Theme.ink.opacity(0.2), radius: 9, y: 6)

                // Cute pictorial room icon badge in bottom-left
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: roomID.badgeSymbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(hex: roomID.accentHex)))
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(color: Theme.ink.opacity(0.22), radius: 4, y: 2)
                        Spacer()
                    }
                }
                .padding(12)
                .frame(width: 294, height: 238)

                if done {
                    Image(systemName: "star.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.lemon)
                        .shadow(color: Theme.ink.opacity(0.35), radius: 0, y: 2)
                        .padding(9)
                        .background(Circle().fill(.white))
                        .overlay(Circle().stroke(Theme.blush, lineWidth: 2.5))
                        .offset(x: 9, y: -9)
                }
            }
            .scaleEffect(glow && bob ? 1.035 : 1)
        }
        .buttonStyle(Squish())
        .onAppear {
            if glow {
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    bob = true
                }
            }
        }
    }
}

// MARK: - Unpacking Gameplay View

struct UnpackingPlayView: View {
    let roomID: UnpackingRoomID
    @ObservedObject var tidyStore: TidyStore
    @ObservedObject var unpackingStore: UnpackingStore
    let nextRoom: () -> Void
    let levels: () -> Void
    let exit: () -> Void

    @StateObject private var world: UnpackingWorld
    @State private var touching = false
    @State private var showDone = false
    @State private var showBook = false
    @State private var confirmReset = false
    @State private var resetArmedAt = Date.distantPast
    @State private var resetPulse = false

    init(
        roomID: UnpackingRoomID,
        tidyStore: TidyStore,
        unpackingStore: UnpackingStore,
        nextRoom: @escaping () -> Void,
        levels: @escaping () -> Void,
        exit: @escaping () -> Void
    ) {
        self.roomID = roomID
        self.tidyStore = tidyStore
        self.unpackingStore = unpackingStore
        self.nextRoom = nextRoom
        self.levels = levels
        self.exit = exit
        _world = StateObject(wrappedValue: UnpackingWorld(roomID: roomID, store: unpackingStore))
    }

    var body: some View {
        ZStack {
            GameStage(background: {
                UnpackingRoomBackdrop(roomID: roomID)
            }) {
                ZStack {
                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: showBook)) { tl in
                        Canvas { ctx, _ in
                            let _ = tl.date
                            UnpackingRenderer.draw(world, ctx)
                        }
                        .onChange(of: tl.date) { date in
                            world.step(to: date)
                        }
                    }
                    .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                if !touching {
                                    touching = true
                                    world.touchDown(v.location)
                                } else {
                                    world.touchMoved(v.location)
                                }
                            }
                            .onEnded { v in
                                touching = false
                                world.touchUp(v.location)
                            }
                    )

                    GameTopBar(
                        gameID: TidyGame.id,
                        showStickerBook: true,
                        showCoins: true,
                        onExit: exit,
                        onStickerBook: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showBook = true
                            }
                        },
                        center: {
                            progressTray
                        },
                        trailing: {
                            HStack(spacing: 12) {
                                RoundButton(symbol: "square.grid.2x2.fill", tint: Color(hex: 0xA77DEB), size: GameChromeLayout.buttonSize) {
                                    Sound.shared.tap()
                                    levels()
                                }
                                protectedReUnpackButton
                                TidyMusicButton(store: tidyStore, size: GameChromeLayout.buttonSize)
                            }
                        }
                    )

                    StickerToast(game: TidyGame.id, target: GameChromeLayout.stickerTarget)

                    if showDone {
                        doneButtons
                            .transition(.scale(scale: 0.35).combined(with: .opacity))
                    }
                }
                .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                .coinPurse(game: TidyGame.id)
            }

            if showBook {
                StickerBookView(game: TidyGame.id) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .onChange(of: world.shouldShowDoneButtons) { ready in
            if ready {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    if world.shouldShowDoneButtons {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                            showDone = true
                        }
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    showDone = false
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                resetPulse = true
            }
        }
        .onDisappear {
            unpackingStore.saveSync()
        }
    }

    /// Zero-word pictorial progress pill: room icon + star dots filling up as she unpacks.
    private var progressTray: some View {
        GameTrayCard(cornerRadius: 26, paddingH: 14, paddingV: 8) {
            HStack(spacing: 10) {
                Image(systemName: roomID.badgeSymbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(hex: roomID.accentHex)))

                HStack(spacing: 4) {
                    ForEach(0..<world.totalItemCount, id: \.self) { i in
                        let filled = i < world.placedCount
                        Image(systemName: filled ? "star.fill" : "circle.fill")
                            .font(.system(size: filled ? 13 : 8, weight: .bold))
                            .foregroundStyle(filled ? Theme.lemon : Theme.ink.opacity(0.18))
                            .shadow(color: filled ? Theme.ink.opacity(0.24) : .clear, radius: 1, y: 1)
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.88)))
            }
        }
    }

    private var protectedReUnpackButton: some View {
        let size = GameChromeLayout.buttonSize
        return Button {
            handleResetTap()
        } label: {
            Image(systemName: confirmReset ? "shippingbox.fill" : "arrow.counterclockwise")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(confirmReset ? .white : Color(hex: 0x4CC3C0))
                .frame(width: size, height: size)
                .background(Circle().fill(confirmReset ? Theme.pink : Color.white))
                .overlay(Circle().stroke(confirmReset ? Color.white : Color(hex: 0x4CC3C0).opacity(0.35), lineWidth: 4.5))
                .shadow(color: (confirmReset ? Theme.pink : Theme.ink).opacity(0.28), radius: confirmReset ? 9 : 6, y: 4)
        }
        .buttonStyle(Squish())
        .scaleEffect(confirmReset && resetPulse ? 1.12 : 1)
        .accessibilityLabel(confirmReset ? "Confirm Re-Unpack Room" : "Re-Unpack Room")
    }

    private func handleResetTap() {
        let hasProgress = world.placedCount > 0 || world.boxes.contains(where: \.isOpened)
        if !hasProgress || confirmReset {
            confirmReset = false
            showDone = false
            Sound.shared.tap()
            world.resetRoom()
            return
        }
        let armed = Date()
        resetArmedAt = armed
        Sound.shared.play(.tap, volume: 0.6)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
            confirmReset = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if resetArmedAt == armed {
                withAnimation(.easeOut(duration: 0.2)) {
                    confirmReset = false
                }
            }
        }
    }

    /// Lifted cleanly above Home Indicator (`padding(.bottom, 74)`), leaving the whole room interactive above!
    private var doneButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 30) {
                RoundButton(symbol: "arrow.counterclockwise", tint: Color(hex: 0x4CC3C0), size: 88) {
                    Sound.shared.tap()
                    showDone = false
                    world.resetRoom()
                }
                .accessibilityLabel("Re-Unpack Room")

                Button {
                    Sound.shared.tap()
                    nextRoom()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 132, height: 132)
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xFF9FC8), Theme.pink],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        )
                        .overlay(Circle().stroke(.white, lineWidth: 7))
                        .shadow(color: Theme.ink.opacity(0.3), radius: 10, y: 7)
                }
                .buttonStyle(Squish())
                .accessibilityLabel("Next Room")

                RoundButton(symbol: "square.grid.2x2.fill", tint: Color(hex: 0xA77DEB), size: 88) {
                    Sound.shared.tap()
                    levels()
                }
                .accessibilityLabel("Rooms")
            }
            .padding(.bottom, 74)
        }
    }
}

// MARK: - Unpacking Canvas Renderer

enum UnpackingRenderer {
    static func draw(_ w: UnpackingWorld, _ ctx: GraphicsContext) {
        // 1. Cozy full-room backdrop & furniture
        UnpackingRoomArt.drawRoom(w.room.id, in: ctx, time: w.time, warmGlow: w.roomGlow)

        // 2. Soft warm surface highlights when dragging or after a gentle bounce hint
        let heldItem = w.heldID.flatMap { id in w.items.first(where: { $0.id == id }) }
        if let held = heldItem {
            drawCompatibleSurfaceHighlights(w, held: held, ctx: ctx)
        } else if let hintID = w.hintSurfaceID, w.time - w.hintAt < 2.2, let zone = w.room.surface(id: hintID) {
            let fade = 1 - (w.time - w.hintAt) / 2.2
            let pulse = (0.5 + 0.5 * sin(w.time * 7)) * fade
            drawSurfaceGlow(ctx, zone: zone, active: true, pulse: pulse)
        }

        // 3. Placed items sorted by z (wall items behind floor/furniture, grounding shadows under standing items)
        let placed = w.items
            .filter { $0.phase == .placed }
            .sorted { lhs, rhs in
                let lw = w.room.surface(id: lhs.surfaceID ?? "")?.kind == .wall ? 0 : 1
                let rw = w.room.surface(id: rhs.surfaceID ?? "")?.kind == .wall ? 0 : 1
                if lw != rw { return lw < rw }
                return lhs.z < rhs.z
            }

        for item in placed {
            let isWall = w.room.surface(id: item.surfaceID ?? "")?.kind == .wall
            if !isWall {
                TidyRenderer.softShadow(
                    ctx,
                    CGPoint(x: item.pos.x, y: item.pos.y + item.size.height * 0.5),
                    width: item.size.width * 1.02,
                    height: 10,
                    alpha: 0.22
                )
            }
            drawItem(ctx, item, time: w.time, floatingGlow: false)
        }

        // 4. Cheering Hanbok plush bear treasure in bottom-right corner if owned
        if TidyWorld.hasPlushBear {
            let bearPos = CGPoint(x: GameChromeLayout.width - 74, y: w.room.floorY - 4)
            let cheer: Double
            if w.isDone {
                cheer = 0.72 + 0.28 * sin(w.time * 6.5)
            } else if w.lastPlace >= 0 && w.time - w.lastPlace < 1.15 {
                cheer = sin((w.time - w.lastPlace) / 1.15 * .pi)
            } else {
                cheer = 0
            }
            TidyRenderer.softShadow(ctx, CGPoint(x: bearPos.x, y: bearPos.y + 1), width: 72, height: 14, alpha: 0.24)
            TidySceneArt.hanbokPlushBear(ctx, at: bearPos, time: w.time, cheer: cheer)
        }

        // 5. Moving boxes on the floor (taped, opening, or collapsing)
        let inviteBoxPulse = (heldItem == nil && !w.items.contains(where: { $0.phase == .staged || $0.phase == .emerging }))
            ? (0.35 + 0.65 * (0.5 + 0.5 * sin(w.time * 3.8)))
            : 0
        for box in w.boxes where !box.isGone {
            let r = box.spec.rect
            let shadowScale = max(0, 1 - box.collapseProgress)
            if shadowScale > 0.05 {
                TidyRenderer.softShadow(
                    ctx,
                    CGPoint(x: r.midX, y: r.maxY + 2),
                    width: r.width * 1.12 * shadowScale,
                    height: 16 * shadowScale,
                    alpha: 0.26 * Double(shadowScale)
                )
            }
            UnpackingRoomArt.drawMovingBox(
                ctx,
                rect: r,
                open: box.openProgress,
                tapePeel: box.tapePeel,
                remainingCount: box.remaining.count,
                kick: box.kick,
                collapse: box.collapseProgress,
                highlightPulse: box.remaining.isEmpty ? 0 : inviteBoxPulse
            )
        }

        // 6. Placement rings
        for r in w.rings {
            let t = CGFloat((w.time - r.born) / 0.6)
            let rad = r.size * 0.42 + 64 * t
            let p = Path(ellipseIn: CGRect(x: r.pos.x - rad, y: r.pos.y - rad, width: rad * 2, height: rad * 2))
            ctx.stroke(p, with: .color(r.color.color(Double(1 - t) * 0.9)), lineWidth: 5.5 * (1 - t) + 1)
        }

        // 7. Hover landing shadow indicator on active compatible surface (zero rigid silhouette!)
        if let held = heldItem, let preview = w.hoverPreviewPos,
           let sid = w.hoverSurfaceID, let zone = w.room.surface(id: sid) {
            if zone.kind == .wall {
                let pRect = CGRect(
                    x: preview.x - held.size.width * 0.52,
                    y: preview.y - held.size.height * 0.52,
                    width: held.size.width * 1.04,
                    height: held.size.height * 1.04
                )
                ctx.fill(Path(roundedRect: pRect, cornerRadius: 12), with: .color(Color(hex: 0xFFF3B8, alpha: 0.32)))
                ctx.stroke(Path(roundedRect: pRect, cornerRadius: 12), with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 2.5, dash: [6, 5]))
            } else {
                let padY = preview.y + held.size.height * 0.5
                let padRect = CGRect(x: preview.x - held.size.width * 0.52, y: padY - 7, width: held.size.width * 1.04, height: 14)
                ctx.fill(Path(ellipseIn: padRect), with: .color(Color(hex: 0xFFE38A, alpha: 0.65)))
                ctx.stroke(Path(ellipseIn: padRect), with: .color(.white.opacity(0.9)), lineWidth: 2)
            }
        }

        // 8. Emerging, staged, settling, and bouncing items
        let activeItems = w.items
            .filter { $0.phase != .placed && $0.phase != .held }
            .sorted { $0.z < $1.z }
        for item in activeItems {
            drawItem(ctx, item, time: w.time, floatingGlow: item.phase == .staged)
        }

        // 9. Held item on very top with lifted shadow
        if let held = heldItem {
            drawItem(ctx, held, time: w.time, floatingGlow: false)
        }

        // 10. Sparkles, puffs, confetti, hearts, steam
        drawParticles(w, ctx)
    }

    private static func drawCompatibleSurfaceHighlights(_ w: UnpackingWorld, held: UnpackingItemState, ctx: GraphicsContext) {
        let pulse = 0.5 + 0.5 * sin(w.time * 5.2)
        for zone in w.room.surfaces where held.kind.allowedSurfaces.contains(zone.kind) {
            let isHovered = (w.hoverSurfaceID == zone.id)
            drawSurfaceGlow(ctx, zone: zone, active: isHovered, pulse: isHovered ? 1.0 : (0.38 + 0.22 * pulse))
        }
    }

    private static func drawSurfaceGlow(_ ctx: GraphicsContext, zone: SurfaceZone, active: Bool, pulse: Double) {
        if zone.kind == .wall {
            let p = Path(roundedRect: zone.rect, cornerRadius: 16)
            ctx.fill(p, with: .color(Color(hex: 0xFFF4B8, alpha: (active ? 0.24 : 0.11) * pulse)))
            ctx.stroke(
                p,
                with: .color(Color(hex: 0xFFE074, alpha: (active ? 0.92 : 0.45) * pulse)),
                style: StrokeStyle(lineWidth: active ? 4 : 2.5, dash: [10, 8])
            )
        } else {
            // Soft warm horizontal ribbon resting right along the surface ledge/top!
            let stripH: CGFloat = active ? 22 : 14
            let stripRect = CGRect(
                x: zone.rect.minX + 4,
                y: min(zone.restY, 760) - stripH * 0.72,
                width: max(12, zone.rect.width - 8),
                height: stripH
            )
            let p = Path(roundedRect: stripRect, cornerRadius: stripH * 0.5)
            ctx.fill(
                p,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(hex: 0xFFF6C2, alpha: (active ? 0.65 : 0.28) * pulse),
                        Color(hex: 0xFFE07D, alpha: (active ? 0.35 : 0.12) * pulse),
                    ]),
                    startPoint: CGPoint(x: stripRect.midX, y: stripRect.minY),
                    endPoint: CGPoint(x: stripRect.midX, y: stripRect.maxY)
                )
            )
            if active {
                ctx.stroke(p, with: .color(.white.opacity(0.88 * pulse)), lineWidth: 2.5)
            }
        }
    }

    private static func drawItem(_ ctx: GraphicsContext, _ item: UnpackingItemState, time: Double, floatingGlow: Bool) {
        let bobY: CGFloat = floatingGlow ? CGFloat(sin(time * 4.2 + Double(item.z)) * 4.5) : 0

        if floatingGlow {
            let glowR = max(item.size.width, item.size.height) * 0.72
            let glowRect = CGRect(x: item.pos.x - glowR, y: item.pos.y + bobY - glowR, width: glowR * 2, height: glowR * 2)
            ctx.fill(
                Path(ellipseIn: glowRect),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xFFF6C4, alpha: 0.58), .clear]),
                    center: CGPoint(x: item.pos.x, y: item.pos.y + bobY),
                    startRadius: 4,
                    endRadius: glowR
                )
            )
        }

        var c = ctx
        if item.lift > 0.02 {
            c.addFilter(.shadow(
                color: Color(hex: 0x3A2248, alpha: 0.28 * Double(item.lift)),
                radius: 3 + 9 * item.lift,
                x: 6 * item.lift,
                y: 10 + 18 * item.lift
            ))
        }

        c.drawLayer { l in
            l.translateBy(x: item.pos.x, y: item.pos.y + bobY)
            l.rotate(by: .radians(Double(item.tilt)))
            let grow = 1 + 0.1 * item.lift
            let sq = max(-0.32, min(0.32, item.squash))
            let half = item.size.height * 0.5
            l.translateBy(x: 0, y: half)
            l.scaleBy(x: (1 - sq * 0.55) * grow, y: (1 + sq) * grow)
            l.translateBy(x: 0, y: -half)
            UnpackingItemArt.draw(
                item.kind,
                color: item.color,
                in: l,
                isLit: item.isLit,
                interactPhase: item.interactTimer,
                time: time
            )
        }
    }

    private static func drawParticles(_ w: UnpackingWorld, _ ctx: GraphicsContext) {
        for p in w.particles {
            let t = CGFloat((w.time - p.born) / max(0.01, p.life))
            switch p.kind {
            case .sparkle:
                let s = p.size * (1 - t * 0.65)
                var c = ctx
                c.translateBy(x: p.pos.x, y: p.pos.y)
                c.rotate(by: .radians(Double(p.rot)))
                c.opacity = Double(max(0, 1 - t))
                c.fill(Twinkle().path(in: CGRect(x: -s / 2, y: -s / 2, width: s, height: s)), with: .color(p.color.color))
            case .puff:
                let r = p.size * (0.6 + t)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p.pos.x - r, y: p.pos.y - r, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(Double(max(0, 0.55 * (1 - t)))))
                )
            case .confetti:
                var c = ctx
                c.translateBy(x: p.pos.x, y: p.pos.y)
                c.rotate(by: .radians(Double(p.rot)))
                c.scaleBy(x: max(0.15, abs(cos(p.rot * 1.7))), y: 1)
                c.opacity = Double(min(1, max(0, (1 - t) * 3)))
                let r = CGRect(x: -p.size / 2, y: -p.size * 0.32, width: p.size, height: p.size * 0.64)
                c.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(p.color.color))
            case .heart:
                let s = p.size * (0.85 + 0.3 * CGFloat(sin(Double(t) * .pi)))
                StorybookArt.heart(ctx, at: p.pos.pt, size: s, color: p.color.color, opacity: Double(max(0, 1 - t)))
            case .steam:
                let r = p.size * (0.5 + t * 0.9)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p.pos.x - r, y: p.pos.y - r, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(Double(max(0, 0.5 * (1 - t)))))
                )
            }
        }
    }

    /// Miniature preview for the 6-room picker: displays HER exact saved room layout if she decorated it,
    /// or the cozy room with taped cardboard moving boxes waiting to be opened!
    static func thumbnail(roomID: UnpackingRoomID, saved: SavedUnpackingRoom?, in ctx: GraphicsContext) {
        let spec = UnpackingRooms.spec(for: roomID)
        let lit = saved?.completed == true
        UnpackingRoomArt.drawRoom(roomID, in: ctx, time: 0.4, warmGlow: lit ? 0.9 : 0)

        if let saved {
            let placedIDs = Set(saved.placed.map(\.itemID))
            for item in saved.placed.sorted(by: { $0.z < $1.z }) {
                var c = ctx
                c.translateBy(x: item.x, y: item.y)
                UnpackingItemArt.draw(item.kind, color: item.color, in: c, isLit: item.isLit || lit, time: 0.4)
            }
            for box in spec.boxes {
                let left = box.items.filter { !placedIDs.contains($0.id) }.count
                if left > 0 {
                    let opened = saved.openedBoxes.contains(box.id)
                    UnpackingRoomArt.drawMovingBox(
                        ctx,
                        rect: box.rect,
                        open: opened ? 1 : 0,
                        tapePeel: opened ? 1 : 0,
                        remainingCount: left,
                        kick: 0,
                        collapse: 0,
                        highlightPulse: 0
                    )
                }
            }
        } else {
            for box in spec.boxes {
                UnpackingRoomArt.drawMovingBox(
                    ctx,
                    rect: box.rect,
                    open: 0,
                    tapePeel: 0,
                    remainingCount: box.items.count,
                    kick: 0,
                    collapse: 0,
                    highlightPulse: 0
                )
            }
        }
    }
}
