import SwiftUI

// MARK: - Ice Cream & Smoothie Shop (a game in the drawer)
//
// An ice cream parlor with a serving window. Animal customers come to the window dreaming of one treat (the picture
// card above them) and she makes it at three stations: the scoop cabinet (dig the dipper through a tub until the
// ball is big, drop it on a cone), the soft-serve machine (hold a handle and the swirl coils up as the stand turns)
// and the smoothie bar (fruit and ice into the blender, hold the button, then carry the jar to the glass and it
// pours). Toppings from the shelf at the bottom: shake the sprinkles, squeeze sauce that runs down, whipped cream,
// a cherry, a wafer, a straw. Ring the bell to serve. Nothing to read, no voice, nothing locked.
//
// Code: IceCreamSim (+ Soft, Blender) is the simulation, IceCreamBuild what's on the stand, IceCreamScene and
// IceCreamTreatArt the drawing, this file the screen. Sounds: tools/icecream/sounds.py. Saves: shop.json.
// The customers are the Bakery's animals (its art file), so the two shops share their regulars.

enum IceCreamGame {
    static let entry = GameEntry(
        id: IceSim.gameID,
        title: "Ice Cream",
        tint: Color(hex: 0xFFB8D6),
        icon: { AnyView(IceTileIcon()) },
        play: { exit in AnyView(IceCreamView(exit: exit)) }
    )
}

private struct IceTileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let k = size.width / 300
            g.scaleBy(x: k, y: k)
            var cone = ICBuild()
            cone.base = .waffle
            cone.scoops = [ICScoop(id: 1, flavor: .strawberry, swirl: nil, r: 44, dx: 0, h: 26),
                           ICScoop(id: 2, flavor: .mint, swirl: nil, r: 40, dx: 4, h: 84)]
            cone.cherry = ICBody(dx: 6, h: 132, vx: 0, vh: 0, resting: true)
            var a = g
            a.translateBy(x: 112, y: 150)
            a.scaleBy(x: 0.82, y: 0.82)
            ICArt.drawBuild(a, cone, at: .zero, time: 0)
            var glass = ICBuild()
            glass.base = .glass
            glass.layers = [ICLayer(top: 0.5, color: ICColor(0xFFAA2E)), ICLayer(top: 0.9, color: ICColor(0xEE6A8C))]
            glass.straw = ICStick(dx: 14, h: -118, angle: 0.22)
            var b = g
            b.translateBy(x: 216, y: 150)
            b.scaleBy(x: 0.62, y: 0.62)
            ICArt.drawBuild(b, glass, at: .zero, time: 0)
        }
    }
}

// MARK: - The screen

final class IceHand {
    enum Mode { case none, held, lever, blend, tickle, bin(Int) }
    var mode: Mode = .none
    var active = false
    var startAt = Date()
    var start = CGPoint.zero
    /// The lifted thing's offset from her finger, eased so it glides up instead of jumping.
    var offset = CGSize.zero
}

private struct ICDockPlate: View, Equatable {
    let topping: ICTopping?
    let open: Bool
    let wanted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white.opacity(0.94))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(open ? Theme.pink : Color.white, lineWidth: 5))
                .shadow(color: Theme.ink.opacity(0.22), radius: 7, y: 5)
            Canvas { ctx, size in
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                if let t = topping {
                    switch t {
                    case .cherry:
                        g.translateBy(x: 0, y: 10)
                        ICScene.topping(g, t, held: false)
                    case .wafer:
                        g.translateBy(x: 0, y: 2)
                        g.scaleBy(x: 0.8, y: 0.8)
                        ICScene.topping(g, t, held: false)
                    case .straw:
                        g.translateBy(x: -8, y: 4)
                        g.scaleBy(x: 0.48, y: 0.48)
                        ICScene.topping(g, t, held: false)
                    default:
                        g.translateBy(x: 0, y: 40)
                        g.scaleBy(x: 0.52, y: 0.52)
                        ICScene.topping(g, t, held: false)
                    }
                } else {
                    // the cones-and-cups button
                    var b = ICBuild()
                    b.base = .waffle
                    var c = g
                    c.translateBy(x: -12, y: -26)
                    c.scaleBy(x: 0.4, y: 0.4)
                    ICArt.drawBuild(c, b, at: .zero, time: 0)
                    var cup = ICBuild()
                    cup.base = .cup
                    var d = g
                    d.translateBy(x: 16, y: 4)
                    d.scaleBy(x: 0.36, y: 0.36)
                    ICArt.drawBuild(d, cup, at: .zero, time: 0)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: 92, height: 92)
        .overlay(alignment: .topTrailing) {
            if wanted {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Theme.pink)
                    .padding(6)
                    .background(Circle().fill(.white))
                    .offset(x: 10, y: -10)
            }
        }
    }
}

struct IceCreamView: View {
    let exit: () -> Void

    private enum Phase { case arriving, waiting, eating, happy, leaving }

    @State private var sim = IceSim()
    @State private var station: ICStation = .scoop
    @State private var hand = IceHand()
    @State private var tray = false
    @State private var order = ICOrder.random(customer: Int.random(in: 0..<BakeryPalette.customers.count))
    @State private var picture = ICBuild()
    @State private var phase: Phase = .arriving
    @State private var custX: CGFloat = 520
    @State private var eyes = "open"
    @State private var mouth = "smile"
    @State private var bob = false
    @State private var stars: Int?
    @State private var hearts = 0
    @State private var floating = 0
    @State private var jarBounce = false
    @State private var carrying: ICTopping?
    @State private var started = false
    @State private var demoServe = false
    /// A quick tap in a tub: the dipper scoops a ball there by itself and puts it on the treat (see `ToolTap`).
    @State private var auto = AutoTool()

    static let toppings: [ICTopping] = ICTopping.allCases

    var body: some View {
        GeometryReader { geo in
            let map = ICMap(size: geo.size)
            ZStack {
                Canvas(opaque: true) { ctx, _ in
                    ICScene.drawBackdrop(ctx, map: map, station: station)
                }
                .allowsHitTesting(false)
                customerLayer
                    .frame(width: 1024, height: 834)
                    .scaleEffect(map.s)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .allowsHitTesting(false)
                // Everything that moves, capped at 60 fps so 120 Hz screens do not double the work.
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
                    Canvas { ctx, _ in
                        sim.step(tl.date)
                        ICScene.draw(ctx, map: map, sim: sim)
                    }
                }
                .contentShape(Rectangle())
                .gesture(handGesture(map))
                controls(map)
                    .frame(width: 1024, height: 834)
                    .scaleEffect(map.s)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .coordinateSpace(name: "ice")
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onDisappear { IceSound.shared.stopLoops() }
        .task { await blinkLoop() }
    }

    private func start() {
        guard !started else { return }
        started = true
        _ = IceSound.shared
        hearts = sim.store.hearts
        picture = order.picture()
        applyLaunchArguments()
        if !demoServe { arrive() }
    }

    // MARK: Her hand on the shop

    private func handGesture(_ map: ICMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("ice"))
            .onChanged { v in
                let p = map.design(v.location)
                if !hand.active {
                    hand.active = true
                    began(p)
                } else {
                    moved(p)
                }
            }
            .onEnded { v in
                let p = map.design(v.location)
                let dist = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                let tap = dist < 14 && Date().timeIntervalSince(hand.startAt) < 0.4
                ended(p, tap: tap)
                hand.active = false
            }
    }

    private func began(_ p: CGPoint) {
        if auto.running { auto.cancel() }
        hand.startAt = Date()
        hand.start = p
        tray = false
        switch sim.station {
        case .scoop:
            let cabinet = CGRect(x: 20, y: 370, width: 490, height: 300)
            if cabinet.contains(p) {
                grab(.scoop, at: p, from: ICGeo.well)
                return
            }
        case .soft:
            // the big flavor buttons: anywhere on one (and a little round it) works
            for (i, c) in ICGeo.softButtons.enumerated() where hypot(p.x - c.x, p.y - c.y) < ICGeo.softButtonR + 12 {
                hand.mode = .lever
                sim.pressLever(i)
                return
            }
        case .smoothie:
            if hypot(p.x - ICGeo.blendButton.x, p.y - ICGeo.blendButton.y) < 40 && sim.jarOnBase {
                hand.mode = .blend
                sim.blending = true
                Sound.shared.tap()
                IceSound.shared.play(.lever, volume: 0.5, rate: 1.3)
                return
            }
            if hypot(p.x - ICGeo.milkHome.x, p.y - ICGeo.milkHome.y) < 54 {
                grab(.milk, at: p, from: ICGeo.milkHome)
                return
            }
            for (i, c) in ICGeo.bins.enumerated() where abs(p.x - c.x) < 40 && p.y > c.y - 40 && p.y < c.y + 40 {
                hand.mode = .bin(i)
                Sound.shared.tap()
                return
            }
            let jp = sim.jarP
            if sim.jarOnBase && p.x > jp.x - 140 && p.x < jp.x + 100 && p.y > jp.y - ICGeo.jarH - 10 && p.y < jp.y + 10 {
                grab(.jar, at: p, from: CGPoint(x: jp.x, y: jp.y - ICGeo.jarH / 2))
                return
            }
        }
        if ICGeo.window.contains(p) {
            hand.mode = .tickle
            tickle()
            return
        }
        hand.mode = .none
    }

    private func grab(_ h: ICHeld, at p: CGPoint, from home: CGPoint) {
        hand.mode = .held
        hand.offset = CGSize(width: home.x - p.x, height: home.y - p.y)
        Sound.shared.tap()
        sim.pickUp(h, at: p)
        moved(p)
    }

    private func moved(_ p: CGPoint) {
        switch hand.mode {
        case .held:
            guard let h = sim.held else { return }
            let target = IceCreamView.lifted(p, h)
            hand.offset = FingerLift.ease(hand.offset, toward: CGSize(width: target.x - p.x, height: target.y - p.y))
            sim.carry(to: CGPoint(x: p.x + hand.offset.width, y: p.y + hand.offset.height), finger: p)
        case .bin(let i):
            if hypot(p.x - hand.start.x, p.y - hand.start.y) > 12 {
                grab(.fruit(ICFruit.allCases[i]), at: p, from: ICGeo.bins[i])
            }
        default:
            break
        }
    }

    private func ended(_ p: CGPoint, tap: Bool) {
        switch hand.mode {
        case .held:
            if tap, case .scoop? = sim.held { autoScoop(at: p) } else { sim.release() }
        case .lever: sim.pressLever(nil)
        case .blend:
            sim.blending = false
        case .bin(let i):
            if tap { sim.tossFruit(ICFruit.allCases[i]) }
        default: break
        }
        hand.mode = .none
    }

    /// The dipper rubs round in the tub she tapped until it has a ball, then carries it over the treat and
    /// lets it drop on (or back to its well when there's no cone yet).
    private func autoScoop(at p: CGPoint) {
        let s = sim
        let a = auto
        a.run(from: p, to: p, step: { q in s.carry(to: q, finger: q) }, end: { q in
            let over = CGPoint(x: s.S.x, y: s.S.y - 130)
            a.run(from: q, to: over, step: { r in s.carry(to: r, finger: r) }, end: { _ in s.release() })
        })
    }

    /// Where a held thing goes for her finger at p. The dipper works just ahead of her finger, held by its handle; pourers and carried things sit above.
    static func lifted(_ p: CGPoint, _ h: ICHeld) -> CGPoint {
        let lift: CGFloat
        switch h {
        case .scoop: lift = FingerLift.tool
        case .topping(let t):
            switch t {
            case .cherry, .wafer, .straw: lift = FingerLift.item
            default: lift = FingerLift.pour             // shakers, sauce bottles and the cream: it falls onto the treat
            }
        case .fruit: lift = FingerLift.item
        case .milk: lift = FingerLift.carry(below: 46)
        case .jar: lift = FingerLift.carry(below: ICGeo.jarH / 2 + 14)
        }
        return FingerLift.point(p, lift: lift, bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
    }

    // MARK: Controls

    private func controls(_ map: ICMap) -> some View {
        ZStack {
            HomeButton {
                IceSound.shared.stopLoops()
                exit()
            }
            .position(x: 62, y: 60)
            HStack(spacing: 16) {
                ForEach(ICStation.allCases, id: \.self) { s in
                    stationButton(s)
                }
            }
            .position(x: 316, y: 60)
            RoundButton(symbol: "arrow.counterclockwise", tint: Color(hex: 0x46B7B0), size: 64) {
                Sound.shared.play(.whoosh, volume: 0.6)
                sim.clearStand()
            }
            .position(x: 690, y: 60)
            heartJar.position(x: 960, y: 56)
            if phase == .waiting || phase == .happy {
                orderBubble
                    .position(x: 879, y: 164)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
            ForEach(0..<floating, id: \.self) { i in
                ICFloatingHeart(index: i).position(x: 879, y: 300)
            }
            dock(map)
            if tray { baseTray.transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
    }

    private func stationButton(_ s: ICStation) -> some View {
        let on = station == s
        let wantedHere = phase == .waiting && order.kind == kindFor(s)
        return Button {
            guard sim.held == nil else { return }
            Sound.shared.tap()
            Sound.shared.play(.pop, volume: 0.6)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { station = s }
            sim.setStation(s)
        } label: {
            ZStack {
                Circle().fill(.white)
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    var b = ICBuild()
                    switch s {
                    case .scoop:
                        b.base = .waffle
                        b.scoops = [ICScoop(id: 3, flavor: .strawberry, swirl: nil, r: 44, dx: 0, h: 26)]
                        g.translateBy(x: 0, y: -12)
                        g.scaleBy(x: 0.34, y: 0.34)
                    case .soft:
                        b.base = .waffle
                        b.rope = ICBuild.sampleSwirl(.twist, floor: -8)
                        g.translateBy(x: 0, y: -4)
                        g.scaleBy(x: 0.3, y: 0.3)
                    case .smoothie:
                        b.base = .glass
                        b.layers = [ICLayer(top: 0.85, color: ICColor(0xEE6A8C))]
                        b.straw = ICStick(dx: 14, h: -118, angle: 0.22)
                        g.translateBy(x: 0, y: -18)
                        g.scaleBy(x: 0.3, y: 0.3)
                    }
                    ICArt.drawBuild(g, b, at: .zero, time: 0)
                }
            }
            .frame(width: 78, height: 78)
            .overlay(Circle().stroke(on ? Theme.pink : Theme.pink.opacity(0.25), lineWidth: on ? 6 : 3))
            .scaleEffect(on ? 1.1 : 0.94)
            .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
            .overlay(alignment: .topTrailing) {
                if wantedHere && !on {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.pink)
                        .padding(5)
                        .background(Circle().fill(.white))
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(Squish())
    }

    private func kindFor(_ s: ICStation) -> ICKind {
        switch s {
        case .scoop: return .scoops
        case .soft: return .soft
        case .smoothie: return .smoothie
        }
    }

    private var heartJar: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "heart.fill")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(Theme.pink)
                .frame(width: 76, height: 76)
                .background(Circle().fill(.white))
                .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
            Text("\(hearts)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 2)
                .background(Capsule().fill(Color(hex: 0xF45C9A)))
                .offset(x: 10, y: 4)
        }
        .scaleEffect(jarBounce ? 1.3 : 1)
        .allowsHitTesting(false)
    }

    private var orderBubble: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white)
                .shadow(color: Theme.ink.opacity(0.22), radius: 8, y: 5)
            if phase == .happy, let s = stars {
                StarRating(filled: s, size: 50)
            } else {
                HStack(spacing: 4) {
                    ICPictureView(build: picture)
                        .equatable()
                        .frame(width: 112, height: 132)
                    ICOrderParts(order: order, sim: sim)
                        .frame(width: 92)
                }
            }
        }
        .frame(width: 228, height: 142)
        .scaleEffect(bob ? 1.03 : 0.98)
    }

    private func dock(_ map: ICMap) -> some View {
        ZStack {
            ICDockPlate(topping: nil, open: tray, wanted: phase == .waiting && sim.build.base != order.base)
                .equatable()
                .position(x: 78, y: ICGeo.dockY)
                .onTapGesture {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { tray.toggle() }
                }
            ForEach(Array(IceCreamView.toppings.enumerated()), id: \.offset) { i, t in
                let spot = CGPoint(x: 188 + CGFloat(i) * 98, y: ICGeo.dockY)
                ICDockPlate(topping: t, open: false, wanted: phase == .waiting && order.topping == t)
                    .equatable()
                    .opacity(carrying == t ? 0.35 : 1)
                    .gesture(toppingGesture(t, spot: spot, map: map))
                    .position(spot)
            }
            Button {
                serve()
            } label: {
                ZStack {
                    Circle().fill(Color(hex: 0xFFD84A))
                    Image(systemName: "bell.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 92, height: 92)
                .overlay(Circle().stroke(.white, lineWidth: 6))
                .shadow(color: Theme.ink.opacity(0.25), radius: 7, y: 5)
            }
            .buttonStyle(Squish())
            .scaleEffect(bob && phase == .waiting ? 1.1 : 1)
            .position(x: 950, y: ICGeo.dockY)
        }
    }

    private func toppingGesture(_ t: ICTopping, spot: CGPoint, map: ICMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("ice"))
            .onChanged { v in
                let p = map.design(v.location)
                if carrying == nil {
                    guard sim.held == nil else { return }
                    carrying = t
                    tray = false
                    sim.dockHome[t] = spot
                    hand.offset = CGSize(width: spot.x - p.x, height: spot.y - p.y)
                    Sound.shared.tap()
                    sim.pickUp(.topping(t), at: p)
                }
                guard carrying == t, let h = sim.held else { return }
                let target = IceCreamView.lifted(p, h)
                hand.offset = FingerLift.ease(hand.offset, toward: CGSize(width: target.x - p.x, height: target.y - p.y))
                sim.carry(to: CGPoint(x: p.x + hand.offset.width, y: p.y + hand.offset.height), finger: p)
            }
            .onEnded { v in
                guard carrying == t else { return }
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                if moved < 14 {
                    // a tap puts it on for her
                    sim.held = nil
                    sim.autoTopping(t)
                } else {
                    sim.release()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { if carrying == t { carrying = nil } }
            }
    }

    private var baseTray: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.95))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Theme.pink.opacity(0.5), lineWidth: 4))
                .shadow(color: Theme.ink.opacity(0.25), radius: 10, y: 6)
                .frame(width: 4 * 108 + 24, height: 150)
            HStack(spacing: 8) {
                ForEach(ICBase.allCases, id: \.self) { b in
                    Button {
                        Sound.shared.tap()
                        sim.placeBase(b)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tray = false }
                    } label: {
                        Canvas { ctx, size in
                            var g = ctx
                            var one = ICBuild()
                            one.base = b
                            let k: CGFloat = 0.62
                            g.translateBy(x: size.width / 2, y: size.height / 2 - b.depth * k * 0.5)
                            g.scaleBy(x: k, y: k)
                            ICArt.drawBuild(g, one, at: .zero, time: 0)
                        }
                        .frame(width: 100, height: 130)
                        .overlay(alignment: .topTrailing) {
                            if phase == .waiting && order.base == b {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(Theme.pink)
                            }
                        }
                    }
                    .buttonStyle(Squish())
                }
            }
        }
        .position(x: 280, y: 640)
    }

    // MARK: The customer

    private var customerLayer: some View {
        let name = BakeryPalette.customers[max(0, min(BakeryPalette.customers.count - 1, order.customer))]
        return ZStack {
            Sprite("cust_\(name)", box: Box.customer)
            Sprite("eyes_\(eyes)", box: Box.customer)
            Sprite("mouth_\(mouth)", box: Box.customer)
        }
        .frame(width: 400, height: 440)
        .scaleEffect(ICGeo.customerScale)
        .offset(y: bob ? -5 : 4)
        .position(x: ICGeo.customer.x + custX, y: ICGeo.customer.y + 20)
        .opacity(phase == .leaving && custX < -100 ? 0 : 1)
    }

    private func arrive() {
        custX = 420
        eyes = "open"
        mouth = "smile"
        stars = nil
        sim.order = order
        IceSound.shared.play(.door, volume: 0.7)
        withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) { custX = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { phase = .waiting }
            Sound.shared.play(.bubble, volume: 0.6)
        }
    }

    private func tickle() {
        guard phase == .waiting else { return }
        Sound.shared.play(.boing, volume: 0.7)
        Sound.shared.tap()
        eyes = "happy"
        mouth = "open"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if phase == .waiting { eyes = "open"; mouth = "smile" }
        }
    }

    private func serve() {
        IceSound.shared.play(.bell, volume: 0.8)
        Sound.shared.tap()
        guard phase == .waiting, sim.held == nil, let b = sim.serve() else { return }
        phase = .eating
        eyes = "happy"
        mouth = "open"
        for k in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(k) * 0.6) {
                IceSound.shared.play(b.kind == .smoothie ? .slurp : .nom)
                Sound.shared.tap()
                mouth = "chew"
                sim.bites = k
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { mouth = "open" }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            let s = order.stars(for: b)
            sim.served = nil
            sim.addHearts(s)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                stars = s
                phase = .happy
                hearts = sim.store.hearts
            }
            eyes = s == 3 ? "star" : "happy"
            mouth = "open"
            IceSound.shared.play(.yay)
            Sound.shared.play(s == 3 ? .fanfare : .cheer, volume: 0.7)
            floating = 2 + s * 2
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { jarBounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { jarBounce = false }
            }
            if !demoServe { DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { leave() } }
        }
    }

    private func leave() {
        withAnimation(.easeOut(duration: 0.25)) { phase = .leaving }
        floating = 0
        Sound.shared.play(.whoosh, volume: 0.5)
        withAnimation(.easeIn(duration: 0.6)) { custX = -700 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            var next = Int.random(in: 0..<BakeryPalette.customers.count)
            if next == order.customer { next = (next + 1) % BakeryPalette.customers.count }
            order = ICOrder.random(customer: next)
            picture = order.picture()
            phase = .arriving
            arrive()
        }
    }

    private func blinkLoop() async {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.2...4.2) * 1_000_000_000))
            if eyes == "open" {
                eyes = "blink"
                try? await Task.sleep(nanoseconds: 140_000_000)
                if eyes == "blink" { eyes = "open" }
            }
        }
    }

    // MARK: Screenshot hooks

    /// -iceDemo scoop | soft | blend | pour | sundae | serve. Freezes the shop mid-action; nothing is saved.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-iceDemo"), i + 1 < args.count else { return }
        sim.demo = true
        order = ICOrder.random(customer: 1, seed: 21)
        picture = order.picture()
        let what = args[i + 1]
        let dt: CGFloat = 1.0 / 60
        func run(_ seconds: CGFloat) { for _ in 0..<Int(seconds * 60) { sim.step(dt: dt) } }
        switch what {
        case "scoop":
            sim.placeBase(.waffle)
            sim.dropScoop(flavor: .strawberry, swirl: nil, size: 1, dx: 0, fromY: 300)
            run(1.2)
            let c = ICGeo.tubs[1]
            sim.pickUp(.scoop, at: CGPoint(x: c.x - 40, y: c.y))
            for k in 0..<50 {
                let a = CGFloat(k) / 50 * 2.6
                sim.carry(to: CGPoint(x: c.x - 40 + cos(a) * -30 + CGFloat(k) * 1.4, y: c.y + sin(a) * 10), finger: CGPoint(x: c.x, y: c.y + 120))
                sim.step(dt: dt)
            }
            sim.frozen = true
        case "soft":
            station = .soft
            sim.setStation(.soft)
            sim.placeBase(.waffle)
            run(0.6)
            sim.pressLever(2)
            run(2.6)
            sim.frozen = true
        case "blend", "pour":
            station = .smoothie
            sim.setStation(.smoothie)
            for f in [ICFruit.strawberry, .strawberry, .banana, .banana, .blueberry, .strawberry, .ice, .mango] {
                sim.dropFruit(f, at: CGPoint(x: sim.jarP.x + CGFloat.random(in: -30...30), y: sim.jarP.y - ICGeo.jarH - 40), v: CGVector(dx: 0, dy: 100))
                run(0.25)
            }
            sim.pickUp(.milk, at: ICGeo.milkHome)
            sim.carry(to: CGPoint(x: sim.jarP.x + 30, y: sim.jarP.y - ICGeo.jarH - 50), finger: CGPoint(x: sim.jarP.x + 30, y: 300))
            run(1.2)
            sim.release()
            run(0.5)
            sim.blending = true
            run(what == "blend" ? 1.6 : 6)
            if what == "pour" {
                sim.blending = false
                run(1.2)
                sim.pickUp(.jar, at: sim.jarP)
                let at = CGPoint(x: sim.S.x - 150, y: sim.S.y - 170)
                for _ in 0..<70 {
                    sim.carry(to: at, finger: CGPoint(x: at.x, y: at.y + 180))
                    sim.step(dt: dt)
                }
            }
            sim.frozen = true
        case "sundae":
            sim.placeBase(.choco)
            for (k, f) in [ICFlavor.chocolate, .vanilla, .strawberry].enumerated() {
                sim.dropScoop(flavor: f, swirl: k == 1 ? .blueberry : nil, size: 1 - CGFloat(k) * 0.15, dx: 0, fromY: 200)
                run(0.9)
            }
            sim.autoTopping(.chocoSauce)
            run(2.5)
            sim.autoTopping(.sprinkles)
            run(1.5)
            sim.autoTopping(.whip)
            sim.autoTopping(.cherry)
            sim.autoTopping(.wafer)
            run(2)
            sim.frozen = true
        case "serve":
            demoServe = true
            sim.placeBase(order.base)
            sim.autoTopping(.sprinkles)
            run(0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                phase = .waiting
                sim.order = order
                sim.build = order.picture()
                sim.build.picture = false
                serve()
            }
        default:
            break
        }
    }
}

// MARK: - Order card pieces

/// The dreamed-of treat, drawn once.
private struct ICPictureView: View, Equatable {
    let build: ICBuild

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let top = (build.profile.max() ?? 0) + (build.cherry != nil ? 30 : 0) + (build.straw != nil ? 40 : 0) + (build.wafer != nil ? 50 : 0)
            let depth = build.base?.depth ?? 120
            let total = max(120, top + depth + 20)
            let k = min(0.6, size.height / total)
            g.translateBy(x: size.width / 2, y: size.height - (depth + 14) * k)
            g.scaleBy(x: k, y: k)
            ICArt.drawBuild(g, build, at: .zero, time: 0)
        }
    }
}

/// The three parts of the order, each ticked green once the treat on the stand matches it.
private struct ICOrderParts: View {
    let order: ICOrder
    let sim: IceSim

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { _ in
            VStack(spacing: 6) {
                ForEach(Array(ICOrder.Part.allCases.enumerated()), id: \.offset) { _, part in
                    let ok = order.matches(part, sim.build)
                    ZStack {
                        Circle().fill(ok ? Color(hex: 0xD7F5DD) : Color(hex: 0xFFF1F6))
                        Canvas { ctx, size in
                            var g = ctx
                            g.translateBy(x: size.width / 2, y: size.height / 2)
                            ICOrderParts.icon(g, part, order)
                        }
                        if ok {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(Color(hex: 0x3EBE5E))
                                .background(Circle().fill(.white))
                                .offset(x: 14, y: -12)
                        }
                    }
                    .frame(width: 40, height: 40)
                }
            }
        }
    }

    static func icon(_ g: GraphicsContext, _ p: ICOrder.Part, _ o: ICOrder) {
        switch p {
        case .base:
            var b = ICBuild()
            b.base = o.base
            var c = g
            let k: CGFloat = o.base == .glass ? 0.2 : 0.22
            c.translateBy(x: 0, y: -o.base.depth * k * 0.5)
            c.scaleBy(x: k, y: k)
            ICArt.drawBuild(c, b, at: .zero, time: 0)
        case .flavor:
            let colors: [ICColor]
            switch o.kind {
            case .scoops: colors = o.flavors.map { (ICFlavor(rawValue: $0) ?? .vanilla).color }
            case .soft:
                let f = ICSoft(rawValue: o.flavors.first ?? 0) ?? .vanilla
                colors = f.colors.0 == f.colors.1 ? [f.colors.0] : [f.colors.0, f.colors.1]
            case .smoothie:
                for (i, f) in o.flavors.enumerated() {
                    let fr = ICFruit(rawValue: f) ?? .strawberry
                    let x = o.flavors.count == 1 ? 0 : (i == 0 ? -7 : 7)
                    ICArt.fruit(g, fr, at: CGPoint(x: CGFloat(x), y: 0), r: fr == .blueberry ? 8 : 10, rot: 0, seed: i)
                }
                return
            }
            for (i, c) in colors.enumerated() {
                let x: CGFloat = colors.count == 1 ? 0 : (i == 0 ? -6 : 6)
                let ball = ICArt.circle(CGPoint(x: x, y: 0), 10)
                ICArt.ballFill(g, ball, CGPoint(x: x, y: 0), 10, c)
                g.stroke(ball, with: .color(ICArt.outline(c)), lineWidth: 1.5)
            }
        case .topping:
            var c = g
            switch o.topping {
            case .cherry:
                c.translateBy(x: 0, y: 6)
                c.scaleBy(x: 0.8, y: 0.8)
            case .wafer:
                c.translateBy(x: 0, y: 14)
                c.scaleBy(x: 0.3, y: 0.3)
            case .straw:
                c.translateBy(x: -4, y: 14)
                c.scaleBy(x: 0.18, y: 0.18)
            default:
                c.translateBy(x: 0, y: 15)
                c.scaleBy(x: 0.2, y: 0.2)
            }
            ICScene.topping(c, o.topping, held: false)
        }
    }
}

private struct ICFloatingHeart: View {
    let index: Int
    @State private var go = false

    var body: some View {
        let dx = CGFloat((index * 37) % 120) - 60
        Image(systemName: "heart.fill")
            .font(.system(size: CGFloat(30 + (index % 3) * 8), weight: .black))
            .foregroundStyle(index % 2 == 0 ? Theme.pink : Color(hex: 0xFF6FA8))
            .offset(x: go ? dx * 1.4 : dx * 0.3, y: go ? -220 : 0)
            .opacity(go ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).delay(Double(index) * 0.12)) { go = true }
            }
    }
}
