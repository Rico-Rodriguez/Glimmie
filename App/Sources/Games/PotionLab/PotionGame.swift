import AVFoundation
import SwiftUI

// MARK: - Potion Lab (a game in the drawer)
//
// A cozy magic lab with a big glass flask on a tripod over a little burner. She takes bottles off the left shelves
// (water, fairy nectar, mermaid water, dragon fire, moon milk, night sky) and pours them in: they tip over the
// mouth and pour once their liquid reaches it, in a stream that lands with a splash, sinks or floats by how heavy
// it is and marbles into the potion. Jars on the right (star sugar, rose petals, bubble berries, frost flakes,
// unicorn hair, lavender) are turned over and shaken: stars fizz and leave glitter, petals float, berries sink and
// pop into bubbles, frost cools it and spills cold fog over the rim, unicorn hair swirls a rainbow through it.
// The paddle in the flask stirs (the potion swirls and dips like a whirlpool), the knob turns the fire up until it
// boils and steams, the tap at the bottom drains it into the bucket. Empty bottles from the crate are dipped in to
// fill them (bubbles glug out), they get a cork and go on the rack, and a potion from the rack poured on the
// unicorn changes her: pink, glowing, sparkly, rainbow, floating in a bubble, hiccuping warm puffs, shivering,
// sleepy, or in love. Secret combos turn the potion into one of ten rare potions for the sticker book, and the
// light bulb shows a picture recipe for one she hasn't found yet.
//
// Code: PotionSim (simulation), PotionPaint (drawing), PotionModel (layout, ingredients, saves), PotionFinds
// (stickers), this file (screen). Sounds: tools/potion/sounds.py -> App/Resources/Games/PotionLab/*.wav.

enum PotionGame {
    static let entry = GameEntry(
        id: PotionSim.gameID,
        title: "Potions",
        tint: Color(hex: 0xC9A6FF),
        icon: { AnyView(PotionTileIcon()) },
        play: { exit in
            if PlaygroundLaunch.hasDemo(["-potionDemo"]) { return AnyView(PotionLabView(exit: exit)) }
            return AnyView(SpellTable(exit: exit))
        },
        stickers: PotionFind.stickers
    )
}

private struct PotionTileIcon: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = CGFloat(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000))
                var g = ctx
                let k = size.width / 300
                g.scaleBy(x: k, y: k)
                let b = PotionBottle(id: 1, r: 1, g: 0.42, b: 0.74, fill: 0.72, shape: PBottleShape.round.rawValue, kind: PotionKind.love.rawValue,
                                     magic: [:], glow: 0.5, sparkle: 0.8)
                PotionBottlePainter.draw(g, bottle: b, center: CGPoint(x: 150, y: 160), angle: sin(t * 1.2) * 0.08, scale: 2.0, time: t)
                var bubbles = Path()
                for i in 0..<4 {
                    let y = 80 - (t * 30 + CGFloat(i) * 22).truncatingRemainder(dividingBy: 80)
                    let r = 6 + CGFloat(i % 2) * 4
                    bubbles.addEllipse(in: CGRect(x: 150 + sin(t * 3 + CGFloat(i)) * 10 - r, y: y - r, width: r * 2, height: r * 2))
                }
                g.stroke(bubbles, with: .color(.white.opacity(0.9)), lineWidth: 3)
            }
        }
    }
}

// MARK: - Sounds

enum PotionSFX: String, CaseIterable {
    case glug, splash, plop, drip, tink, clink, cork, pop, bloop, fizz, frost, chime, magic, poof, heart, boing, hiccup
    case shakeOff, yawn, shake, knob, click, whoosh, gurgle, fill, tap
    case boil, sizzle, fire, stir
}

/// The lab's own effects and its looping boil, fizz, fire and stir, from App/Resources/Games/PotionLab.
final class PotionSound {
    static let shared = PotionSound()
    static let looping: Set<PotionSFX> = [.boil, .sizzle, .fire, .stir]
    private var players: [PotionSFX: [AVAudioPlayer]] = [:]
    private var loops: [PotionSFX: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "potion.sound", qos: .userInitiated)
    private var loopLevel: [PotionSFX: Float] = [:]
    private var loopSent: [PotionSFX: Float] = [:]

    private init() {
        _ = Sound.shared
        for s in PotionSFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "PotionLab") else { continue }
            if PotionSound.looping.contains(s) {
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.numberOfLoops = -1
                p?.volume = 0
                p?.prepareToPlay()
                loops[s] = p
            } else {
                players[s] = (0..<3).compactMap { _ in
                    let p = try? AVAudioPlayer(contentsOf: url)
                    p?.enableRate = true
                    p?.prepareToPlay()
                    return p
                }
            }
        }
    }

    func play(_ s: PotionSFX, volume: Float = 0.85) {
        guard let pool = players[s], !pool.isEmpty else { return }
        let v = volume * Float.random(in: 0.8...1)
        // a little variety in pitch for the watery ones
        let watery: Set<PotionSFX> = [.plop, .drip, .pop, .bloop, .splash, .glug, .tink, .clink]
        let rate: Float = watery.contains(s) ? Float.random(in: 0.88...1.15) : 1
        queue.async {
            let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            p.volume = v
            p.rate = rate
            p.currentTime = 0
            p.play()
        }
    }

    func setLoop(_ s: PotionSFX, volume: Float) {
        guard let p = loops[s] else { return }
        let old = loopLevel[s] ?? 0
        let v = old + (volume - old) * 0.1
        loopLevel[s] = v
        let sent = loopSent[s] ?? 0
        let on = v > 0.01
        guard abs(v - sent) > 0.01 || (on != (sent > 0.01)) else { return }
        loopSent[s] = on ? v : 0
        queue.async {
            p.volume = on ? v : 0
            if on {
                if !p.isPlaying { p.play() }
            } else if p.isPlaying {
                p.pause()
            }
        }
    }

    func stopLoops() {
        for s in loops.keys { loopLevel[s] = 0; loopSent[s] = 0 }
        let all = Array(loops.values)
        queue.async { for p in all { p.pause(); p.volume = 0 } }
    }
}

// MARK: - A scripted move (a tap makes a thing do its job by itself)

/// Plays a path of points into the game's drag handlers, like a ghost hand.
final class PotionScript {
    private var timer: Timer?
    private var legs: [(CGPoint, Double)] = []
    private var start = CGPoint.zero
    private var began = Date()
    private var step: ((CGPoint) -> Void)?
    private var end: (() -> Void)?
    var running: Bool { timer != nil }

    /// Moves from `from` through each point (reached after its duration), with a little wobble while holding still.
    func run(from: CGPoint, legs: [(CGPoint, Double)], step: @escaping (CGPoint) -> Void, end: @escaping () -> Void) {
        cancel()
        start = from
        self.legs = legs
        self.step = step
        self.end = end
        began = Date()
        step(from)
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func cancel() {
        guard let t = timer else { return }
        t.invalidate()
        timer = nil
        let e = end
        step = nil
        end = nil
        e?()
    }

    private func tick() {
        var a = Date().timeIntervalSince(began)
        var from = start
        for (to, dur) in legs {
            if a < dur {
                let k = CGFloat(a / dur)
                let e = k * k * (3 - 2 * k)
                var p = CGPoint(x: from.x + (to.x - from.x) * e, y: from.y + (to.y - from.y) * e)
                if hypot(to.x - from.x, to.y - from.y) < 2 {
                    // holding still: a little shake, like a hand
                    p.x += sin(CGFloat(a) * 22) * 7
                    p.y += cos(CGFloat(a) * 17) * 4
                }
                step?(p)
                return
            }
            a -= dur
            from = to
        }
        timer?.invalidate()
        timer = nil
        step?(from)
        let e = end
        step = nil
        end = nil
        e?()
    }
}

// MARK: - The screen

final class PotionHand {
    var active = false
    var startAt = Date()
    var grab: PotionGrab = .none
    var offset = CGSize.zero
    var start = CGPoint.zero
    var autoStir: AutoTool?
}

enum PotionGrab: Equatable {
    case none, knob, valve, unicorn, glass
    case ingredient(PIngredient)
    case rack(Int)
    case crate
    case spoon
}

struct PotionLabView: View {
    let exit: () -> Void

    @State private var sim = PotionSim()
    @State private var liquid = PotionLiquid()
    @State private var hand = PotionHand()
    @State private var script = PotionScript()
    @State private var started = false
    @State private var lightsOn = true
    @State private var book = false
    @State private var hint: PotionKind?
    static let bookSpot = CGPoint(x: 150, y: 46)

    /// How far the stirring paddle's blade sits ahead of (below) her finger: she holds the end of its handle.
    static let paddleReach: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            let map = PMap(size: geo.size)
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                    Canvas(opaque: true) { ctx, _ in
                        PotionPainter.drawBackdrop(ctx, map: map, sim: sim)
                    }
                }
                .allowsHitTesting(false)
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
                    Canvas { ctx, _ in
                        sim.step(tl.date)
                        playSounds()
                        PotionPainter.draw(ctx, map: map, sim: sim, liquid: liquid)
                    }
                }
                .contentShape(Rectangle())
                .gesture(handGesture(map))

                controls
                    .frame(width: 1024, height: 834)
                    .scaleEffect(map.s)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                if let k = hint {
                    PotionHintCard(kind: k, next: { hint = sim.hint(after: k); Sound.shared.play(.flip, volume: 0.6) },
                                   close: { withAnimation(.easeOut(duration: 0.2)) { hint = nil } })
                        .frame(width: 1024, height: 834)
                        .scaleEffect(map.s)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .transition(.opacity)
                        .zIndex(1)
                }
                if book {
                    StickerBookView(game: PotionSim.gameID) { withAnimation(.easeOut(duration: 0.2)) { book = false } }
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .coordinateSpace(name: "potion")
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onDisappear {
            script.cancel()
            sim.save()
            PotionSound.shared.stopLoops()
        }
    }

    private func start() {
        guard !started else { return }
        started = true
        _ = PotionSound.shared
        lightsOn = sim.lightsOn
        applyLaunchArguments()
    }

    private func playSounds() {
        let snd = PotionSound.shared
        for c in sim.cues { snd.play(c, volume: c == .glug || c == .fill ? 0.6 : 0.85) }
        sim.cues.removeAll()
        snd.setLoop(.fire, volume: sim.heat > 0 ? 0.18 + 0.12 * Float(sim.heat) : 0)
        snd.setLoop(.boil, volume: Float(sim.boiling) * 0.7)
        snd.setLoop(.sizzle, volume: Float(sim.fizzLevel) * 0.6)
        snd.setLoop(.stir, volume: Float(min(1, sim.stirSpeed / 700)) * 0.7)
    }

    // MARK: Controls

    private var controls: some View {
        ZStack {
            HomeButton(action: exit)
                .position(x: 62, y: 46)
            StickerBookButton(game: PotionSim.gameID) { book = true }
                .position(x: PotionLabView.bookSpot.x, y: PotionLabView.bookSpot.y)
            Button {
                Sound.shared.play(.sparkle, volume: 0.6)
                Sound.shared.tap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { hint = sim.hint(after: nil) }
            } label: {
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    let recipes = PotionKind.allCases
                    let found = recipes.filter { StickerBook.shared.has(game: PotionSim.gameID, id: $0.rawValue) }.count
                    HStack(spacing: 9) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Color(hex: 0xE09D12))
                        Text("\(found)/\(recipes.count)")
                            .font(.system(size: 23, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(width: 134, height: 72)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.lemon, lineWidth: 5))
                    .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Potion recipes")
                    .accessibilityValue("\(found) of \(recipes.count) discovered")
                }
            }
            .buttonStyle(Squish())
            .position(x: 270, y: 46)
            Button {
                Sound.shared.tap()
                lightsOn.toggle()
                sim.setLights(lightsOn)
            } label: {
                Image(systemName: lightsOn ? "sun.max.fill" : "moon.stars.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(lightsOn ? Color(hex: 0xFFB83D) : Color(hex: 0x7A7AF0))
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(.white))
                    .overlay(Circle().stroke(lightsOn ? Color(hex: 0xFFB83D) : Color(hex: 0x7A7AF0), lineWidth: 5))
                    .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
            }
            .buttonStyle(Squish())
            .position(x: 962, y: 46)
            StickerToast(game: PotionSim.gameID, target: PotionLabView.bookSpot)
        }
    }

    // MARK: Touch

    private func grabAt(_ p: CGPoint) -> PotionGrab {
        if hypot(p.x - PotionGeometry.knob.x, p.y - PotionGeometry.knob.y) < PotionGeometry.knobRadius + 20 { return .knob }
        if hypot(p.x - PotionGeometry.valve.x, p.y - (PotionGeometry.valve.y - 20)) < 46 { return .valve }
        for ing in PIngredient.allCases where ing.shelfRect.contains(p) { return .ingredient(ing) }
        for i in sim.rack.indices {
            let s = PotionSim.rackSpot(i)
            if CGRect(x: s.x - 40, y: s.y - 96, width: 80, height: 100).contains(p) { return .rack(i) }
        }
        if PotionGeometry.crate.insetBy(dx: 0, dy: -50).contains(p) { return .crate }
        if PotionGeometry.unicornBox.contains(p) { return .unicorn }
        // the flask (and the paddle's handle sticking out of it)
        if PotionGeometry.insideOuter(p, pad: 10) || (abs(p.x - PotionGeometry.C.x) < PotionGeometry.hw + 60 && p.y > PotionGeometry.rimY - 160 && p.y < PotionGeometry.rimY + 10) { return .spoon }
        return .none
    }

    private func handGesture(_ map: PMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("potion"))
            .onChanged { v in
                let p = map.design(v.location)
                if !hand.active {
                    hand.active = true
                    hand.startAt = Date()
                    hand.start = p
                    if script.running { script.cancel() }
                    if let a = hand.autoStir, a.running { a.cancel() }
                    hand.grab = grabAt(p)
                    if hand.grab == .knob || hand.grab == .valve || hand.grab == .unicorn { Sound.shared.tap() }
                    return
                }
                let moved = hypot(p.x - hand.start.x, p.y - hand.start.y)
                guard moved > 10 || sim.held != nil else { return }
                drag(hand.grab, finger: p)
            }
            .onEnded { v in
                let p = map.design(v.location)
                let moved = hypot(p.x - hand.start.x, p.y - hand.start.y)
                let tap = moved < 12 && Date().timeIntervalSince(hand.startAt) < 0.5 && sim.held == nil
                if tap {
                    tapped(hand.grab, at: p)
                } else if sim.held != nil {
                    sim.release()
                } else if hand.grab == .knob {
                    // a slide along the knob turns it
                    let dx = p.x - hand.start.x
                    sim.setHeat(sim.heat + (dx > 0 ? 1 : -1))
                }
                hand.active = false
                hand.grab = .none
            }
    }

    /// Where a held thing goes for her finger: bottles and jars above it, the paddle's blade ahead of it.
    private func lifted(_ g: PotionGrab, _ f: CGPoint) -> CGPoint {
        switch g {
        case .spoon:
            return CGPoint(x: f.x - 8, y: f.y + PotionLabView.paddleReach)
        case .crate:
            return FingerLift.point(f, lift: FingerLift.item, bottom: 834, width: 1024)
        default:
            return FingerLift.point(f, lift: FingerLift.pour, bottom: 834, width: 1024)
        }
    }

    private func drag(_ g: PotionGrab, finger f: CGPoint) {
        if sim.held == nil {
            switch g {
            case .ingredient(let ing):
                let c = CGPoint(x: ing.shelfSpot.x, y: ing.shelfSpot.y - 62)
                hand.offset = CGSize(width: c.x - f.x, height: c.y - f.y)
                sim.pickUp(.ingredient(ing), finger: f, at: c)
            case .rack(let i):
                let c = PotionSim.rackFly(i)
                hand.offset = CGSize(width: c.x - f.x, height: c.y - f.y)
                sim.pickUp(.rack(i), finger: f, at: c)
            case .crate:
                let c = CGPoint(x: PotionGeometry.crate.midX, y: PotionGeometry.crate.minY + 10)
                hand.offset = CGSize(width: c.x - f.x, height: c.y - f.y)
                sim.pickUp(.empty, finger: f, at: c)
            case .spoon:
                hand.offset = CGSize(width: sim.spoon.x - f.x, height: sim.spoon.y - f.y)
                sim.pickUp(.spoon, finger: f, at: sim.spoon)
            default:
                return
            }
        }
        let target = lifted(g, f)
        hand.offset = FingerLift.ease(hand.offset, toward: CGSize(width: target.x - f.x, height: target.y - f.y), by: 0.25)
        sim.carry(to: CGPoint(x: f.x + hand.offset.width, y: f.y + hand.offset.height), finger: f)
    }

    private func tapped(_ g: PotionGrab, at p: CGPoint) {
        switch g {
        case .knob:
            sim.setHeat(sim.heat >= 3 ? 0 : sim.heat + 1)
        case .valve:
            sim.toggleDrain()
        case .unicorn:
            sim.tapUnicorn()
        case .ingredient(let ing):
            // it flies over the flask and pours (or shakes) a bit in by itself
            let from = CGPoint(x: ing.shelfSpot.x, y: ing.shelfSpot.y - 62 + FingerLift.pour)
            let over = CGPoint(x: PotionGeometry.C.x + (ing.isLiquid ? -40 : 0), y: 96 + FingerLift.pour)
            auto(g, from: from, legs: [(over, 0.45), (over, ing.isLiquid ? 1.4 : 1.8)])
        case .rack(let i):
            // a potion from the rack goes to the unicorn
            let c = PotionSim.rackFly(i)
            let from = CGPoint(x: c.x, y: c.y + FingerLift.pour)
            let over = CGPoint(x: PotionGeometry.unicornBox.midX + 50, y: PotionGeometry.unicornBox.minY - 60 + FingerLift.pour)
            auto(g, from: from, legs: [(over, 0.5), (over, 1.4)])
        case .crate:
            // an empty bottle goes in through the mouth, fills, and comes out with its cork
            let from = CGPoint(x: PotionGeometry.crate.midX, y: PotionGeometry.crate.minY + 10 + FingerLift.item)
            let above = CGPoint(x: PotionGeometry.C.x, y: 70 + FingerLift.item)
            let deep = CGPoint(x: PotionGeometry.C.x, y: min(PotionGeometry.bottomY - 70, max(sim.level + 90, PotionGeometry.joinY + 40)) + FingerLift.item)
            auto(g, from: from, legs: [(above, 0.45), (deep, 0.5), (deep, 1.5), (above, 0.5)])
        case .spoon:
            let f = CGPoint(x: p.x, y: p.y - PotionLabView.paddleReach)
            let auto = AutoTool()
            hand.autoStir = auto
            auto.run(from: CGPoint(x: PotionSim.spoonRest.x, y: PotionSim.spoonRest.y - PotionLabView.paddleReach), to: f,
                     step: { drag(.spoon, finger: $0) }, end: { _ in sim.release() })
        case .glass, .none:
            break
        }
    }

    private func auto(_ g: PotionGrab, from: CGPoint, legs: [(CGPoint, Double)]) {
        script.run(from: from, legs: legs, step: { drag(g, finger: $0) }, end: { sim.release() })
    }

    // MARK: Screenshot hooks

    /// -potionDemo <mix|pour|shake|stir|boil|dip|unicorn|rare|night|hint> (nothing is saved).
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-potionDemo") else { return }
        let mode = i + 1 < args.count ? args[i + 1] : "mix"
        StickerBook.shared.demo = true
        sim.showcase(mode)
        if mode == "night" { lightsOn = false }
        if mode == "hint" { hint = .galaxy }
    }
}

// MARK: - The picture recipe

/// A card with a rare potion and what goes into it, in pictures: the ingredients, and the fire or the moon when it
/// needs the burner up high or the lights off. The arrow shows another one.
struct PotionHintCard: View {
    let kind: PotionKind
    let next: () -> Void
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
            VStack(spacing: 16) {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                    Canvas { ctx, size in
                        let t = CGFloat(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000))
                        draw(ctx, size, t)
                    }
                }
                .frame(width: 720, height: 300)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(.white, lineWidth: 8))
            .shadow(color: Theme.ink.opacity(0.35), radius: 20, y: 10)
            .overlay(alignment: .topTrailing) {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 66, height: 66)
                        .background(Circle().fill(Theme.pink))
                        .overlay(Circle().stroke(.white, lineWidth: 5))
                }
                .buttonStyle(Squish())
                .offset(x: 18, y: -18)
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: next) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 66, height: 66)
                        .background(Circle().fill(Theme.lilac))
                        .overlay(Circle().stroke(.white, lineWidth: 5))
                }
                .buttonStyle(Squish())
                .offset(x: 18, y: 18)
            }
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let g = ctx
        let found = StickerBook.shared.has(game: PotionSim.gameID, id: kind.rawValue)
        // the ingredients, with plus signs between
        var items: [PIngredient?] = kind.recipe.map { $0 }
        if kind.needsFire || kind.needsNight { items.append(nil) }
        let n = CGFloat(items.count)
        let step: CGFloat = min(118, 470 / max(1, n))
        let x0: CGFloat = 40 + step / 2
        let scale: CGFloat = min(0.95, step / 118 * 0.95)
        for (i, it) in items.enumerated() {
            let x = x0 + CGFloat(i) * step
            let y: CGFloat = 150
            if let ing = it {
                PotionPainter.drawIngredient(g, ing, center: CGPoint(x: x, y: y), angle: 0, scale: scale, fill: 1, time: t)
            } else if kind.needsFire {
                flame(g, CGPoint(x: x, y: y + 20), t)
            } else {
                moon(g, CGPoint(x: x, y: y))
            }
            if i < items.count - 1 {
                plus(g, CGPoint(x: x + step / 2, y: y + 10))
            }
        }
        // = the potion
        let ex = x0 + n * step - step / 2 + 34
        var eq = Path()
        eq.move(to: CGPoint(x: ex - 16, y: 152)); eq.addLine(to: CGPoint(x: ex + 16, y: 152))
        eq.move(to: CGPoint(x: ex - 16, y: 172)); eq.addLine(to: CGPoint(x: ex + 16, y: 172))
        g.stroke(eq, with: .color(Theme.ink.opacity(0.5)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        let b = PotionBottle(id: 7, r: kind.color.r, g: kind.color.g, b: kind.color.b, fill: 0.8, shape: kind.shape.rawValue, kind: kind.rawValue,
                             magic: [:], glow: Double(kind.glow), sparkle: Double(kind.sparkle))
        let bc = CGPoint(x: min(size.width - 90, ex + 120), y: 140)
        if found {
            PotionBottlePainter.draw(g, bottle: b, center: bc, angle: sin(t * 1.5) * 0.06, scale: 1.6, time: t)
        } else {
            // not found yet: a mystery shape with a question of stars
            var m = g
            m.opacity = 0.9
            PotionBottlePainter.draw(m, bottle: b, center: bc, angle: sin(t * 1.5) * 0.06, scale: 1.6, time: t)
            Twinkles.draw(g, around: bc, radius: 90, time: t * 1.5, count: 5, alpha: 1)
        }
        // stir it: a paddle going round under the recipe
        var arrow = Path()
        let c = CGPoint(x: x0 + (n - 1) * step / 2, y: 262)
        for k in 0...24 {
            let a = Double(k) / 24 * 1.7 * .pi + Double(t) * 1.6
            let p = CGPoint(x: c.x + 60 * CGFloat(cos(a)), y: c.y + 14 * CGFloat(sin(a)))
            if k == 0 { arrow.move(to: p) } else { arrow.addLine(to: p) }
        }
        g.stroke(arrow, with: .color(Theme.lilac), style: StrokeStyle(lineWidth: 6, lineCap: .round))
    }

    private func plus(_ g: GraphicsContext, _ c: CGPoint) {
        var p = Path()
        p.move(to: CGPoint(x: c.x - 13, y: c.y)); p.addLine(to: CGPoint(x: c.x + 13, y: c.y))
        p.move(to: CGPoint(x: c.x, y: c.y - 13)); p.addLine(to: CGPoint(x: c.x, y: c.y + 13))
        g.stroke(p, with: .color(Theme.ink.opacity(0.45)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
    }

    private func flame(_ g: GraphicsContext, _ c: CGPoint, _ t: CGFloat) {
        for k in 0..<3 {
            let s: CGFloat = 1 - CGFloat(k) * 0.3
            let h = 70 * s * (1 + 0.08 * sin(t * 12 + CGFloat(k)))
            var f = Path()
            f.move(to: CGPoint(x: c.x - 26 * s, y: c.y + 30))
            f.addQuadCurve(to: CGPoint(x: c.x, y: c.y + 30 - h), control: CGPoint(x: c.x - 34 * s, y: c.y + 30 - h * 0.5))
            f.addQuadCurve(to: CGPoint(x: c.x + 26 * s, y: c.y + 30), control: CGPoint(x: c.x + 34 * s, y: c.y + 30 - h * 0.5))
            f.closeSubpath()
            let col = [RGB(hex: "#FF6A2A"), RGB(hex: "#FFB03A"), RGB(hex: "#FFF0A0")][k]
            g.fill(f, with: .color(col.c()))
        }
    }

    private func moon(_ g: GraphicsContext, _ c: CGPoint) {
        let r = CGRect(x: c.x - 34, y: c.y - 34, width: 68, height: 68)
        g.fill(Path(ellipseIn: r.insetBy(dx: -10, dy: -10)), with: .color(RGB(hex: "#2A2458").c()))
        var m = Path(ellipseIn: r)
        m.addEllipse(in: r.offsetBy(dx: 22, dy: -10))
        g.fill(m, with: .color(RGB(hex: "#FFF1B8").c()), style: FillStyle(eoFill: true))
    }
}

// MARK: - Screenshots

extension PotionSim {
    /// Sets up the lab for a screenshot. Nothing is saved.
    func showcase(_ mode: String) {
        demo = true
        rack = [
            PotionBottle(id: 1, r: 1, g: 0.31, b: 0.6, fill: 0.9, shape: PBottleShape.heart.rawValue, kind: PotionKind.love.rawValue, magic: ["love": 1], glow: 0.3, sparkle: 0.3),
            PotionBottle(id: 2, r: 0.23, g: 0.12, b: 0.61, fill: 0.85, shape: PBottleShape.star.rawValue, kind: PotionKind.galaxy.rawValue, magic: ["sparkle": 1], glow: 0.45, sparkle: 1),
            PotionBottle(id: 3, r: 0.4, g: 0.8, b: 0.75, fill: 0.7, shape: PBottleShape.round.rawValue, kind: nil, magic: ["bubble": 0.8], glow: 0, sparkle: 0.1),
            PotionBottle(id: 4, r: 1, g: 0.76, b: 0.18, fill: 0.9, shape: PBottleShape.diamond.rawValue, kind: PotionKind.golden.rawValue, magic: ["glow": 1], glow: 0.75, sparkle: 1),
            PotionBottle(id: 5, r: 0.95, g: 0.55, b: 0.3, fill: 0.6, shape: PBottleShape.tall.rawValue, kind: nil, magic: ["fire": 0.7], glow: 0.2, sparkle: 0),
            PotionBottle(id: 6, r: 1, g: 0.54, b: 0.82, fill: 0.8, shape: PBottleShape.star.rawValue, kind: PotionKind.rainbow.rawValue, magic: ["rainbow": 1], glow: 0.5, sparkle: 0.7),
        ]
        nextID = 10
        volume = PotionGeometry.capacity * 0.6
        updateLiquid()
        // three layers: heavy night sky at the bottom, fairy nectar in the middle, moon milk on top
        for j in 0..<PotionSim.NY {
            for i in 0..<PotionSim.NX {
                let k = PotionSim.idx(i, j)
                guard !solid[k] else { continue }
                let y = PotionGeometry.cellCenter(i, j).y
                let ing: PIngredient = y > 560 ? .night : (y > 450 ? .nectar : .mermaid)
                let a: Float = 0.9
                dr[k] = Float(ing.color.r) * a; dg[k] = Float(ing.color.g) * a; db[k] = Float(ing.color.b) * a; da[k] = a
                rho[k] = ing.density
            }
        }
        doses = [.night: 1, .nectar: 1, .mermaid: 1]
        version += 1
        // give it a swirl so the layers marble
        for k in u.indices where liquid[k] {
            let p = PotionGeometry.cellCenter(k % PotionSim.NX, k / PotionSim.NX)
            let dx = p.x - PotionGeometry.C.x, dy = p.y - 500
            u[k] = Float(-dy * 1.4)
            v[k] = Float(dx * 1.4)
        }
        for _ in 0..<40 { step(dt: 1.0 / 60) }
        switch mode {
        case "pour":
            pickUp(.ingredient(.dragon), finger: CGPoint(x: 420, y: 230), at: CGPoint(x: 420, y: 110))
            carry(to: CGPoint(x: 420, y: 110), finger: CGPoint(x: 420, y: 220))
            demoKeepFull = true
        case "shake":
            addPiece(.stars, at: CGPoint(x: 500, y: 300), v: .zero)
            for k in 0..<6 { addPiece([PIngredient.petals, .berries, .stars][k % 3], at: CGPoint(x: 460 + CGFloat(k) * 18, y: 140 - CGFloat(k) * 20), v: CGVector(dx: 0, dy: 60)) }
            pickUp(.ingredient(.stars), finger: CGPoint(x: 540, y: 200), at: CGPoint(x: 540, y: 90))
            carry(to: CGPoint(x: 540, y: 90), finger: CGPoint(x: 540, y: 200))
            demoKeepFull = true
        case "stir":
            pickUp(.spoon, finger: CGPoint(x: 512, y: 380), at: spoon)
            demoStir = true
        case "boil":
            heat = 3
            temp = 1
            doses[.berries] = 3
            for i in foam.indices { foam[i] = 20 }
        case "dip":
            pickUp(.empty, finger: CGPoint(x: 512, y: 520), at: CGPoint(x: 512, y: 120))
            dipInside = true
            heldPos = CGPoint(x: 512, y: max(level + 90, PotionGeometry.joinY + 40))
            dipFill = 0.45
            dipColor = PIngredient.nectar.color
        case "unicorn":
            uni.rainbow = 30
            uni.glitter = 30
            uni.float = 30
            uni.floatY = -110
            pickUp(.rack(0), finger: CGPoint(x: 250, y: 470), at: CGPoint(x: 250, y: 360))
            carry(to: CGPoint(x: 250, y: 360), finger: CGPoint(x: 250, y: 470))
            demoKeepFull = true
        case "rare", "night":
            doses = [.night: 2, .stars: 3]
            if mode == "night" {
                doses = [.moon: 2]
                lightsOn = false
                night = 1
                uni.glow = 30
            }
            for _ in 0..<240 { step(dt: 1.0 / 60) }
        default:
            break
        }
    }
}
