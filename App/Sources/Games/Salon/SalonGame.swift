import SwiftUI

// MARK: - Hair Salon (a game in the drawer)
//
// A client sits in the salon chair with messy hair (sometimes with a leaf or a twig in it). She can
// wash it (shampoo foam and a shower), towel it, comb it, cut it (the pieces fall and pile up on the
// floor), blow-dry it, curl it, straighten it, dye it (14 colors, rainbow, or back to natural), add
// glitter, grow it back with a magic potion, and put in bows, clips, flowers, scrunchies (which
// gather the hair into ponytails) and the Dress Up hats and crowns. The camera puts the look on the
// photo wall (the last 30); tapping a photo brings that client back. Everything is open; no words.
//
// The hair is a physics simulation (SalonHair.swift); the client's face is the Dress Up art.
// Sounds: tools/salon/sounds.py -> App/Resources/Games/Salon/*.wav.

enum SalonGame {
    static let id = "salon"
    static let entry = GameEntry(
        id: id,
        title: "Salon",
        tint: Color(hex: 0xC9B6FF),
        icon: { AnyView(SalonTileIcon()) },
        play: { exit in AnyView(SalonView(exit: exit)) }
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

    /// Draws a client with her hair, standing still, into `ctx` (already in doll coordinates).
    static func paint(look: Look, sim: HairSim, cape: Int, in ctx: GraphicsContext) {
        SalonFurniture.drawChairBack(in: ctx)
        ClientPainter.draw(look, .normal, z: 0...9, in: ctx)
        HairPainter.drawBack(sim, in: ctx)
        ClientPainter.draw(look, .normal, z: 10...45, in: ctx)
        SalonFurniture.drawCape(color: ClipPainter.clipColor(cape), in: ctx)
        HairPainter.drawFront(sim, in: ctx)
        ClientPainter.draw(look, .normal, z: 46...200, in: ctx)
        ClipPainter.drawAll(sim, in: ctx)
        HairPainter.drawFlakes(sim, t: 0.3, in: ctx)
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

/// The drawer tile shows her latest client.
private struct SalonTileIcon: View {
    private static var cached: (key: String, look: Look, sim: HairSim, cape: Int)?

    var body: some View {
        let t = SalonTileIcon.current()
        Canvas { ctx, size in
            var g = ctx
            ArtPainter.fit(&g, box: CGRect(x: 96, y: 96, width: 408, height: 440), into: size)
            SalonPortrait.paint(look: t.look, sim: t.sim, cape: t.cape, in: g)
        }
        .padding(-16)
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
    @State private var flash = 0.0
    @State private var burstID = 0
    @State private var pressStart: (tool: SalonTool, wasSelected: Bool)?
    @State private var sideTie = 0
    @State private var size = CGSize(width: 1024, height: 834)
    @Environment(\.scenePhase) private var phase

    private let autosave = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    init(exit: @escaping () -> Void) {
        self.exit = exit
        let w = SalonWorld(visit: SalonStore.loadCurrent())
        _world = State(initialValue: w)
        _hat = State(initialValue: w.hat)
    }

    static let shelfRight: CGFloat = 236
    static let trayWidth: CGFloat = 272

    var body: some View {
        DesignCanvas {
            GeometryReader { geo in
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
                    .padding(.top, 100)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                    topBar
                    if burstID > 0 {
                        SparkleBurst(colors: [.white, Theme.lemon, Theme.pink, Theme.lilac], count: 16, radius: 240)
                            .id(burstID)
                            .position(world.toDesign(HairV(300, 300)))
                    }
                    Color.white.opacity(flash).allowsHitTesting(false)
                    if showPhotos {
                        SalonPhotoWall(store: store, onPick: { v in
                            SalonSound.shared.play(.chime, volume: 0.6)
                            saveCurrent()
                            world.load(v)
                            hat = world.hat
                            withAnimation(.easeInOut(duration: 0.3)) { showPhotos = false }
                        }, onClose: {
                            withAnimation(.easeInOut(duration: 0.3)) { showPhotos = false }
                        })
                        .transition(.opacity)
                    }
                }
                .coordinateSpace(name: "salon")
                .onAppear {
                    size = geo.size
                    world.centerX = geo.size.width / 2 - 25
                    _ = SalonSound.shared
                    applyLaunchArguments()
                }
                .onChange(of: geo.size) { s in
                    size = s
                    world.centerX = s.width / 2 - 25
                }
            }
        }
        .background(Color(hex: 0xF6DDF2).ignoresSafeArea())
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

    // MARK: Stage

    private var stage: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, s in
                world.frame(at: tl.date)
                world.draw(ctx, size: s, now: tl.date)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("salon"))
                .onChanged { v in
                    if world.finger == nil { world.press(v.location) } else { world.move(v.location) }
                }
                .onEnded { _ in world.release() }
        )
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack {
            HStack(spacing: 18) {
                HomeButton {
                    saveCurrent()
                    exit()
                }
                Spacer()
                RoundButton(symbol: "person.crop.circle.badge.plus", tint: Color(hex: 0x9B79E0)) {
                    SalonSound.shared.play(.chime, volume: 0.6)
                    Sound.shared.play(.whoosh, volume: 0.5)
                    Sound.shared.tap()
                    saveCurrent()
                    world.newClient()
                    hat = nil
                    saveCurrent()
                }
                RoundButton(symbol: "camera.fill", tint: Theme.pink) { snap() }
                ZStack(alignment: .topTrailing) {
                    RoundButton(symbol: "photo.on.rectangle.angled", tint: Color(hex: 0x46B7B0)) {
                        Sound.shared.play(.pop)
                        Sound.shared.tap()
                        withAnimation(.easeInOut(duration: 0.3)) { showPhotos = true }
                    }
                    if !store.photos.isEmpty {
                        Text("\(store.photos.count)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 30, minHeight: 30)
                            .background(Circle().fill(Theme.pink))
                            .offset(x: 8, y: -6)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            Spacer()
        }
    }

    private func snap() {
        SalonSound.shared.play(.shutter, volume: 0.8)
        Sound.shared.play(.sparkle, volume: 0.6)
        Sound.shared.tap()
        world.cheer()
        store.addPhoto(world.visit(positions: true))
        burstID += 1
        flash = 0.9
        withAnimation(.easeOut(duration: 0.5)) { flash = 0 }
    }

    // MARK: Tool shelf

    private var shelf: some View {
        let tools = SalonTool.allCases
        return VStack(spacing: 10) {
            ForEach(0..<(tools.count + 1) / 2, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(tools[(row * 2)..<min(tools.count, row * 2 + 2)]) { t in
                        toolButton(t)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white, lineWidth: 4))
    }

    private func toolButton(_ t: SalonTool) -> some View {
        let on = tool == t
        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(t.tint)
            SalonToolPicture(tool: t, dye: SalonView.swatch(dye), open: 0.6).padding(8)
        }
        .frame(width: 92, height: 92)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(on ? Theme.pink : .white, lineWidth: on ? 6 : 4))
        .shadow(color: on ? Theme.pink.opacity(0.5) : Theme.ink.opacity(0.14), radius: on ? 9 : 4, y: on ? 0 : 3)
        .scaleEffect(on ? 1.06 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: on)
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

    static func swatch(_ i: Int) -> RGB {
        if i < SalonWorld.dyeColors.count { return SalonWorld.dyeColors[i] }
        return RGB(1, 0.6, 0.8)
    }

    @ViewBuilder
    private func tray(_ t: SalonTool) -> some View {
        VStack(spacing: 10) {
            switch t {
            case .dye: dyeTray
            case .glitter: glitterTray
            default: clipTray
            }
        }
        .padding(12)
        .frame(width: SalonView.trayWidth)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.72)))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white, lineWidth: 4))
    }

    private var dyeTray: some View {
        let n = SalonWorld.dyeColors.count + 2
        let cols = Array(repeating: GridItem(.fixed(70), spacing: 12), count: 3)
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(0..<n, id: \.self) { i in
                Button {
                    dye = i
                    world.dyeColor = i
                    Sound.shared.play(.pop, volume: 0.5)
                    Sound.shared.tap()
                } label: {
                    DyeSwatch(index: i, natural: SalonWorld.hairPalette[safe: world.look.hair] ?? RGB(0.4, 0.3, 0.2), on: dye == i)
                        .frame(width: 70, height: 70)
                }
                .buttonStyle(Squish())
            }
        }
    }

    private var glitterTray: some View {
        let cols = Array(repeating: GridItem(.fixed(100), spacing: 14), count: 2)
        return LazyVGrid(columns: cols, spacing: 14) {
            ForEach(0..<SalonWorld.glitterColors.count, id: \.self) { i in
                Button {
                    glitter = i
                    world.glitterColor = i
                    Sound.shared.play(.sparkle, volume: 0.4)
                    Sound.shared.tap()
                } label: {
                    GlitterSwatch(color: SalonWorld.glitterColors[i], on: glitter == i)
                        .frame(width: 100, height: 100)
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
        let cols = Array(repeating: GridItem(.fixed(70), spacing: 10), count: 3)
        return VStack(spacing: 12) {
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<SalonView.clipChoices.count, id: \.self) { i in
                    clipChoice(SalonView.clipChoices[i])
                }
            }
            Capsule().fill(Theme.pink.opacity(0.3)).frame(width: 180, height: 5)
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
                            .frame(width: 70, height: 70)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(hat == h ? Theme.blush : .white))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(hat == h ? Theme.pink : Theme.pink.opacity(0.2), lineWidth: hat == h ? 4 : 2))
                    }
                    .buttonStyle(Squish())
                }
            }
        }
    }

    private func clipChoice(_ c: SalonCarry) -> some View {
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
        .frame(width: 70, height: 70)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.pink.opacity(0.2), lineWidth: 2))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("salon"))
                .onChanged { v in
                    if world.carry == nil {
                        world.carry = c
                        Sound.shared.play(.pop, volume: 0.5)
                        Sound.shared.tap()
                    }
                    world.carryPoint = v.location
                }
                .onEnded { v in
                    let tapped = abs(v.translation.width) < 12 && abs(v.translation.height) < 12
                    if tapped {
                        world.carry = nil
                        world.carryPoint = nil
                        placeForHer(c)
                    } else if v.location.x < size.width - SalonView.trayWidth - 20 {
                        world.dropCarry(at: v.location)
                    } else {
                        world.carry = nil
                        world.carryPoint = nil
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
                world.dropCarry(at: CGPoint(x: world.toDesign(s).x, y: world.toDesign(s).y + SalonWorld.carryLift))
                return
            }
            world.carry = c
            world.dropCarry(at: CGPoint(x: world.toDesign(HairV(300, 170)).x, y: world.toDesign(HairV(300, 170)).y + SalonWorld.carryLift))
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
                let c = index == SalonWorld.naturalIndex ? natural : SalonView.swatch(index)
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
                let x = r.minX + 10 + CGFloat((i * 37) % 64)
                let y = r.minY + 12 + CGFloat((i * 53) % 60)
                let s: CGFloat = i % 3 == 0 ? 7 : 4
                ctx.fill(ClipPainter.star(s, points: 4, inner: 0.35).applying(CGAffineTransform(translationX: x, y: y)),
                         with: .color((i % 2 == 0 ? color : color.mix(Shades.white, 0.5)).color))
            }
            ctx.stroke(jar, with: .color(on ? Theme.pink : Theme.pink.opacity(0.25)), lineWidth: on ? 5 : 2.5)
        }
    }
}

// MARK: - Photo wall

private struct SalonPhotoWall: View {
    @ObservedObject var store: SalonStore
    let onPick: (SalonVisit) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.35).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    RoundButton(symbol: "xmark", tint: Theme.pink) {
                        Sound.shared.play(.whoosh, volume: 0.5)
                        onClose()
                    }
                }
                if store.photos.isEmpty {
                    Spacer()
                    Image(systemName: "camera.fill")
                        .font(.system(size: 90, weight: .bold))
                        .foregroundStyle(Theme.pink.opacity(0.5))
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(150), spacing: 18), count: 5), spacing: 18) {
                            ForEach(store.photos) { v in
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
                            }
                        }
                        .padding(.vertical, 10)
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
