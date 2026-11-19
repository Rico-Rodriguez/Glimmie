import Combine
import SwiftUI

// MARK: - Exam room
//
// The patient sits in the middle; tools sit on two shelves. She drags a tool off a shelf and over
// the patient. The tool's tip works on the nearest spot that needs it (see `VetVisit.use`), and the
// patient reacts: winces at the tweezers, giggles at the sponge, says "yum" to medicine, sneezes
// while it has a cold, and jumps for joy once everything is better. Tools that aren't needed still
// do something fun, so there is no wrong move.

/// Where the patient sits in the room.
private struct VetLayout {
    let size: CGSize
    static let k: CGFloat = 0.86
    var patient: CGSize { CGSize(width: 600 * VetLayout.k, height: 660 * VetLayout.k) }
    var origin: CGPoint { CGPoint(x: size.width / 2 - patient.width / 2, y: size.height - patient.height - 18) }
    func toRoom(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * VetLayout.k, y: origin.y + p.y * VetLayout.k) }
    func toPatient(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - origin.x) / VetLayout.k, y: (p.y - origin.y) / VetLayout.k) }
}

private struct VetParticle: Identifiable {
    enum Kind { case prop(String), sparkle(Color), heart(Color), drop, confetti(Color) }
    let id = UUID()
    let kind: Kind
    let pos: CGPoint
    let vel: CGVector
    let born: Date
    let life: Double
    var gravity: CGFloat = 0
    var spin: Double = 0
    var scale: CGFloat = 1
}

struct VetExamView: View {
    @ObservedObject var clinic: VetClinic
    let animal: String
    let onExit: () -> Void
    let onBack: () -> Void

    @State private var visit: VetVisit
    @State private var stickers: [VetSticker]
    @State private var tool: VetTool?
    @State private var finger: CGPoint = .zero
    @State private var lastTip: CGPoint?
    @State private var consumed = false
    @State private var usedThisDrag = false
    @State private var reaction: VetFace?
    @State private var reactionUntil = Date.distantPast
    @State private var bounceAt = Date.distantPast
    @State private var bounceAmp: CGFloat = 0.05
    @State private var particles: [VetParticle] = []
    @State private var healedAt: Date?
    @State private var nextSneeze = Date().addingTimeInterval(2.5)
    @State private var working: Int?
    @State private var workingUntil = Date.distantPast
    @State private var bowColor = Int.random(in: 0..<6)
    @State private var lastFx: [String: Date] = [:]
    @State private var size = CGSize(width: 1024, height: 834)
    /// Foam, water, fur and the rest of the physical effects (a class: it changes every frame).
    @State private var effects: VetFX

    private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    init(clinic: VetClinic, animal: String, onExit: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.clinic = clinic
        self.animal = animal
        self.onExit = onExit
        self.onBack = onBack
        _visit = State(initialValue: clinic.visit(animal))
        _stickers = State(initialValue: clinic.stickers(animal))
        let f = VetFX()
        if let a = VetArt.shared.animals[animal] { f.setUp(a) }
        _effects = State(initialValue: f)
    }

    private var layout: VetLayout { VetLayout(size: size) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx, s in VetDraw.room("exam", size: s, in: ctx) }
                TimelineView(.animation) { tl in
                    Canvas { ctx, _ in draw(ctx, now: tl.date) }
                }
                .allowsHitTesting(false)

                // tap the patient to tickle them
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: layout.patient.width * 0.62, height: layout.patient.height * 0.86)
                    .position(x: geo.size.width / 2, y: layout.origin.y + layout.patient.height * 0.55)
                    .onTapGesture { tickle() }

                HStack {
                    shelf(Array(VetTool.allCases.prefix(10)))
                    Spacer()
                    shelf(Array(VetTool.allCases.suffix(10)))
                }
                .padding(.horizontal, 14)
                .padding(.top, 96)
                .padding(.bottom, 20)

                topBar

                if let t = tool, let art = VetArt.shared.tools[t] {
                    let tip = tipRoom
                    let s: CGFloat = 150.0 / 140
                    VetToolPicture(tool: t)
                        .frame(width: 150, height: 150)
                        .shadow(color: Theme.ink.opacity(0.25), radius: 8, y: 8)
                        .position(x: tip.x + (70 - art.tip.x) * s, y: tip.y + (70 - art.tip.y) * s)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "exam")
            .onAppear { size = geo.size }
            .onChange(of: geo.size) { size = $0 }
        }
        .onReceive(timer) { _ in tick() }
        .onDisappear { save() }
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack {
            HStack(spacing: 16) {
                HomeButton { save(); onExit() }
                Button {
                    Sound.shared.play(.whoosh, volume: 0.6)
                    save()
                    onBack()
                } label: {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Color(hex: 0x6CCB8B)))
                        .overlay(Circle().stroke(.white, lineWidth: 5))
                        .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 4)
                }
                .buttonStyle(Squish())
                .scaleEffect(visit.healed ? 1.18 : 1)
                .animation(visit.healed ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: visit.healed)
                Spacer()
                hearts
                Spacer()
                Color.clear.frame(width: 160, height: 72)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            Spacer()
        }
    }

    private var hearts: some View {
        HStack(spacing: 6) {
            ForEach(visit.spots) { s in
                Image(systemName: s.healed ? "heart.fill" : "heart")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(s.healed ? Theme.pink : Theme.ink.opacity(0.3))
                    .scaleEffect(s.healed ? 1.1 : 0.9)
                    .animation(.spring(response: 0.3, dampingFraction: 0.45), value: s.healed)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Capsule().fill(.white.opacity(0.85)))
        .shadow(color: Theme.ink.opacity(0.12), radius: 5, y: 3)
    }

    // MARK: Shelves

    private func shelf(_ tools: [VetTool]) -> some View {
        let needed = visit.neededTools
        return VStack(spacing: 10) {
            ForEach(0..<(tools.count + 1) / 2, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(tools[(row * 2)..<min(tools.count, row * 2 + 2)], id: \.self) { t in
                        VetToolButton(tool: t, needed: needed.contains(t), lifted: tool == t,
                                      onDrag: { drag(t, $0) }, onEnd: { drop(t, $0) })
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white, lineWidth: 4))
    }

    // MARK: Dragging

    private var tipRoom: CGPoint { CGPoint(x: finger.x, y: finger.y - 44) }

    private func drag(_ t: VetTool, _ p: CGPoint) {
        guard !consumed else { return }
        if tool == nil {
            tool = t
            usedThisDrag = false
            lastTip = nil
            Sound.shared.play(.tap, volume: 0.6)
            Sound.shared.tap()
        }
        finger = p
    }

    private func drop(_ t: VetTool, _ p: CGPoint) {
        defer {
            tool = nil
            lastTip = nil
            consumed = false
            effects.endDrag()
        }
        guard !consumed, tool == t else { return }
        finger = p
        let tip = layout.toPatient(tipRoom)
        let onHead = hypot(tip.x - 300, tip.y - 250) < 175
        let onBody = onHead || (abs(tip.x - 300) < 140 && tip.y > 330 && tip.y < 640)
        if t == .bow && onHead {
            addSticker(VetSticker(prop: "bow\(bowColor)", x: tip.x, y: tip.y, scale: 0.85, rotation: Double.random(in: -18...18)))
            bowColor = (bowColor + 1) % 6
            react(.wow, 1.0)
        } else if t == .bandage && onBody && !usedThisDrag {
            addSticker(VetSticker(prop: "bandage", x: tip.x, y: tip.y, scale: 0.7, rotation: Double.random(in: -30...30)))
            react(.giggle, 0.8)
        } else {
            Sound.shared.play(.flip, volume: 0.4)
        }
    }

    private func addSticker(_ s: VetSticker) {
        stickers.append(s)
        effects.pressSticker(at: s.point)
        if stickers.count > 12 { stickers.removeFirst(stickers.count - 12) }
        clinic.setStickers(stickers, for: animal)
        VetSound.shared.play(.sticker)
        bounce(0.05)
        burst(at: layout.toRoom(s.point), count: 6, colors: [.white, Theme.lemon, Theme.pink])
    }

    // MARK: The game loop

    private func tick() {
        let now = Date()
        if !particles.isEmpty { particles.removeAll { now.timeIntervalSince($0.born) > $0.life } }

        if visit.has(.cold) && tool == nil && now > nextSneeze {
            nextSneeze = now.addingTimeInterval(Double.random(in: 5...8))
            react(.sneeze, 0.7)
            VetSound.shared.play(.sneeze, volume: 0.7)
            bounce(0.08)
            spawn(.prop("drip"), at: layout.toRoom(CGPoint(x: 312, y: 330)), vel: CGVector(dx: 30, dy: -60), life: 0.9, gravity: 500, scale: 0.6)
        }

        guard let t = tool, !consumed else { return }
        let tip = layout.toPatient(tipRoom)
        let moved = min(40, lastTip.map { hypot(tip.x - $0.x, tip.y - $0.y) } ?? 0)
        let step = lastTip.map { CGVector(dx: tip.x - $0.x, dy: tip.y - $0.y) } ?? .zero
        lastTip = tip
        effects.mudSpots = visit.spots.filter { $0.ailment == .mud && !$0.healed }.map(\.point)
        effects.emit(t, tip: tip, room: tipRoom, step: step, toRoom: layout.toRoom,
                mouth: VetArt.shared.animals[animal]?.mouth ?? CGPoint(x: 300, y: 334), mud: effects.mudSpots)
        let events = visit.use(t, at: tip, moved: moved, dt: 1.0 / 30)
        if events.isEmpty {
            play(t, tip: tip, moved: moved, now: now)
        } else {
            usedThisDrag = true
            for e in events { handle(e, tool: t, tip: tip, now: now) }
            clinic.update(visit)
        }
    }

    private func handle(_ e: VetVisit.Event, tool t: VetTool, tip: CGPoint, now: Date) {
        let room = layout.toRoom(tip)
        switch e {
        case .working(let id, _):
            working = id
            workingUntil = now.addingTimeInterval(0.25)
            let a = visit.spots.first { $0.id == id }?.ailment
            if a?.stings == true {
                react(.ouch, 0.35)
                VetSound.shared.play(.ouch, volume: 0.5, gap: 1.4)
            } else {
                switch t {
                case .toothbrush: react(.brushing, 0.3)
                case .thermometer: react(.oh, 0.3)
                case .stethoscope, .icepack: react(.blinkSmile, 0.3)
                default: react(.giggle, 0.3)
                }
            }
            switch t {
            case .sponge, .cream, .swab, .toothbrush:
                VetSound.shared.play(.scrub, volume: 0.6, gap: 0.22)
            case .shower:
                VetSound.shared.play(.splash, volume: 0.6, gap: 0.5)
            case .comb, .brush, .tissue:
                VetSound.shared.play(.swish, volume: 0.6, gap: 0.28)
            case .stethoscope:
                VetSound.shared.play(.heartbeat, gap: 0.9)
                if fx("hb", 0.9) { spawn(.heart(Theme.pink), at: room, vel: CGVector(dx: 0, dy: -90), life: 0.9, scale: 1.1) }
            default:
                break
            }
        case .stepDone(let id, let ailment, let step):
            guard let s = visit.spots.first(where: { $0.id == id }) else { break }
            let at = layout.toRoom(ailment.steps[step].anchor.map(VetAnchors.point) ?? s.point)
            bounce(0.06)
            burst(at: at, count: 8)
            switch t {
            case .tweezers:
                VetSound.shared.play(.pluck)
                spawn(.prop("thorn"), at: at, vel: CGVector(dx: s.point.x < 300 ? -160 : 160, dy: -380), life: 1.2, gravity: 700, spin: 400, scale: 0.8)
                react(.ouch, 0.4)
            case .bandage:
                VetSound.shared.play(.sticker)
                effects.pressSticker(at: s.point)
            case .thermometer: VetSound.shared.play(.beep)
            case .syrup:
                VetSound.shared.play(.nom)
                react(.yum, 1.0)
            case .shower: VetSound.shared.play(.splash)
            case .wrap:
                VetSound.shared.play(.zip)
                effects.wrap(id)
            case .stethoscope: VetSound.shared.play(.heartbeat)
            case .comb:
                VetSound.shared.play(.bugjump)
                spawn(.prop(["bug", "bugGreen", "bugPink"][id % 3]), at: at,
                      vel: CGVector(dx: s.point.x < 300 ? -320 : 320, dy: -520), life: 1.4, gravity: 900, spin: 200, scale: 0.6)
            case .brush:
                VetSound.shared.play(.swish)
                spawn(.prop(["leaf", "leafGold", "leafRed"][id % 3]), at: at,
                      vel: CGVector(dx: s.point.x < 300 ? -200 : 200, dy: -200), life: 1.8, gravity: 260, spin: 160, scale: 0.8)
            case .sponge: Sound.shared.play(.bubble, volume: 0.7)
            default: Sound.shared.play(.ding, volume: 0.5)
            }
        case .spotHealed(let id, _):
            if let s = visit.spots.first(where: { $0.id == id }) {
                let at = layout.toRoom(s.point)
                for i in 0..<3 {
                    spawn(.heart([Theme.pink, Color(hex: 0xFF6F96), Theme.lilac][i]), at: at,
                          vel: CGVector(dx: Double(i - 1) * 60, dy: -150 - Double(i) * 30), life: 1.1, scale: 0.9)
                }
            }
            Sound.shared.play(.sparkle, volume: 0.6)
            if reaction != .yum { react(.giggle, 0.9) }
        case .allHealed:
            healedAt = now
            clinic.recordHealed(animal)
            react(.wow, 2.6)
            bounce(0.1)
            VetSound.shared.play(.healed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { Sound.shared.play(.fanfare, volume: 0.7) }
            confetti()
        }
    }

    /// Tools that aren't needed right now still do something nice.
    private func play(_ t: VetTool, tip: CGPoint, moved: CGFloat, now: Date) {
        let a = VetArt.shared.animals[animal]
        let mouth = a?.mouth ?? CGPoint(x: 300, y: 334)
        let nearMouth = hypot(tip.x - mouth.x, tip.y - mouth.y) < 70
        let onPatient = hypot(tip.x - 300, tip.y - 262) < 170 || (abs(tip.x - 300) < 150 && tip.y > 330 && tip.y < 650)
        guard onPatient else { return }
        let room = layout.toRoom(tip)
        let rubbing = moved > 2
        switch t {
        case .treat, .syrup:
            if nearMouth {
                consumed = true
                tool = nil
                VetSound.shared.play(.nom)
                if t == .treat { effects.crumbs(at: layout.toRoom(mouth)) }
                react(.yum, 1.3)
                bounce(0.07)
                for i in 0..<4 {
                    spawn(.heart([Theme.pink, Color(hex: 0xFF6F96)][i % 2]), at: layout.toRoom(mouth),
                          vel: CGVector(dx: Double(i) * 40 - 60, dy: -160), life: 1.2, scale: 0.8)
                }
            } else { react(.oh, 0.3) }
        case .feather:
            if rubbing {
                react(.giggle, 0.6)
                VetSound.shared.play(.giggle, volume: 0.6, gap: 1.0)
                if fx("wig", 0.5) { bounce(0.04) }
            }
        case .brush, .towel, .comb:
            if rubbing {
                react(.blinkSmile, 0.5)
                VetSound.shared.play(.swish, volume: 0.5, gap: 0.35)
                if fx("spk", 0.15) { spawn(.sparkle(.white), at: room, vel: CGVector(dx: .random(in: -60...60), dy: -80), life: 0.6, scale: 0.8) }
            }
        case .sponge:
            if rubbing {
                react(.giggle, 0.4)
                VetSound.shared.play(.scrub, volume: 0.5, gap: 0.25)
            }
        case .shower:
            react(.giggle, 0.4)
            VetSound.shared.play(.splash, volume: 0.5, gap: 0.5)
        case .spray:
            react(.wow, 0.6)
            VetSound.shared.play(.spray, volume: 0.5, gap: 0.45)
            if fx("spr", 0.08) {
                spawn(.sparkle([Theme.lemon, Theme.pink, .white, Theme.lilac].randomElement()!), at: room,
                      vel: CGVector(dx: .random(in: -120...120), dy: .random(in: -140...(-20))), life: 0.9, scale: .random(in: 0.6...1.2))
            }
        case .stethoscope:
            react(.blinkSmile, 0.4)
            VetSound.shared.play(.heartbeat, volume: 0.8, gap: 0.9)
            if fx("hb", 0.9) { spawn(.heart(Theme.pink), at: room, vel: CGVector(dx: 0, dy: -90), life: 0.9, scale: 1.1) }
        case .thermometer, .toothbrush:
            react(nearMouth ? (t == .toothbrush ? .brushing : .oh) : .oh, 0.3)
            if nearMouth && t == .toothbrush && rubbing {
                VetSound.shared.play(.scrub, volume: 0.5, gap: 0.25)
                if fx("spk", 0.2) { spawn(.sparkle(.white), at: room, vel: CGVector(dx: .random(in: -50...50), dy: -60), life: 0.6) }
            }
        case .icepack:
            react(.blinkSmile, 0.4)
        case .tissue, .cream, .swab, .wrap, .tweezers, .bandage, .bow:
            react(.oh, 0.3)
        }
    }

    private func tickle() {
        react(.giggle, 0.8)
        VetSound.shared.play(.giggle, volume: 0.6, gap: 0.6)
        VetSound.shared.play(.hop, volume: 0.4, gap: 0.3)
        bounce(0.07)
        let p = layout.toRoom(CGPoint(x: 300, y: 200))
        spawn(.heart(Theme.pink), at: p, vel: CGVector(dx: .random(in: -60...60), dy: -140), life: 1.0)
    }

    // MARK: Effects helpers

    private func react(_ f: VetFace, _ secs: Double) {
        reaction = f
        reactionUntil = Date().addingTimeInterval(secs)
    }

    private func bounce(_ amp: CGFloat) {
        bounceAt = Date()
        bounceAmp = amp
    }

    /// True at most once per `gap` seconds for `key`.
    private func fx(_ key: String, _ gap: Double) -> Bool {
        let now = Date()
        if let t = lastFx[key], now.timeIntervalSince(t) < gap { return false }
        lastFx[key] = now
        return true
    }

    private func spawn(_ k: VetParticle.Kind, at p: CGPoint, vel: CGVector, life: Double, gravity: CGFloat = 0,
                       spin: Double = 0, scale: CGFloat = 1) {
        particles.append(VetParticle(kind: k, pos: p, vel: vel, born: Date(), life: life, gravity: gravity, spin: spin, scale: scale))
        if particles.count > 160 { particles.removeFirst(particles.count - 160) }
    }

    private func burst(at p: CGPoint, count: Int, colors: [Color] = [.white, Theme.lemon, Theme.pink, Theme.mint]) {
        for i in 0..<count {
            let a = Double(i) / Double(count) * 2 * .pi
            spawn(.sparkle(colors[i % colors.count]), at: p, vel: CGVector(dx: cos(a) * 170, dy: sin(a) * 170 - 40),
                  life: 0.7, scale: 0.7 + CGFloat(i % 3) * 0.25)
        }
    }

    private func confetti() {
        let colors = [Theme.pink, Theme.lemon, Theme.mint, Theme.sky, Theme.lilac, Theme.peach]
        for i in 0..<46 {
            let x = size.width * CGFloat.random(in: 0.2...0.8)
            spawn(.confetti(colors[i % colors.count]), at: CGPoint(x: x, y: size.height * 0.45),
                  vel: CGVector(dx: .random(in: -260...260), dy: .random(in: -760...(-380))), life: 2.4, gravity: 620,
                  spin: .random(in: -600...600), scale: .random(in: 0.8...1.3))
        }
        burst(at: layout.toRoom(CGPoint(x: 300, y: 260)), count: 14)
    }

    private func save() {
        clinic.update(visit)
        clinic.setStickers(stickers, for: animal)
    }

    // MARK: Drawing

    private func face(_ now: Date) -> VetFace {
        if let r = reaction, now < reactionUntil { return r }
        let t = now.timeIntervalSinceReferenceDate
        var f: VetFace
        if visit.healed {
            f = (healedAt.map { now.timeIntervalSince($0) < 4 } ?? false) ? .wow : .calm
            if t.truncatingRemainder(dividingBy: 7) < 1.2 { f = .giggle }
        } else if visit.has(.cold) || visit.has(.tummy) {
            f = .poorly
        } else {
            f = .sad
        }
        if tool != nil && !visit.healed { f = VetFace(eyes: "open", mouth: f.mouth, brows: f.brows) }
        if f.eyes == "open" || f.eyes == "sad" || f.eyes == "sparkle" {
            if t.truncatingRemainder(dividingBy: 3.7) < 0.13 { f.eyes = "blink" }
        }
        return f
    }

    private func draw(_ ctx: GraphicsContext, now: Date) {
        let art = VetArt.shared
        guard let a = art.animals[animal] else { return }
        let L = layout
        let t = now.timeIntervalSinceReferenceDate
        effects.step(to: t, toPatient: L.toPatient, toRoom: L.toRoom, floorY: L.toRoom(CGPoint(x: 300, y: 648)).y)

        // body motion: breathing, squash-bounce, shivers, and a happy hop when healed
        var sy: CGFloat = 1 + 0.012 * CGFloat(sin(t * 2.4))
        var sx: CGFloat = 1
        let db = now.timeIntervalSince(bounceAt)
        if db < 1.4 {
            let b = bounceAmp * CGFloat(sin(db * 18) * exp(-db * 4.5))
            sy += b
            sx -= b * 0.6
        }
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        if visit.has(.cold) && t.truncatingRemainder(dividingBy: 3.2) < 0.5 { dx = 2.5 * sin(t * 60) }
        if let h = healedAt {
            let dh = now.timeIntervalSince(h)
            if dh < 2.6 { dy = -CGFloat(abs(sin(dh * 7.4)) * 60 * exp(-dh * 1.1)) }
        }

        var g = ctx
        g.translateBy(x: L.origin.x, y: L.origin.y)
        g.scaleBy(x: VetLayout.k, y: VetLayout.k)
        g.fill(Path(ellipseIn: CGRect(x: 300 - 190 * (1 - dy / 160), y: 622, width: 380 * (1 - dy / 160), height: 40)),
               with: .color(Theme.ink.opacity(0.12)))
        effects.drawPuddle(g, floor: CGPoint(x: 300, y: 642), t: t)

        var p = g
        p.translateBy(x: 300 + dx, y: 640 + dy)
        if abs(effects.lean) > 0.01 { p.rotate(by: .degrees(effects.lean)) }
        p.scaleBy(x: sx, y: sy)
        p.translateBy(x: -300, y: -640)

        var look = CGVector.zero
        if tool != nil {
            let tip = L.toPatient(tipRoom)
            let v = CGVector(dx: tip.x - 300, dy: tip.y - a.eye.y)
            let n = max(1, hypot(v.dx, v.dy))
            look = CGVector(dx: v.dx / n * 6, dy: v.dy / n * 5)
        }

        VetPatientPainter.draw(a, face: face(now), look: look, in: p, overlay: { c in
            for s in stickers {
                VetDraw.prop(s.prop, at: s.point, scale: CGFloat(s.scale) * effects.pressScale(at: s.point, t: t), rotation: s.rotation, in: c)
            }
            drawSpots(c, t: t, now: now)
            effects.drawOnFur(c, t: t)
        }, top: { c in
            drawFaceTop(c, a: a, t: t)
        })

        // where the lifted tool is needed
        if let tl = tool {
            let pulse = 1 + 0.12 * sin(t * 7)
            for s in visit.spots where s.step?.tool == tl {
                let c = s.target
                let r = 46 * pulse
                let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                p.stroke(ring, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [14, 12], dashPhase: CGFloat(t * 30)))
                p.stroke(ring, with: .color(Theme.pink.opacity(0.7)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [14, 12], dashPhase: CGFloat(t * 30)))
            }
        }

        if let h = healedAt, now.timeIntervalSince(h) < 3.5 {
            let dh = now.timeIntervalSince(h)
            let s = CGFloat(min(1, dh * 3)) * (1 + 0.05 * CGFloat(sin(dh * 6)))
            VetDraw.prop("medal", at: L.toRoom(CGPoint(x: 470, y: 120)), scale: 1.3 * s,
                         rotation: 8 * sin(dh * 3), opacity: min(1, (3.5 - dh) * 2), in: ctx)
        }

        drawParticles(ctx, now: now)
        effects.drawInRoom(ctx, t: t)
    }

    private func drawSpots(_ c: GraphicsContext, t: Double, now: Date) {
        for s in visit.spots {
            let p = s.point
            let busy = working == s.id && now < workingUntil
            let jig: CGFloat = busy ? CGFloat(sin(t * 50)) * 2 : 0
            let pr = CGFloat(min(1, s.progress))
            switch s.ailment {
            case .mud:
                if s.stage == 0 {
                    VetDraw.prop("mud", at: p, scale: 0.85, opacity: Double(1 - pr * 0.6), in: c)
                    VetFX.drawLather(c, at: p, amount: pr * 0.9, mud: Double(1 - pr) * 0.8, t: t)
                } else if s.stage == 1 {
                    VetFX.drawLather(c, at: CGPoint(x: p.x, y: p.y + pr * 30), amount: (1 - pr) * (1 + jig * 0.02), mud: 0.12 * Double(1 - pr), t: t)
                }
            case .thorns:
                if !s.healed {
                    VetDraw.prop("thorn", at: CGPoint(x: p.x + jig, y: p.y - 6), scale: 0.75,
                                 rotation: (p.x < 300 ? -22 : 22) + (busy ? 8 * sin(t * 30) : 0), in: c)
                }
            case .scrape:
                if s.healed {
                    VetDraw.prop("bandage", at: p, scale: 0.68 * effects.pressScale(at: p, t: now.timeIntervalSinceReferenceDate), rotation: Double((s.id * 37) % 50 - 25), in: c)
                } else {
                    VetDraw.prop("scrapeClean", at: p, scale: 0.8, in: c)
                    if s.stage == 0 { VetDraw.prop("scrape", at: p, scale: 0.8, opacity: Double(1 - pr * 0.9), in: c) }
                }
            case .cold:
                if !s.healed {
                    VetDraw.prop("rednose", at: VetAnchors.point("nose"), scale: 0.9 + 0.05 * CGFloat(sin(t * 3)), in: c)
                }
            case .toothache:
                if s.stage == 0 {
                    VetDraw.prop("swelling", at: p, scale: 0.8 + 0.04 * CGFloat(sin(t * 5)) - pr * 0.25, in: c)
                } else if s.stage == 1 {
                    VetDraw.prop("swelling", at: p, scale: 0.45, opacity: 0.8, in: c)
                }
            case .fleas:
                if !s.healed {
                    let hop = -abs(CGFloat(sin(t * 5 + Double(s.id)))) * 10
                    VetDraw.prop(["bug", "bugGreen", "bugPink"][s.id % 3], at: CGPoint(x: p.x + jig * 3, y: p.y + hop),
                                 scale: 0.58, rotation: 10 * sin(t * 3 + Double(s.id)), in: c)
                }
            case .rash:
                if !s.healed { VetDraw.prop("rash", at: p, scale: 0.75, opacity: Double(1 - pr * 0.8), in: c) }
            case .tummy:
                if !s.healed {
                    VetDraw.prop("swirl", at: p, scale: s.stage == 0 ? 0.85 : 0.55, rotation: t * 90, opacity: s.stage == 0 ? 1 : 0.6, in: c)
                }
            case .sprain:
                if s.healed {
                    VetFX.drawWrap(c, at: p, started: effects.wraps[s.id], t: t)
                } else {
                    VetDraw.prop("bump", at: p, scale: (s.stage == 0 ? 0.8 : 0.5) + 0.06 * CGFloat(sin(t * 6)), in: c)
                }
            case .leaves:
                if !s.healed {
                    VetDraw.prop(["leaf", "leafGold", "leafRed"][s.id % 3], at: CGPoint(x: p.x + jig * 2, y: p.y),
                                 scale: 0.8, rotation: 8 * sin(t * 2 + Double(s.id)), in: c)
                }
            }
        }
    }

    /// Things drawn over the face: cold drips and shivers, foam while brushing.
    private func drawFaceTop(_ c: GraphicsContext, a: VetAnimal, t: Double) {
        if visit.has(.cold) {
            let n = VetAnchors.point("nose")
            let bob = CGFloat(sin(t * 2.2)) * 4
            VetDraw.prop("drip", at: CGPoint(x: n.x + 16, y: n.y + 24 + bob), scale: 0.7 + 0.08 * CGFloat(sin(t * 2.2)), in: c)
            VetDraw.prop("chill", at: CGPoint(x: 300, y: 262), scale: 1, opacity: 0.6 + 0.3 * sin(t * 4), in: c)
        }
        for s in visit.spots where s.ailment == .toothache && s.stage == 1 && s.progress > 0.05 {
            VetDraw.prop("bubbles", at: CGPoint(x: a.mouth.x + 30, y: a.mouth.y + 12), scale: 0.3 + CGFloat(s.progress) * 0.35, opacity: 0.9, in: c)
        }
    }

    private func drawParticles(_ ctx: GraphicsContext, now: Date) {
        for q in particles {
            let age = now.timeIntervalSince(q.born)
            guard age >= 0, age < q.life else { continue }
            let tt = CGFloat(age)
            let x = q.pos.x + q.vel.dx * tt
            let y = q.pos.y + q.vel.dy * tt + 0.5 * q.gravity * tt * tt
            let fade = min(1, (q.life - age) / 0.3)
            var g = ctx
            g.opacity = fade
            g.translateBy(x: x, y: y)
            g.rotate(by: .degrees(q.spin * age))
            switch q.kind {
            case .prop(let name):
                VetDraw.prop(name, at: .zero, scale: q.scale, in: g)
            case .sparkle(let col):
                // a real twinkle: it flares and dims and turns as it flies
                let seed = Double(abs(q.id.hashValue % 997)) / 97
                let flicker = CGFloat(0.55 + 0.45 * abs(sin(age * 15 + seed)))
                let r = 13 * q.scale * (1 - tt * 0.4) * flicker
                let glow = r * 1.9
                g.fill(Path(ellipseIn: CGRect(x: -glow, y: -glow, width: glow * 2, height: glow * 2)),
                       with: .radialGradient(Gradient(colors: [col.opacity(0.45), col.opacity(0)]), center: .zero, startRadius: 0, endRadius: glow))
                g.rotate(by: .degrees(age * 140 + seed * 30))
                g.fill(Twinkle().path(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(col))
                g.fill(Path(ellipseIn: CGRect(x: -r * 0.22, y: -r * 0.22, width: r * 0.44, height: r * 0.44)), with: .color(.white))
            case .heart(let col):
                let r = 16 * q.scale * (0.6 + min(0.4, tt))
                let hp = VetExamView.heart(r)
                g.fill(hp, with: .color(col))
                g.stroke(hp, with: .color(.white), lineWidth: 3)
            case .drop:
                let r = 6 * q.scale
                g.fill(Path(ellipseIn: CGRect(x: -r * 0.7, y: -r, width: r * 1.4, height: r * 2)), with: .color(Color(hex: 0x8EC5FF)))
            case .confetti(let col):
                g.fill(Path(roundedRect: CGRect(x: -7 * q.scale, y: -4 * q.scale, width: 14 * q.scale, height: 8 * q.scale), cornerRadius: 2),
                       with: .color(col))
            }
        }
    }

    static func heart(_ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: s * 0.95))
        p.addCurve(to: CGPoint(x: -s, y: -s * 0.25), control1: CGPoint(x: -s * 0.2, y: s * 0.75), control2: CGPoint(x: -s, y: s * 0.25))
        p.addCurve(to: CGPoint(x: 0, y: -s * 0.5), control1: CGPoint(x: -s, y: -s * 0.75), control2: CGPoint(x: -s * 0.45, y: -s * 0.95))
        p.addCurve(to: CGPoint(x: s, y: -s * 0.25), control1: CGPoint(x: s * 0.45, y: -s * 0.95), control2: CGPoint(x: s, y: -s * 0.75))
        p.addCurve(to: CGPoint(x: 0, y: s * 0.95), control1: CGPoint(x: s, y: s * 0.25), control2: CGPoint(x: s * 0.2, y: s * 0.75))
        p.closeSubpath()
        return p
    }
}

// MARK: - A tool on the shelf

private struct VetToolButton: View {
    let tool: VetTool
    let needed: Bool
    let lifted: Bool
    let onDrag: (CGPoint) -> Void
    let onEnd: (CGPoint) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !needed)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 2.2)
            let wiggle = needed && phase < 0.7 ? sin(phase * 27) * 7 * (1 - phase / 0.7) : 0
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(VetArt.shared.tools[tool]?.tint ?? .white)
                VetToolPicture(tool: tool).padding(9)
            }
            .frame(width: 92, height: 92)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(needed ? Theme.pink : .white, lineWidth: needed ? 6 : 4)
            )
            .shadow(color: needed ? Theme.pink.opacity(0.55) : Theme.ink.opacity(0.15), radius: needed ? 9 : 4, y: needed ? 0 : 3)
            .rotationEffect(.degrees(wiggle))
            .opacity(lifted ? 0.35 : 1)
            .scaleEffect(lifted ? 0.92 : 1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("exam"))
                .onChanged { onDrag($0.location) }
                .onEnded { onEnd($0.location) }
        )
    }
}
