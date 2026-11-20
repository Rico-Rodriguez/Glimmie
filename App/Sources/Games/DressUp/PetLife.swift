import SwiftUI

// MARK: - The pet corner stage, alive
//
// One class holds everything that moves (a class, like DollMotion: it changes every frame and is
// drawn by a TimelineView, so it never triggers SwiftUI updates). Coordinates are the pet corner's
// design space ("corner"); the pet itself is drawn in its 600x660 art space at scale `k`.
//
// What she can do:
// - pet it (rub) for hearts, tap it to make it hop and giggle
// - drag a snack to its mouth (it opens wide, chews, and loves its favorite best)
// - sponge on bubbles, rinse them off with the shower (it shakes dry), or rub with the towel
// - brush it until it shines
// - throw the ball or yarn (it bounces off the walls and the pet heads it), tickle it with the feather
// - put it to bed (lights dim, blanket, Zzz); tap to wake it with a yawn
// Every tool also works with a single tap: it plays itself.

private enum Bit { case heart, sparkle, bubble, crumb, drop, zzz, confetti, splash }

private struct Particle {
    var kind: Bit
    var p: CGPoint
    var v: CGVector
    var born: Double
    var life: Double
    var size: CGFloat
    var color: Color
    var spin: Double = 0
}

private struct Ball {
    var id: String
    var p: CGPoint
    var v: CGVector
    var angle: Double = 0
    var touched: Double
    var lastHeader: Double = 0
}

private enum Want: String, CaseIterable { case food, bath, brush, play, sleep }

final class PetLife {
    static let trayW: CGFloat = 410

    // layout
    private(set) var size = CGSize(width: 1194, height: 834)
    let k: CGFloat = 0.78
    private var leftW: CGFloat { size.width - Self.trayW - 36 }
    private var origin: CGPoint { CGPoint(x: leftW / 2 - 300 * k + 10, y: 732 - PetArt.feetY * k) }
    private var floorY: CGFloat { origin.y + (PetArt.feetY + 10) * k }

    private func toPet(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - origin.x) / k, y: (p.y - origin.y - hopY) / k) }
    private func toCanvas(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * k, y: origin.y + p.y * k + hopY) }
    private var headC: CGPoint { toCanvas(PetArt.headCenter) }
    private var mouthC: CGPoint { toCanvas(PetArt.shared.animals[kind]?.mouth ?? CGPoint(x: 300, y: 334)) }

    var onLove: (Int, Bool) -> Void = { _, _ in }

    private(set) var kind = "kitty"
    private var t: Double = 0
    private var last: Double = 0
    private var lastTouch: Double = 0

    // the body
    private var hopY: CGFloat = 0, hopV: CGFloat = 0
    private var squash: CGFloat = 1, squashV: CGFloat = 0
    private var tilt: Double = 0, tiltTarget: Double = 0
    private var eyeOff: CGSize = .zero
    private var lookAt: CGPoint?
    private var nextBlink: Double = 1
    private var blinkUntil: Double = 0
    private var face: (eyes: String, mouth: String, until: Double)?
    private var chewUntil: Double = 0
    private var chewFood = ""
    private var shakeUntil: Double = 0
    private var sleeping = false
    private var sleepSince: Double = 0
    private var yawnUntil: Double = 0
    private var dim: Double = 0

    // bath and brush
    private var foam: [CGPoint] = []
    private var hadFoam = false
    private var wet: [CGPoint] = []
    private var shine: CGFloat = 0
    private var shineAwarded = false

    // things flying around
    private var bits: [Particle] = []
    private var ball: Ball?

    // the tool in her hand
    private var held: String?
    private var heldAt: CGPoint = .zero
    /// Where the held tool is drawn: lifted above her finger (see `FingerLift`), or on its path when it plays itself.
    private var drawAt: CGPoint = .zero
    private var heldLast: CGPoint = .zero
    private var heldMoved: CGFloat = 0
    private var stepDist: CGFloat = 0
    private var auto: [CGPoint] = []
    private var autoStart: Double = 0
    private var autoDur: Double = 1
    private var autoThrow: CGVector?

    // petting
    private var rubbed: CGFloat = 0
    private var touching = false
    private var touchStartT: Double = 0
    private var touchLast: CGPoint = .zero
    private var tickle: Double = 0

    // what it would like to do next
    private var want: Want?
    private var nextWant: Double = 0

    private var lastSound: [String: Double] = [:]

    // MARK: Control

    func reset(kind: String) {
        self.kind = kind
        foam = []; wet = []; hadFoam = false; shine = 0; shineAwarded = false
        bits = []; ball = nil; held = nil; auto = []; sleeping = false; dim = 0
        want = nil; nextWant = t + Double.random(in: 9...14)
        face = nil; chewUntil = 0
        hop(0.8)
    }

    /// A little happy hop (when she changes its clothes or picks it).
    func cheer() {
        hop(1)
        express("happy", "grin", 0.7)
        for _ in 0..<5 { spawn(.heart, at: headC, spread: 80) }
    }

    /// A salon treatment: a twinkly swirl and a proud wiggle.
    func pamper() {
        hop(0.6)
        express("sparkle", "grin", 1.0)
        for _ in 0..<14 { spawn(.sparkle, at: toCanvas(CGPoint(x: 300, y: 380)), spread: 200) }
        play("sparkle", 0.1)
    }

    func demo(_ mode: String) {
        switch mode {
        case "foam":
            for i in 0..<26 {
                let a = Double(i) * 0.9
                foam.append(CGPoint(x: 300 + cos(a) * Double(40 + i * 4), y: 440 + sin(a) * Double(30 + i * 2)))
            }
            hadFoam = true
            express("happy", "grin", 30)
        case "sleep": goToSleep()
        case "feed": express("sparkle", "wide", 30)
        default: express("happy", "grin", 2)
        }
    }

    // MARK: Touches on the stage

    func touch(_ p: CGPoint, start: CGPoint) {
        lastTouch = t
        if !touching {
            touching = true
            touchStartT = t
            touchLast = p
            if var b = ball, hypot(b.p.x - p.x, b.p.y - p.y) < 90 {
                // kick the ball
                b.v = CGVector(dx: (b.p.x - p.x) * 14, dy: -900 - CGFloat.random(in: 0...300))
                b.touched = t
                ball = b
                play("boing", 0.1)
                touching = false
                return
            }
        }
        let d = hypot(p.x - touchLast.x, p.y - touchLast.y)
        touchLast = p
        guard over(p), !sleeping else { return }
        lookAt = p
        if d > 0 {
            rubbed += d
            tiltTarget = Double(max(-6, min(6, (p.x - headC.x) / 30)))
            express("happy", "grin", 0.5)
            if Int(rubbed / 46) != Int((rubbed - d) / 46) { spawn(.heart, at: p, spread: 20) }
            if rubbed > 900 {
                rubbed = 0
                love(1)
                play("sparkle", 0.5)
            }
        }
    }

    func release(_ p: CGPoint, start: CGPoint, predicted: CGPoint) {
        defer { touching = false; tiltTarget = 0 }
        let moved = hypot(p.x - start.x, p.y - start.y)
        guard moved < 14, t - touchStartT < 0.45, over(p) else { return }
        if sleeping { wake(); return }
        // tap: a hop and a giggle
        hop(1)
        express("happy", "grin", 0.6)
        spawn(.heart, at: headC, spread: 60)
        spawn(.heart, at: headC, spread: 60)
        play("boing", 0.15)
    }

    // MARK: Tools from the tray

    func trayChanged(_ id: String, _ p: CGPoint, translation: CGSize) {
        lastTouch = t
        if held == nil, auto.isEmpty, hypot(translation.width, translation.height) > 10 {
            pick(id, at: p)
        }
        if held == id && auto.isEmpty { move(to: p) }
    }

    func trayEnded(_ id: String, _ p: CGPoint, predicted: CGPoint) {
        if held == id && auto.isEmpty {
            drop(at: drawAt, velocity: CGVector(dx: (predicted.x - p.x) * 3, dy: (predicted.y - p.y) * 3))
        } else if held == nil {
            autoUse(id, from: p)
        }
    }

    private func pick(_ id: String, at p: CGPoint) {
        held = id
        heldAt = p; heldLast = p; heldMoved = 0; stepDist = 0
        drawAt = drawn(p)
        play("pop", 0.05)
        Sound.shared.tap()
        if id == "ball" || id == "yarn" { ball = nil }
    }

    private func move(to p: CGPoint, playing: Bool = false) {
        guard let id = held else { return }
        let d = hypot(p.x - heldAt.x, p.y - heldAt.y)
        heldLast = heldAt
        heldAt = p
        drawAt = playing ? p : drawn(p)
        heldMoved += d
        stepDist += d
        let tip = tipPoint()
        lookAt = tip
        switch id {
        case "sponge":
            guard over(tip), stepDist > 20 else { return }
            stepDist = 0
            if foam.count < 70 {
                let q = toPet(tip)
                foam.append(CGPoint(x: q.x + CGFloat.random(in: -14...14), y: q.y + CGFloat.random(in: -14...14)))
                hadFoam = true
            }
            spawn(.bubble, at: tip, spread: 30)
            express("happy", "grin", 0.4)
            play("bubble", 0.22, volume: 0.6)
        case "towel":
            guard over(tip), stepDist > 16 else { return }
            stepDist = 0
            let q = toPet(tip)
            let before = foam.count + wet.count
            foam.removeAll { hypot($0.x - q.x, $0.y - q.y) < 70 }
            wet.removeAll { hypot($0.x - q.x, $0.y - q.y) < 80 }
            express("happy", "smile", 0.4)
            play("whoosh", 0.35, volume: 0.4)
            if before > 0 && foam.isEmpty && wet.isEmpty { clean() }
        case "brush":
            guard over(tip), stepDist > 16 else { return }
            stepDist = 0
            spawn(.sparkle, at: tip, spread: 24)
            shine = min(1.4, shine + 0.018)
            express("happy", "smile", 0.4)
            play("sparkle", 0.3, volume: 0.45)
            if shine >= 1 && !shineAwarded {
                shineAwarded = true
                for _ in 0..<10 { spawn(.sparkle, at: headC, spread: 160) }
                fulfil(.brush, love: 1)
            }
        default:
            break
        }
    }

    private func drop(at p: CGPoint, velocity v: CGVector) {
        guard let id = held else { return }
        held = nil
        auto = []
        switch id {
        case "ball", "yarn":
            let speed = hypot(v.dx, v.dy)
            var vel = speed < 60 ? CGVector(dx: CGFloat.random(in: -120...120), dy: -300) : v
            let cap: CGFloat = 1800
            if speed > cap { vel = CGVector(dx: v.dx / speed * cap, dy: v.dy / speed * cap) }
            let start = CGPoint(x: min(max(p.x, 60), leftW - 60), y: min(p.y, floorY - 50))
            ball = Ball(id: id, p: start, v: vel, touched: t)
            play("whoosh", 0.1, volume: 0.6)
        case "bed":
            if p.x < leftW { goToSleep() }
        default:
            if foods.contains(id) {
                // not eaten: it pops back to the shelf
                spawn(.sparkle, at: p, spread: 20)
            }
        }
        lookAt = nil
    }

    /// A tap on a tray item: the tool plays itself.
    private func autoUse(_ id: String, from p: CGPoint) {
        lastTouch = t
        func pts(_ list: [(CGFloat, CGFloat)]) -> [CGPoint] { list.map { toCanvas(CGPoint(x: $0.0, y: $0.1)) } }
        let mouth = PetArt.shared.animals[kind]?.mouth ?? CGPoint(x: 300, y: 334)
        var path: [CGPoint]
        var dur = 1.6
        switch id {
        case "bed":
            if sleeping { wake() } else { goToSleep() }
            return
        case "ball", "yarn":
            pick(id, at: p)
            let target = CGPoint(x: headC.x + CGFloat.random(in: -30...30), y: headC.y - 160)
            drop(at: CGPoint(x: leftW - 80, y: 420), velocity: CGVector(dx: (target.x - (leftW - 80)) * 1.6, dy: -700))
            return
        case "sponge":
            path = pts([(300, 470), (220, 430), (380, 450), (250, 520), (360, 520), (300, 420), (230, 480), (380, 490), (300, 540)])
            dur = 2.2
        case "towel", "brush":
            path = pts([(300, 200), (220, 230), (380, 230), (240, 420), (360, 440), (260, 500), (340, 500), (300, 300)])
            dur = 2.2
        case "shower":
            path = pts([(160, 70), (440, 60), (180, 120), (420, 110), (300, 80)])
            dur = 2.6
        case "feather":
            path = pts([(470, 150), (420, 230), (480, 330), (400, 300), (470, 200), (380, 160)])
            dur = 2.4
        default:
            // a snack flies to the mouth
            path = [toCanvas(CGPoint(x: mouth.x + 40, y: mouth.y + 70))]
            dur = 0.7
        }
        pick(id, at: p)
        auto = [drawn(p)] + path   // these are where the tool itself goes
        autoStart = t
        autoDur = dur
    }

    // MARK: Things that happen

    private func hop(_ k: CGFloat) {
        guard hopY >= -1 else { return }
        hopV = -620 * k
        squashV += 2.4 * k
    }

    private func express(_ eyes: String, _ mouth: String, _ secs: Double) {
        face = (eyes, mouth, t + secs)
    }

    private func love(_ n: Int, wanted: Bool = false) {
        let cb = onLove
        DispatchQueue.main.async { cb(n, wanted) }
        for _ in 0..<(2 + n * 2) { spawn(.heart, at: headC, spread: 90) }
    }

    private func fulfil(_ w: Want, love n: Int) {
        if want == w {
            want = nil
            nextWant = t + Double.random(in: 16...28)
            for _ in 0..<24 { spawn(.confetti, at: CGPoint(x: headC.x, y: headC.y - 120), spread: 40) }
            love(n + 2, wanted: true)
        } else {
            love(n)
        }
    }

    private func eat(_ food: String) {
        held = nil
        auto = []
        chewUntil = t + 1.4
        chewFood = food
        play("pop", 0.0)
        let fav = PetSave.favorites[kind] == food
        if fav {
            express("sparkle", "grin", 2.2)
            hop(0.8)
            for _ in 0..<8 { spawn(.heart, at: headC, spread: 120) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { Sound.shared.play(.cheer, volume: 0.7) }
        } else {
            express("happy", "yum", 1.9)
        }
        fulfil(.food, love: fav ? 2 : 1)
    }

    private func clean() {
        hadFoam = false
        shakeUntil = t + 0.8
        for _ in 0..<16 { spawn(.drop, at: headC, spread: 140) }
        for _ in 0..<10 { spawn(.sparkle, at: toCanvas(CGPoint(x: 300, y: 440)), spread: 150) }
        play("sparkle", 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in self?.wet = [] }
        express("happy", "grin", 1.2)
        fulfil(.bath, love: 1)
    }

    private func goToSleep() {
        guard !sleeping else { return }
        sleeping = true
        sleepSince = t
        play("note1", 0)
        if want == .sleep { fulfil(.sleep, love: 1) }
    }

    private func wake() {
        let slept = t - sleepSince
        sleeping = false
        yawnUntil = t + 0.9
        nextWant = t + Double.random(in: 14...24)
        play("note3", 0)
        if slept > 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.hop(1)
                self?.love(1)
            }
        }
    }

    private func play(_ name: String, _ gap: Double, volume: Float = 1) {
        if let l = lastSound[name], t - l < gap { return }
        lastSound[name] = t
        guard let s = SFX(rawValue: name) else { return }
        Sound.shared.play(s, volume: volume)
    }

    private func spawn(_ kind: Bit, at p: CGPoint, spread: CGFloat) {
        guard bits.count < 260 else { return }
        let jitter = CGPoint(x: p.x + CGFloat.random(in: -spread...spread), y: p.y + CGFloat.random(in: -spread...spread) * 0.6)
        var b = Particle(kind: kind, p: jitter, v: .zero, born: t, life: 1, size: 20, color: .white)
        switch kind {
        case .heart:
            b.v = CGVector(dx: CGFloat.random(in: -40...40), dy: CGFloat.random(in: -160 ... -90))
            b.life = 1.1; b.size = CGFloat.random(in: 18...30)
            b.color = [Color(hex: 0xF45C9A), Color(hex: 0xFF8FB8), Color(hex: 0xFF6F96)].randomElement()!
        case .sparkle:
            b.v = CGVector(dx: CGFloat.random(in: -60...60), dy: CGFloat.random(in: -80...10))
            b.life = 0.7; b.size = CGFloat.random(in: 12...24)
            b.color = [Color.white, Theme.lemon, Color(hex: 0xC9B6FF)].randomElement()!
        case .bubble:
            b.v = CGVector(dx: CGFloat.random(in: -30...30), dy: CGFloat.random(in: -140 ... -60))
            b.life = 1.4; b.size = CGFloat.random(in: 10...26)
        case .crumb:
            b.v = CGVector(dx: CGFloat.random(in: -120...120), dy: CGFloat.random(in: -160 ... -40))
            b.life = 0.8; b.size = CGFloat.random(in: 5...9)
            b.color = Color(hex: 0xE9B27A)
        case .drop:
            b.v = CGVector(dx: CGFloat.random(in: -360...360), dy: CGFloat.random(in: -320 ... -60))
            b.life = 0.9; b.size = CGFloat.random(in: 8...13)
            b.color = Color(hex: 0x9CCBFF)
        case .zzz:
            b.v = CGVector(dx: 26, dy: -46)
            b.life = 2.4; b.size = CGFloat.random(in: 26...40)
        case .confetti:
            b.v = CGVector(dx: CGFloat.random(in: -340...340), dy: CGFloat.random(in: -520 ... -200))
            b.life = 1.6; b.size = CGFloat.random(in: 10...16); b.spin = Double.random(in: -8...8)
            b.color = [Color(hex: 0xF45C9A), Theme.lemon, Theme.sky, Theme.mint, Theme.lilac].randomElement()!
        case .splash:
            b.v = CGVector(dx: CGFloat.random(in: -80...80), dy: CGFloat.random(in: -120 ... -40))
            b.life = 0.4; b.size = 6
            b.color = Color(hex: 0x9CCBFF)
        }
        bits.append(b)
    }

    /// Is this point (corner space) on the pet?
    private func over(_ p: CGPoint) -> Bool {
        let q = toPet(p)
        let hx = (q.x - 300) / 170, hy = (q.y - 262) / 150
        let bx = (q.x - 300) / 145, by = (q.y - 490) / 160
        return hx * hx + hy * hy < 1 || bx * bx + by * by < 1
    }

    // MARK: Held tool drawing helpers

    private static let toolScale: CGFloat = 0.9
    private static let tips: [String: CGPoint] = ["sponge": CGPoint(x: 70, y: 104), "brush": CGPoint(x: 50, y: 48),
                                                  "towel": CGPoint(x: 70, y: 96), "shower": CGPoint(x: 44, y: 74),
                                                  "feather": CGPoint(x: 110, y: 26)]

    /// Where a tool goes for her finger at p: well above it, so her finger doesn't hide what she's doing.
    /// A tool's tip goes the shared tool lift above her finger; a snack floats the item lift above it.
    private func lifted(_ p: CGPoint) -> CGPoint {
        FingerLift.point(p, lift: foods.contains(held ?? "") ? FingerLift.item : FingerLift.tool, bottom: size.height, width: leftW)
    }

    /// Where the held thing is drawn for her finger at p, so that its tip lands on `lifted(p)`.
    private func drawn(_ p: CGPoint) -> CGPoint {
        let at = lifted(p)
        guard let id = held, let tip = Self.tips[id] else { return at }
        return CGPoint(x: at.x - (tip.x - 70) * Self.toolScale, y: at.y - (tip.y - 70) * Self.toolScale)
    }

    private func tipPoint() -> CGPoint {
        guard let id = held, let tip = Self.tips[id] else { return drawAt }
        return CGPoint(x: drawAt.x + (tip.x - 70) * Self.toolScale, y: drawAt.y + (tip.y - 70) * Self.toolScale)
    }

    // MARK: Every frame

    private func step(_ now: Double) {
        if last == 0 { last = now; nextWant = now + 10 }
        let dt = min(1.0 / 20, max(0, now - last))
        last = now
        t = now

        // auto-played tool
        if !auto.isEmpty, held != nil {
            let u = min(1, (t - autoStart) / autoDur)
            let f = u * Double(auto.count - 1)
            let i = min(auto.count - 2, Int(f))
            let r = CGFloat(f - Double(i))
            let a = auto[i], b = auto[i + 1]
            move(to: CGPoint(x: a.x + (b.x - a.x) * r, y: a.y + (b.y - a.y) * r), playing: true)
            if u >= 1 {
                let wasFood = held.map { foods.contains($0) } ?? false
                if wasFood, let h = held { eat(h) } else { drop(at: heldAt, velocity: .zero) }
            }
        }

        // the held tool, continuously
        if let id = held {
            lastTouch = t
            let tip = tipPoint()
            lookAt = tip
            if foods.contains(id) {
                let d = hypot(tip.x - mouthC.x, tip.y - mouthC.y)
                if d < 80 { eat(id) } else if d < 280 { express("sparkle", "wide", 0.2) }
            } else if id == "shower" {
                if Int(t * 40) != Int((t - dt) * 40) {
                    var b = Particle(kind: .drop, p: CGPoint(x: tip.x + CGFloat.random(in: -16...16), y: tip.y), v: CGVector(dx: CGFloat.random(in: -50...10), dy: 420),
                                     born: t, life: 2, size: CGFloat.random(in: 7...11), color: Color(hex: 0x7FB6E8))
                    b.spin = 1   // falling shower water (marked by spin 1)
                    bits.append(b)
                }
                play("bubble", 0.3, volume: 0.35)
            } else if id == "feather" {
                let d = hypot(tip.x - headC.x, tip.y - headC.y)
                if d < 230 {
                    tickle += dt
                    express("happy", "grin", 0.3)
                    tiltTarget = sin(t * 9) * 5
                    if Int(tickle * 3) != Int((tickle - dt) * 3) { spawn(.heart, at: tip, spread: 20) }
                    if tickle > 2.4 { tickle = 0; fulfil(.play, love: 1); hop(0.7); play("boing", 0) }
                } else {
                    tiltTarget = Double(max(-5, min(5, (tip.x - headC.x) / 60)))
                    let speed = hypot(heldAt.x - heldLast.x, heldAt.y - heldLast.y) / max(dt, 0.001)
                    if speed > 1400 && tip.y < headC.y - 120 { hop(0.6) }
                }
            }
        }

        // the ball
        if var b = ball {
            let r: CGFloat = b.id == "yarn" ? 40 : 42
            b.v.dy += 1500 * CGFloat(dt)
            b.p.x += b.v.dx * CGFloat(dt)
            b.p.y += b.v.dy * CGFloat(dt)
            b.angle += Double(b.v.dx * CGFloat(dt)) / Double(r) * 57
            let bounce: CGFloat = b.id == "yarn" ? 0.45 : 0.7
            if b.p.y > floorY - r {
                b.p.y = floorY - r
                if b.v.dy > 260 { play(b.id == "yarn" ? "tap" : "boing", 0.15, volume: 0.5) }
                b.v.dy = -b.v.dy * bounce
                b.v.dx *= 0.86
                if abs(b.v.dy) < 50 { b.v.dy = 0 }
            }
            if b.p.x < r { b.p.x = r; b.v.dx = abs(b.v.dx) * 0.8 }
            if b.p.x > leftW - r { b.p.x = leftW - r; b.v.dx = -abs(b.v.dx) * 0.8 }
            if b.p.y < 150 { b.p.y = 150; b.v.dy = abs(b.v.dy) * 0.5 }
            lookAt = b.p
            // the pet bops it with its head
            let top = CGPoint(x: headC.x, y: headC.y - 70)
            if hypot(b.p.x - top.x, b.p.y - top.y) < 130, b.v.dy > 0, t - b.lastHeader > 0.6, !sleeping {
                b.lastHeader = t
                b.touched = t
                b.v = CGVector(dx: CGFloat.random(in: -520...520), dy: -980)
                hop(0.9)
                express("happy", "grin", 0.6)
                play("boing", 0)
                spawn(.sparkle, at: b.p, spread: 20)
                fulfil(.play, love: 1)
            }
            ball = t - b.touched > 14 ? nil : b
        }

        // particles
        var keep: [Particle] = []
        keep.reserveCapacity(bits.count)
        for var b in bits {
            let age = t - b.born
            if age > b.life { continue }
            switch b.kind {
            case .crumb, .confetti, .splash: b.v.dy += 900 * CGFloat(dt)
            case .drop: b.v.dy += (b.spin == 1 ? 600 : 900) * CGFloat(dt)
            default: break
            }
            b.p.x += b.v.dx * CGFloat(dt)
            b.p.y += b.v.dy * CGFloat(dt)
            if b.kind == .drop && b.spin == 1 {
                if over(b.p) && b.p.y > headC.y - 160 {
                    // shower water rinses the bubbles it lands on
                    let q = toPet(b.p)
                    let before = foam.count
                    foam.removeAll { hypot($0.x - q.x, $0.y - q.y) < 64 }
                    if foam.count < before, wet.count < 18, Bool.random() { wet.append(q) }
                    if before > 0 && foam.isEmpty && hadFoam { clean() }
                    if Double.random(in: 0..<1) < 0.3 { continue }
                }
                if b.p.y > floorY { spawn(.splash, at: CGPoint(x: b.p.x, y: floorY - 4), spread: 4); continue }
            }
            keep.append(b)
        }
        bits = keep

        // chewing crumbs
        if t < chewUntil, Int(t * 5) != Int((t - dt) * 5) {
            for _ in 0..<3 { spawn(.crumb, at: mouthC, spread: 14) }
            play("pop", 0.15, volume: 0.5)
        }

        // sleeping
        dim += ((sleeping ? 1 : 0) - dim) * min(1, dt * 2.5)
        if sleeping, Int(t / 1.3) != Int((t - dt) / 1.3) {
            spawn(.zzz, at: CGPoint(x: headC.x + 110, y: headC.y - 90), spread: 6)
        }

        // the wanting bubble
        if want == nil, !sleeping, held == nil, ball == nil, t > nextWant, t - lastTouch > 4 {
            want = Want.allCases.randomElement()
            play("ding", 0, volume: 0.5)
        }

        // springs: hop, squash and stretch, tilt
        if hopY < 0 || hopV != 0 {
            hopV += 2400 * CGFloat(dt)
            hopY += hopV * CGFloat(dt)
            if hopY >= 0 {
                if hopV > 260 { squashV -= hopV * 0.004 }
                hopY = 0; hopV = 0
            }
        }
        let breathe: CGFloat = sleeping ? 1 + 0.022 * CGFloat(sin(t * 1.4)) : 1 + 0.012 * CGFloat(sin(t * 2.5))
        let target = hopY < 0 ? 1.05 : breathe
        squashV += (-(squash - target) * 300 - squashV * 13) * CGFloat(dt)
        squash = min(1.25, max(0.78, squash + squashV * CGFloat(dt)))
        if t < shakeUntil {
            tilt = sin(t * 46) * 8
        } else {
            tilt += (tiltTarget - tilt) * min(1, dt * 7)
        }
        if !touching && held == nil { tiltTarget = sleeping ? -5 : 0 }

        // eyes follow what's interesting
        var goal = CGSize.zero
        if let p = lookAt, !sleeping {
            let dx = p.x - headC.x, dy = p.y - headC.y
            let len = max(1, hypot(dx, dy))
            let m = min(9, len / 26)
            goal = CGSize(width: dx / len * m, height: dy / len * m * 0.8)
        } else if !sleeping {
            let w = sin(t * 0.37) * cos(t * 0.23)
            goal = CGSize(width: CGFloat(w) * 6, height: 0)
        }
        eyeOff.width += (goal.width - eyeOff.width) * min(1, CGFloat(dt) * 10)
        eyeOff.height += (goal.height - eyeOff.height) * min(1, CGFloat(dt) * 10)
        if held == nil && ball == nil && !touching { lookAt = nil }

        if t > nextBlink {
            blinkUntil = t + 0.14
            nextBlink = t + Double.random(in: 2.4...5.2)
        }
    }

    private func pose() -> PetPose {
        var p = PetPose()
        p.squash = squash
        p.tilt = tilt
        p.look = eyeOff
        p.flap = CGFloat(sin(t * (sleeping ? 1.5 : 6)))
        p.time = t
        if sleeping {
            p.eyes = "blink"; p.mouth = "smile"
        } else if t < yawnUntil {
            p.eyes = "tired"; p.mouth = "o"
        } else if t < chewUntil {
            p.eyes = face.map { $0.until > t ? $0.eyes : "happy" } ?? "happy"
            p.mouth = Int(t * 6) % 2 == 0 ? "yum" : "smile"
        } else if let f = face, f.until > t {
            p.eyes = f.eyes; p.mouth = f.mouth
        } else if t < blinkUntil {
            p.eyes = "blink"
        }
        if p.eyes != "open" && p.eyes != "sparkle" { p.look = .zero }
        return p
    }

    // MARK: Drawing

    func frame(_ now: Double, pet: PetLook, size: CGSize, in ctx: GraphicsContext) {
        self.size = size
        if pet.kind != kind { reset(kind: pet.kind) }
        step(now)
        let k = self.k
        let o = origin

        // night falls while it sleeps
        if dim > 0.01 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x2E2A6B).opacity(0.5 * dim)))
            for i in 0..<14 {
                let x = CGFloat((i * 137) % Int(max(1, leftW))), y = CGFloat(40 + (i * 53) % 260)
                let tw = 0.5 + 0.5 * sin(t * 2 + Double(i))
                var g = ctx
                g.opacity = dim * tw
                g.fill(Twinkle().path(in: CGRect(x: x, y: y, width: 18, height: 18)), with: .color(.white))
            }
        }

        var g = ctx
        g.translateBy(x: o.x, y: o.y + hopY)
        g.scaleBy(x: k, y: k)

        // floor shadow (shrinks as it hops)
        let sh = ctx
        let s = max(0.5, 1 + hopY / 300)
        let shadowW = 300 * k * s
        sh.fill(Path(ellipseIn: CGRect(x: o.x + 300 * k - shadowW / 2, y: floorY - 22 * k, width: shadowW, height: 48 * k * s)),
                with: .color(Theme.ink.opacity(0.16)))

        if dim > 0.02 {
            var b = ctx
            b.opacity = min(1, dim * 1.5)
            b.translateBy(x: o.x, y: o.y)
            b.scaleBy(x: k, y: k)
            PetPainter.prop("bed", at: .zero, center: .zero, in: b)
        }

        let foamNow = foam, wetNow = wet, shineNow = shine, dimNow = dim, tt = t
        PetPainter.draw(pet, pose: pose(), over: { pg in
            for (i, f) in foamNow.enumerated() {
                let wob = 1 + 0.06 * sin(tt * 3 + Double(i))
                PetPainter.prop("foam", at: f, scale: CGFloat(wob) * (0.8 + CGFloat(i % 3) * 0.15), center: .zero, in: pg)
            }
            for w in wetNow {
                let d = Path(ellipseIn: CGRect(x: w.x - 7, y: w.y - 10, width: 14, height: 20))
                pg.fill(d, with: .color(Color(hex: 0xBFE4FF).opacity(0.9)))
                pg.fill(Path(ellipseIn: CGRect(x: w.x - 3, y: w.y - 6, width: 5, height: 7)), with: .color(.white.opacity(0.9)))
            }
            if shineNow > 0.15 {
                for i in 0..<8 {
                    let a = Double(i) * 0.8 + tt * 0.6
                    let x = 300 + CGFloat(cos(a * 1.3)) * 150, y = 360 + CGFloat(sin(a)) * 200
                    let tw = 0.5 + 0.5 * sin(tt * 4 + Double(i) * 1.7)
                    var q = pg
                    q.opacity = Double(min(1, shineNow)) * tw
                    q.fill(Twinkle().path(in: CGRect(x: x - 14, y: y - 14, width: 28, height: 28)), with: .color(.white))
                }
            }
            if dimNow > 0.02 {
                var b = pg
                b.opacity = min(1, dimNow * 1.5)
                PetPainter.prop("blanket", at: .zero, center: .zero, in: b)
            }
        }, in: g)

        if let b = ball {
            let fade = min(1, max(0, 14 - (t - b.touched)))
            PetPainter.prop(b.id, at: b.p, scale: 0.86, rotation: b.angle, opacity: fade, in: ctx)
        }

        drawBits(ctx)
        drawWant(ctx)

        if let id = held {
            var sc = Self.toolScale
            if foods.contains(id) { sc = 0.82 }
            if id == "bed" {
                var m = ctx
                m.opacity = 0.9
                let r = CGRect(x: drawAt.x - 40, y: drawAt.y - 40, width: 80, height: 80)
                m.fill(Path(ellipseIn: r), with: .color(Color(hex: 0x6B6FD6)))
                m.fill(Path(ellipseIn: r.offsetBy(dx: 16, dy: -10)), with: .color(Color(hex: 0xE6E4FF)))
            } else {
                // over the pet a tool turns see-through, with a ring where its tip works
                let tip = tipPoint()
                let working = Self.tips[id] != nil && over(tip)
                var m = ctx
                if working { m.opacity = FingerLift.seeThrough }
                PetPainter.prop(id, at: drawAt, scale: sc, rotation: id == "sponge" || id == "towel" ? sin(t * 8) * 4 : 0, in: m)
                if working { FingerLift.drawTip(ctx, at: tip, time: t) }
            }
        }
    }

    private func drawBits(_ ctx: GraphicsContext) {
        for b in bits {
            let age = t - b.born
            let fadeOut = max(0, min(1, (b.life - age) / 0.35))
            var g = ctx
            g.opacity = fadeOut
            let r = CGRect(x: b.p.x - b.size / 2, y: b.p.y - b.size / 2, width: b.size, height: b.size)
            switch b.kind {
            case .heart:
                g.fill(heartPath(in: r), with: .color(b.color))
            case .sparkle:
                g.fill(Twinkle().path(in: r), with: .color(b.color))
            case .bubble:
                g.fill(Path(ellipseIn: r), with: .color(Color(hex: 0x9CCBFF).opacity(0.3)))
                g.stroke(Path(ellipseIn: r), with: .color(.white), lineWidth: 3)
                g.fill(Path(ellipseIn: CGRect(x: r.minX + b.size * 0.22, y: r.minY + b.size * 0.2, width: b.size * 0.25, height: b.size * 0.18)),
                       with: .color(.white))
            case .crumb, .splash:
                g.fill(Path(ellipseIn: r), with: .color(b.color))
            case .drop:
                var d = Path()
                d.move(to: CGPoint(x: r.midX, y: r.minY - b.size * 0.4))
                d.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX + b.size * 0.3, y: r.maxY))
                d.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY - b.size * 0.4), control: CGPoint(x: r.minX - b.size * 0.3, y: r.maxY))
                g.fill(d, with: .color(b.color))
            case .zzz:
                g.draw(Text("z").font(.system(size: b.size, weight: .heavy, design: .rounded)).foregroundColor(.white), at: b.p)
            case .confetti:
                var c = g
                c.translateBy(x: b.p.x, y: b.p.y)
                c.rotate(by: .radians(b.spin * age))
                c.fill(Path(CGRect(x: -b.size / 2, y: -b.size / 4, width: b.size, height: b.size / 2)), with: .color(b.color))
            }
        }
    }

    private func drawWant(_ ctx: GraphicsContext) {
        guard let w = want else { return }
        let c = toCanvas(CGPoint(x: 470, y: 70))
        let bob = CGFloat(sin(t * 2.4)) * 6
        var g = ctx
        g.translateBy(x: c.x, y: c.y + bob)
        let tail1 = CGRect(x: -64, y: 64, width: 22, height: 22), tail2 = CGRect(x: -86, y: 94, width: 13, height: 13)
        for r in [tail2, tail1, CGRect(x: -58, y: -58, width: 116, height: 116)] {
            g.fill(Path(ellipseIn: r), with: .color(.white))
            g.stroke(Path(ellipseIn: r), with: .color(Theme.blush), lineWidth: 4)
        }
        let icon: String
        switch w {
        case .food: icon = PetSave.favorites[kind] ?? "cookie"
        case .bath: icon = "sponge"
        case .brush: icon = "brush"
        case .play: icon = "ball"
        case .sleep: icon = ""
        }
        if icon.isEmpty {
            var m = Path()
            m.addArc(center: .zero, radius: 32, startAngle: .degrees(40), endAngle: .degrees(320), clockwise: false)
            m.addArc(center: CGPoint(x: 14, y: -6), radius: 26, startAngle: .degrees(300), endAngle: .degrees(60), clockwise: true)
            m.closeSubpath()
            g.fill(m, with: .color(Color(hex: 0x6B6FD6)))
        } else {
            PetPainter.prop(icon, at: .zero, scale: 0.68, in: g)
        }
    }

    private func heartPath(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.3), control1: CGPoint(x: r.midX - w * 0.1, y: r.maxY - h * 0.15),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.65))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY + h * 0.22), control1: CGPoint(x: r.minX, y: r.minY - h * 0.05),
                   control2: CGPoint(x: r.midX - w * 0.05, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.3), control1: CGPoint(x: r.midX + w * 0.05, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY - h * 0.05))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.minY + h * 0.65),
                   control2: CGPoint(x: r.midX + w * 0.1, y: r.maxY - h * 0.15))
        return p
    }
}

private let foods: Set<String> = ["fish", "bone", "carrot", "berry", "cookie", "cupcake"]
