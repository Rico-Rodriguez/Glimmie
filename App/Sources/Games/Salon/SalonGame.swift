import SwiftUI

// MARK: - Hair Salon (a game in the drawer)
//
// A client sits in the salon chair with messy hair (sometimes with a leaf or a twig in it). She can
// comb it, wash it (shampoo foam and a shower), towel it, blow-dry it, straighten it, curl it, cut it
// (the pieces fall and pile up on the floor), dye it (14 colors, rainbow, or back to natural), add
// glitter, grow it back with a magic potion, and put in bows, clips, flowers, scrunchies (which
// gather the hair into ponytails, braids, and buns) and Dress Up hats and crowns. The camera puts the
// look on the photo wall (the last 30); tapping a photo brings that client back. Everything is open; no words.
//
// The hair is a physics simulation (SalonHair.swift) drawn as fine strands (SalonPaint.swift); the
// client's face is the Dress Up art.
// Sounds: tools/salon/sounds.py -> App/Resources/Games/Salon/*.wav.

enum SalonGame {
    static let id = "salon"
    static let entry = GameEntry(
        id: id,
        title: "Salon",
        tint: Color(hex: 0xC9B6FF),
        icon: { AnyView(SalonTileIcon()) },
        play: { exit in AnyView(SalonView(exit: exit)) },
        stickers: SalonFind.stickers
    )
}

// MARK: - Saves

final class SalonStore: ObservableObject {
    static let maxPhotos = 30
    @Published private(set) var photos: [SalonVisit]

    init() {
        photos = GameStorage.load([SalonVisit].self, game: SalonGame.id, file: "photos.json") ?? []
    }

    static func loadCurrent() -> SalonVisit? {
        GameStorage.load(SalonVisit.self, game: SalonGame.id, file: "current.json")
    }

    static func saveCurrent(_ v: SalonVisit) {
        var c = v
        c.saved = Date()
        GameStorage.save(c, game: SalonGame.id, file: "current.json")
    }

    func addPhoto(_ v: SalonVisit) {
        var p = v
        p.id = UUID()
        p.saved = Date()
        photos.insert(p, at: 0)
        if photos.count > SalonStore.maxPhotos { photos.removeLast(photos.count - SalonStore.maxPhotos) }
        GameStorage.save(photos, game: SalonGame.id, file: "photos.json")
    }

    func deletePhoto(id: UUID) {
        photos.removeAll { $0.id == id }
        SalonPortrait.evict(id: id)
        GameStorage.save(photos, game: SalonGame.id, file: "photos.json")
    }
}

// MARK: - Portraits (photo wall and drawer tile)

enum SalonPortrait {
    private static var sims: [UUID: HairSim] = [:]

    static func sim(for v: SalonVisit) -> HairSim {
        if let s = sims[v.id] { return s }
        if sims.count > 40 { sims.removeAll() }
        let s = HairSim(save: v.hair, palette: SalonWorld.hairPalette)
        sims[v.id] = s
        return s
    }

    static func evict(id: UUID) {
        sims.removeValue(forKey: id)
    }

    /// Draws a client with her hair, standing still, into `ctx` (already in doll coordinates).
    static func paint(look: Look, sim: HairSim, cape: Int, in ctx: GraphicsContext) {
        paint(look: look, e: .normal, sim: sim, cape: cape, t: 0.3, client: ctx, art: ctx, foam: false)
    }

    /// Her, the chair, the cape and her hair, turned however far she is turned. `client` hops with her,
    /// `art` doesn't (cut hair on the floor).
    static func paint(look: Look, e: Expression, sim: HairSim, cape: Int, t: Double, client: GraphicsContext,
                      art: GraphicsContext, foam: Bool) {
        let yaw = sim.yaw
        SalonFurniture.drawChairBack(yaw: yaw, in: client)
        ClientPainter.drawTurned(look, e, z: 0...9, yaw: yaw, in: client)
        HairPainter.drawBack(sim, in: client)
        for p in sim.pieces where !p.front { HairPainter.draw(p, in: art) }
        ClientPainter.drawTurned(look, e, z: 10...45, yaw: yaw, in: client)
        SalonFurniture.drawCape(color: ClipPainter.clipColor(cape), yaw: yaw, in: client)
        HairPainter.drawFront(sim, in: client)
        ClientPainter.drawTurned(look, e, z: 46...200, yaw: yaw, in: client)
        ClipPainter.drawAll(sim, in: client)
        if foam { HairPainter.drawFoam(sim, in: client) }
        HairPainter.drawFlakes(sim, t: t, in: client)
        for p in sim.pieces where p.front { HairPainter.draw(p, in: art) }
    }

    static func lookWithHat(_ v: SalonVisit) -> Look {
        var l = v.look
        l.picks["hat"] = v.hat
        return l
    }
}

struct SalonPortraitView: View {
    let visit: SalonVisit
    var box = CGRect(x: 60, y: 70, width: 480, height: 560)

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            ArtPainter.fit(&g, box: box, into: size)
            SalonPortrait.paint(look: SalonPortrait.lookWithHat(visit), sim: SalonPortrait.sim(for: visit), cape: visit.cape, in: g)
        }
    }
}

/// The drawer tile shows her latest client with a crisp miniature pink scissors & sparkle badge
/// so Hair Salon immediately stands out from Dress Up.
private struct SalonTileIcon: View {
    private static var cached: (key: String, look: Look, sim: HairSim, cape: Int)?

    var body: some View {
        let t = SalonTileIcon.current()
        ZStack {
            Canvas { ctx, size in
                var g = ctx
                ArtPainter.fit(&g, box: CGRect(x: 96, y: 96, width: 408, height: 440), into: size)
                SalonPortrait.paint(look: t.look, sim: t.sim, cape: t.cape, in: g)
            }
            .padding(-16)

            Canvas { ctx, size in
                let side = min(size.width, size.height)
                let r = side * 0.21
                let center = CGPoint(x: size.width - r - side * 0.04, y: size.height - r - side * 0.04)
                let circle = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))

                var badgeCtx = ctx
                badgeCtx.addFilter(.shadow(color: Theme.ink.opacity(0.24), radius: side * 0.03, x: 0, y: side * 0.02))
                StorybookArt.fillAndStroke(badgeCtx, circle, fill: .white, stroke: Theme.pink, width: max(2.2, side * 0.028))

                var sc = ctx
                sc.translateBy(x: center.x, y: center.y)
                sc.rotate(by: .degrees(-20))
                let scScale = (r * 1.48) / 100
                sc.scaleBy(x: scScale, y: scScale)
                sc.translateBy(x: -50, y: -50)
                SalonToolArt.draw(.scissors, dye: RGB(1, 0.56, 0.72), open: 0.72, in: sc)

                StorybookArt.sparkle(
                    ctx,
                    at: CGPoint(x: center.x - r * 0.92, y: center.y - r * 0.72),
                    radius: max(3.5, side * 0.055),
                    color: Theme.lemon
                )
                StorybookArt.sparkle(
                    ctx,
                    at: CGPoint(x: center.x + r * 0.78, y: center.y - r * 0.92),
                    radius: max(2.8, side * 0.04),
                    color: Theme.pink
                )
            }
            .allowsHitTesting(false)
        }
    }

    static func current() -> (look: Look, sim: HairSim, cape: Int) {
        let v = SalonStore.loadCurrent()
        let key = v.map { "\($0.id)-\($0.saved.timeIntervalSince1970)" } ?? "starter"
        if let c = cached, c.key == key { return (c.look, c.sim, c.cape) }
        let made: (Look, HairSim, Int)
        if let v {
            made = (SalonPortrait.lookWithHat(v), HairSim(save: v.hair, palette: SalonWorld.hairPalette), v.cape)
        } else {
            let c = SalonWorld.makeClient(seed: 21)
            made = (c.0, c.1, 15)
        }
        cached = (key, made.0, made.1, made.2)
        return made
    }
}

// MARK: - The salon

struct SalonView: View {
    let exit: () -> Void
    @StateObject private var store = SalonStore()
    @State private var world: SalonWorld
    @State private var tool: SalonTool?
    @State private var dye = 0
    @State private var glitter = 0
    @State private var hat: String?
    @State private var showPhotos = false
    @State private var showBook = false
    @State private var flash = 0.0
    @State private var burstID = 0
    @State private var pressStart: (tool: SalonTool, wasSelected: Bool)?
    @State private var sideTie = 0
    @State private var draggingFromHair = false
    @State private var overReturnBadge = false
    @State private var carryingFromTray = false
    @State private var suppressClipTapUntil = Date.distantPast
    /// A quick tap on her hair with a tool picked: the tool does that spot by itself (see `ToolTap`).
    @State private var auto = AutoTool()
    @Environment(\.scenePhase) private var phase

    private let autosave = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    init(exit: @escaping () -> Void) {
        self.exit = exit
        let w = SalonWorld(visit: SalonStore.loadCurrent())
        _world = State(initialValue: w)
        _hat = State(initialValue: w.hat)
    }

    static let shelfRight: CGFloat = 222
    static let trayWidth: CGFloat = 258
    private static let returnDropPoint = CGPoint(x: SalonWorld.defaultCenterX, y: GameChromeLayout.height - 58)

    var body: some View {
        ZStack {
            GameStage(background: { SalonBackdropView() }) {
                ZStack {
                    stage
                    HStack(alignment: .top, spacing: 0) {
                        shelf
                        Spacer()
                        if let t = tool, t.hasTray {
                            tray(t)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.top, 98)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)

                    turnButtons

                    if draggingFromHair {
                        ReturnDropBadge(hovered: overReturnBadge)
                            .position(SalonView.returnDropPoint)
                            .transition(.scale.combined(with: .opacity))
                            .allowsHitTesting(false)
                    }

                    GameTopBar(
                        gameID: SalonGame.id,
                        showStickerBook: true,
                        showCoins: true,
                        onExit: {
                            saveCurrent()
                            exit()
                        },
                        onStickerBook: {
                            saveCurrent()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showBook = true
                            }
                        },
                        trailing: {
                            HStack(spacing: 12) {
                                RoundButton(
                                    symbol: "person.crop.circle.badge.plus",
                                    tint: Color(hex: 0x9B79E0),
                                    size: GameChromeLayout.buttonSize
                                ) {
                                    switchToNewClient()
                                }
                                .accessibilityLabel("New Client")

                                RoundButton(
                                    symbol: "camera.fill",
                                    tint: Theme.pink,
                                    size: GameChromeLayout.buttonSize
                                ) {
                                    snap()
                                }
                                .accessibilityLabel("Take Photo")

                                ZStack(alignment: .topTrailing) {
                                    RoundButton(
                                        symbol: "photo.on.rectangle.angled",
                                        tint: Color(hex: 0x46B7B0),
                                        size: GameChromeLayout.buttonSize
                                    ) {
                                        Sound.shared.play(.pop)
                                        Sound.shared.tap()
                                        withAnimation(.easeInOut(duration: 0.3)) { showPhotos = true }
                                    }
                                    .accessibilityLabel("Photo Wall")

                                    if !store.photos.isEmpty {
                                        Text("\(store.photos.count)")
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.white)
                                            .frame(minWidth: 26, minHeight: 26)
                                            .background(Circle().fill(Theme.pink))
                                            .overlay(Circle().stroke(.white, lineWidth: 2))
                                            .offset(x: 6, y: -5)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        }
                    )

                    if burstID > 0 {
                        SparkleBurst(colors: [.white, Theme.lemon, Theme.pink, Theme.lilac], count: 16, radius: 240)
                            .id(burstID)
                            .position(world.toDesign(HairV(300, 300)))
                    }

                    Color.white.opacity(flash).allowsHitTesting(false)

                    StickerToast(game: SalonGame.id, target: GameChromeLayout.stickerTarget)
                }
                .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                .coordinateSpace(name: "salon")
                .coinPurse(game: SalonGame.id)
                .onAppear {
                    world.centerX = SalonWorld.defaultCenterX
                    _ = SalonSound.shared
                    applyLaunchArguments()
                }
            }

            if showPhotos {
                SalonPhotoWall(
                    store: store,
                    onPick: { v in
                        SalonSound.shared.play(.chime, volume: 0.6)
                        backupStyledClientIfNeeded()
                        saveCurrent()
                        world.load(v)
                        hat = world.hat
                        withAnimation(.easeInOut(duration: 0.3)) { showPhotos = false }
                    },
                    onDelete: { id in
                        Sound.shared.play(.whoosh, volume: 0.45)
                        Sound.shared.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            store.deletePhoto(id: id)
                        }
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.3)) { showPhotos = false }
                    }
                )
                .transition(.opacity)
                .zIndex(4)
            }

            if showBook {
                StickerBookView(game: SalonGame.id) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .onDisappear { saveCurrent() }
        .onReceive(autosave) { _ in
            if world.changed {
                world.changed = false
                saveCurrent()
            }
        }
        .onChange(of: phase) { p in if p != .active { saveCurrent() } }
    }

    private func saveCurrent() {
        SalonStore.saveCurrent(world.visit(positions: true))
    }

    /// Auto-saves an edited client to the photo wall before switching away so no hairstyle is ever lost.
    private func backupStyledClientIfNeeded() {
        if world.hasBeenStyled && !world.savedSinceStyle {
            store.addPhoto(world.visit(positions: true))
            world.markSavedToWall()
        }
    }

    private func switchToNewClient() {
        SalonSound.shared.play(.chime, volume: 0.6)
        Sound.shared.play(.whoosh, volume: 0.5)
        Sound.shared.tap()
        backupStyledClientIfNeeded()
        saveCurrent()
        world.newClient()
        hat = nil
        saveCurrent()
    }

    private func isOverReturnDrop(finger p: CGPoint) -> Bool {
        let badge = SalonView.returnDropPoint
        if hypot(p.x - badge.x, p.y - badge.y) < 76 { return true }
        if let item = world.draggedItemDesignPoint, hypot(item.x - badge.x, item.y - badge.y) < 76 { return true }
        return false
    }

    private func isOverRightTray(_ p: CGPoint) -> Bool {
        guard let t = tool, t.hasTray else { return false }
        return p.x >= GameChromeLayout.width - SalonView.trayWidth - 14
    }

    // MARK: Stage

    private var stage: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: showPhotos || showBook)) { tl in
            Canvas { ctx, s in
                world.frame(at: tl.date)
                world.draw(ctx, size: s, now: tl.date)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("salon"))
                .onChanged { v in
                    if auto.running { auto.cancel() }
                    if world.finger == nil { world.press(v.location) } else { world.move(v.location) }
                    let dragging = world.isDraggingFromHair
                    if dragging != draggingFromHair {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            draggingFromHair = dragging
                        }
                    }
                    let hovered = dragging && (isOverReturnDrop(finger: v.location) || isOverRightTray(v.location))
                    if hovered != overReturnBadge {
                        overReturnBadge = hovered
                    }
                }
                .onEnded { v in
                    let wasTap = ToolTap.isTap(v.translation)
                    let discard = draggingFromHair && (isOverReturnDrop(finger: v.location) || isOverRightTray(v.location))
                    world.release(discarding: discard)
                    if draggingFromHair || overReturnBadge {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            draggingFromHair = false
                            overReturnBadge = false
                        }
                    }
                    if let t = tool, t != .clips, wasTap {
                        if t == .scissors {
                            world.tapSnip(at: v.location)
                        } else {
                            autoDo(at: v.location)
                        }
                    }
                }
        )
    }

    /// The picked tool does the spot she tapped by itself: a little rub there, through the same hands.
    private func autoDo(at spot: CGPoint) {
        let f = world.fingerFor(tip: spot)
        let w = world
        auto.run(from: CGPoint(x: f.x + 70, y: f.y + 90), to: f,
                 step: { q in if w.finger == nil { w.press(q) } else { w.move(q) } },
                 end: { _ in w.release() })
    }

    // MARK: Turning the chair

    /// Arrows on each side of the chair base spin her around, so she can do the back and sides too.
    private var turnButtons: some View {
        let y = min(GameChromeLayout.height - 52, world.floorDesign - 24)
        return ZStack {
            RoundButton(symbol: "arrow.counterclockwise", tint: Color(hex: 0x9B79E0), size: 74) {
                Sound.shared.tap()
                world.turn(-1)
            }
            .position(x: world.centerX - 200, y: y)
            RoundButton(symbol: "arrow.clockwise", tint: Color(hex: 0x9B79E0), size: 74) {
                Sound.shared.tap()
                world.turn(1)
            }
            .position(x: world.centerX + 200, y: y)
        }
    }

    // MARK: Camera snap

    private func snap() {
        SalonSound.shared.play(.shutter, volume: 0.8)
        Sound.shared.play(.sparkle, volume: 0.6)
        Sound.shared.tap()
        world.cheer()
        store.addPhoto(world.visit(positions: true))
        world.markSavedToWall()
        SalonFind.salonStar.unlock()
        if world.consumeCoinReward() {
            Coins.shared.earn(4, game: SalonGame.id, from: CGPoint(x: 512, y: 360))
        }
        burstID += 1
        flash = 0.9
        withAnimation(.easeOut(duration: 0.5)) { flash = 0 }
    }

    // MARK: Tool shelf

    private var naturalHairColor: RGB {
        SalonWorld.hairPalette[safe: world.look.hair] ?? RGB(0.42, 0.27, 0.2)
    }

    private var shelf: some View {
        let tools = SalonTool.allCases
        return GameTrayCard(cornerRadius: 28, paddingH: 10, paddingV: 10) {
            VStack(spacing: 10) {
                ForEach(0..<(tools.count + 1) / 2, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(tools[(row * 2)..<min(tools.count, row * 2 + 2)]) { t in
                            toolButton(t)
                        }
                    }
                }
            }
        }
    }

    private func toolButton(_ t: SalonTool) -> some View {
        let on = tool == t
        let isRainbowDye = t == .dye && dye == SalonWorld.rainbowIndex
        let brushColor = SalonView.swatch(dye, natural: naturalHairColor)
        return GameDockTile(size: 86, selected: on, tint: .white, cornerRadius: 22) {
            SalonToolPicture(tool: t, dye: brushColor, rainbow: isRainbowDye, open: 0.6)
                .padding(8)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("salon"))
                .onChanged { v in
                    if pressStart == nil {
                        pressStart = (t, tool == t)
                        if tool != t { select(t) }
                    }
                    // dragging a tool off the shelf uses it straight away
                    if v.location.x > SalonView.shelfRight + 10 {
                        if world.finger == nil { world.press(v.location) } else { world.move(v.location) }
                    }
                }
                .onEnded { v in
                    let start = pressStart
                    pressStart = nil
                    if world.finger != nil { world.release(); return }
                    let tapped = abs(v.translation.width) < 12 && abs(v.translation.height) < 12
                    if tapped, let s = start, s.wasSelected, s.tool == t { select(nil) }
                }
        )
    }

    private func select(_ t: SalonTool?) {
        Sound.shared.play(.pop, volume: 0.6)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tool = t }
        world.tool = t
        world.dyeColor = dye
        world.glitterColor = glitter
    }

    // MARK: Trays

    static func swatch(_ i: Int, natural: RGB = RGB(0.42, 0.27, 0.2)) -> RGB {
        if i < SalonWorld.dyeColors.count { return SalonWorld.dyeColors[i] }
        if i == SalonWorld.naturalIndex { return natural }
        return SalonWorld.dyeColors[0]
    }

    @ViewBuilder
    private func tray(_ t: SalonTool) -> some View {
        GameTrayCard(cornerRadius: 28, paddingH: 12, paddingV: 12) {
            VStack(spacing: 10) {
                switch t {
                case .dye: dyeTray
                case .glitter: glitterTray
                default: clipTray
                }
            }
            .frame(width: SalonView.trayWidth - 24)
        }
    }

    private var dyeTray: some View {
        let n = SalonWorld.dyeColors.count + 2
        let cols = Array(repeating: GridItem(.fixed(68), spacing: 10), count: 3)
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(0..<n, id: \.self) { i in
                Button {
                    dye = i
                    world.dyeColor = i
                    Sound.shared.play(.pop, volume: 0.5)
                    Sound.shared.tap()
                } label: {
                    DyeSwatch(index: i, natural: naturalHairColor, on: dye == i)
                        .frame(width: 68, height: 68)
                }
                .buttonStyle(Squish())
            }
        }
    }

    private var glitterTray: some View {
        let cols = Array(repeating: GridItem(.fixed(96), spacing: 12), count: 2)
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(0..<SalonWorld.glitterColors.count, id: \.self) { i in
                Button {
                    glitter = i
                    world.glitterColor = i
                    Sound.shared.play(.sparkle, volume: 0.4)
                    Sound.shared.tap()
                } label: {
                    GlitterSwatch(color: SalonWorld.glitterColors[i], on: glitter == i)
                        .frame(width: 96, height: 96)
                }
                .buttonStyle(Squish())
            }
        }
    }

    static let clipChoices: [SalonCarry] = [
        .clip(.bow, 4), .clip(.bow, 16), .clip(.ribbon, 19), .clip(.flower, 3), .clip(.daisy, 0), .clip(.star, 9),
        .clip(.heart, 5), .clip(.butterfly, 15), .clip(.pearl, 0), .scrunchie(3), .scrunchie(18), .scrunchie(11),
    ]

    static let hats = ["h_crown", "h_tiara", "h_bigbow", "h_twobows", "h_flowers", "h_headband",
                       "h_unicorn", "h_cat", "h_bunny", "h_starcrown", "h_halo", "h_sunflower"]

    private var clipTray: some View {
        let cols = Array(repeating: GridItem(.fixed(68), spacing: 10), count: 3)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(0..<SalonView.clipChoices.count, id: \.self) { i in
                        clipChoice(SalonView.clipChoices[i])
                    }
                }
                Capsule().fill(Theme.pink.opacity(0.32)).frame(width: 170, height: 5)
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(SalonView.hats, id: \.self) { h in
                        Button {
                            Sound.shared.play(.pop, volume: 0.6)
                            Sound.shared.play(.sparkle, volume: 0.3)
                            Sound.shared.tap()
                            world.wearHat(h)
                            hat = world.hat
                            world.sparkle(at: HairV(300, 170), count: 6)
                        } label: {
                            ItemThumb(item: h, look: world.look)
                                .padding(6)
                                .frame(width: 68, height: 68)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(hat == h ? Theme.blush : .white))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(hat == h ? Theme.pink : Theme.blush, lineWidth: hat == h ? 4 : 2.2))
                        }
                        .buttonStyle(Squish())
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollDisabled(carryingFromTray)
        .frame(maxHeight: 656)
    }

    private func clipChoice(_ c: SalonCarry) -> some View {
        Button {
            guard Date() > suppressClipTapUntil else { return }
            Sound.shared.play(.pop, volume: 0.5)
            Sound.shared.tap()
            placeForHer(c)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white)
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    g.scaleBy(x: 1.05, y: 1.05)
                    switch c {
                    case .clip(let kind, let color): ClipPainter.draw(kind, color: color, in: g)
                    case .scrunchie(let color):
                        g.scaleBy(x: 1.3, y: 1.3)
                        ClipPainter.drawScrunchie(color: color, in: g)
                    }
                }
            }
            .frame(width: 68, height: 68)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.blush, lineWidth: 2.2))
        }
        .buttonStyle(Squish())
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .named("salon"))
                .onChanged { v in
                    if world.carry == nil {
                        let pullingLeft = v.translation.width < -10 && abs(v.translation.width) >= abs(v.translation.height) * 0.65
                        let outsideTray = v.location.x < GameChromeLayout.width - SalonView.trayWidth - 6
                        guard pullingLeft || outsideTray else { return }
                        carryingFromTray = true
                        world.startCarry(c, at: v.location, fromHair: false, initialOffset: .zero)
                        Sound.shared.play(.pop, volume: 0.5)
                        Sound.shared.tap()
                    }
                    world.moveCarry(to: v.location)
                }
                .onEnded { v in
                    guard carryingFromTray || world.carry != nil else { return }
                    carryingFromTray = false
                    suppressClipTapUntil = Date().addingTimeInterval(0.18)
                    if v.location.x < GameChromeLayout.width - SalonView.trayWidth - 14 {
                        world.dropCarry(at: v.location)
                    } else {
                        world.cancelCarry()
                    }
                }
        )
    }

    /// A tap on a clip puts it somewhere pretty by itself.
    private func placeForHer(_ c: SalonCarry) {
        switch c {
        case .clip:
            let spots: [HairV] = [HairV(392, 196), HairV(208, 196), HairV(300, 160), HairV(432, 290), HairV(168, 290),
                                  HairV(350, 170), HairV(250, 170), HairV(440, 360), HairV(160, 360)]
            for s in spots.shuffled() {
                let taken = world.sim.clips.contains { cl in world.sim.clipPosition(cl).map { $0.dist(s) < 30 } ?? false }
                if taken { continue }
                world.carry = c
                world.carryPoint = nil
                world.dropCarry(at: SalonWorld.carrying(to: world.toDesign(s)))
                return
            }
            world.carry = c
            world.carryPoint = nil
            world.dropCarry(at: SalonWorld.carrying(to: world.toDesign(HairV(300, 170))))
        case .scrunchie(let color):
            sideTie += 1
            let left = sideTie % 2 == 1
            let ys: [CGFloat] = [400, 440, 360, 480, 520]
            for y in ys where world.tryTie(at: HairV(left ? 168 : 432, y), color: color) { return }
            for y in ys where world.tryTie(at: HairV(left ? 432 : 168, y), color: color) { return }
        }
    }

    // MARK: Screenshot hooks

    /// `-salonDemo wash | dry | cut | curl | style | photos` sets up a moment for simulator screenshots.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-salonDemo"), i + 1 < args.count else { return }
        Coins.shared.demo = true
        StickerBook.shared.demo = true
        let name = args[i + 1]
        if name == "photos" {
            for k in 0..<6 {
                let w = SalonWorld(visit: nil)
                SalonDemo.style(w, variant: k)
                store.addPhoto(w.visit(positions: true))
            }
            showPhotos = true
            return
        }
        let t = SalonDemo.run(name, in: world)
        tool = t
        hat = world.hat
        if t == .dye { dye = SalonWorld.rainbowIndex }
    }
}

// MARK: - Swatches

private struct DyeSwatch: View {
    let index: Int
    let natural: RGB
    let on: Bool

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6)
            let blob = Path(ellipseIn: r)
            if index == SalonWorld.rainbowIndex {
                ctx.fill(blob, with: .conicGradient(Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red]),
                                                    center: CGPoint(x: r.midX, y: r.midY)))
                ctx.stroke(blob, with: .color(.white), lineWidth: 3)
            } else {
                let c = SalonView.swatch(index, natural: natural)
                ctx.fill(blob, with: .color(c.color))
                ctx.stroke(blob, with: .color(Shades.outline(c).color), lineWidth: 3)
                if index == SalonWorld.naturalIndex {
                    // a little leaf: "your own color"
                    var g = ctx
                    g.translateBy(x: r.midX, y: r.midY)
                    g.scaleBy(x: 0.9, y: 0.9)
                    ClipPainter.draw(.leaf, color: 0, in: g)
                }
            }
            var s = ctx
            s.opacity = 0.6
            s.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.15, width: r.width * 0.3, height: r.height * 0.2)),
                   with: .color(.white))
            if on {
                ctx.stroke(Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)), with: .color(Theme.pink), lineWidth: 4)
            }
        }
    }
}

private struct GlitterSwatch: View {
    let color: RGB
    let on: Bool

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
            let jar = Path(roundedRect: r, cornerRadius: 22, style: .continuous)
            ctx.fill(jar, with: .color(.white))
            for i in 0..<18 {
                let x = r.minX + 10 + CGFloat((i * 37) % 60)
                let y = r.minY + 12 + CGFloat((i * 53) % 56)
                let s: CGFloat = i % 3 == 0 ? 7 : 4
                ctx.fill(ClipPainter.star(s, points: 4, inner: 0.35).applying(CGAffineTransform(translationX: x, y: y)),
                         with: .color((i % 2 == 0 ? color : color.mix(Shades.white, 0.5)).color))
            }
            ctx.stroke(jar, with: .color(on ? Theme.pink : Theme.blush), lineWidth: on ? 5 : 2.5)
        }
    }
}

// MARK: - Photo wall

private struct SalonPhotoWall: View {
    @ObservedObject var store: SalonStore
    let onPick: (SalonVisit) -> Void
    let onDelete: (UUID) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.35).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            DesignCanvas {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        RoundButton(symbol: "xmark", tint: Theme.pink) {
                            Sound.shared.play(.whoosh, volume: 0.5)
                            onClose()
                        }
                        .accessibilityLabel("Close")
                    }
                    if store.photos.isEmpty {
                        Spacer()
                        Image(systemName: "camera.fill")
                            .font(.system(size: 90, weight: .bold))
                            .foregroundStyle(Theme.pink.opacity(0.5))
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(150), spacing: 18), count: 5), spacing: 20) {
                                ForEach(store.photos) { v in
                                    ZStack(alignment: .topTrailing) {
                                        Button {
                                            onPick(v)
                                        } label: {
                                            SalonPortraitView(visit: v)
                                                .frame(width: 150, height: 175)
                                                .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                    .fill(LinearGradient(colors: [Color(hex: 0xFFF1F8), Color(hex: 0xEDE4FF)], startPoint: .top, endPoint: .bottom)))
                                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white, lineWidth: 6))
                                                .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
                                        }
                                        .buttonStyle(Squish())

                                        Button {
                                            onDelete(v.id)
                                        } label: {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 34, height: 34)
                                                .background(Circle().fill(Color(hex: 0xF06A8E)))
                                                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                                                .shadow(color: Theme.ink.opacity(0.22), radius: 3, y: 2)
                                        }
                                        .buttonStyle(Squish())
                                        .accessibilityLabel("Delete Photo")
                                        .offset(x: 8, y: -8)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding(26)
                .frame(width: 900, height: 700)
                .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Theme.cream))
                .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(.white, lineWidth: 8))
            }
        }
    }
}
