import SwiftUI
import Combine

// MARK: - Shared pieces

/// How a mini-game went. Stars (1...3) go in the jar; score is kept as her best.
struct GameResult {
    let stars: Int
    let score: Int
}

/// Runs one stop of the Sparkle Path full screen, then shows the stars she earned.
struct GameHost: View {
    @EnvironmentObject var game: GameState
    let play: Play
    /// Stars earned; 0 when she left early.
    let onDone: (Int) -> Void

    @State private var result: GameResult? = nil
    @State private var newBest = false

    var body: some View {
        ZStack {
            gameView
                .allowsHitTesting(result == nil)
            if result == nil, play.kind != .dress {
                VStack {
                    HStack {
                        CandyButton(symbol: "xmark", color: .white, size: 60) { onDone(0) }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.leading, 20).padding(.top, 18)
            }
            if let r = result {
                ResultView(stars: r.stars, newBest: newBest) { onDone(r.stars) }
                    .transition(.opacity)
                    .zIndex(5)
            }
        }
    }

    @ViewBuilder private var gameView: some View {
        let level = Adventure.level(at: play.stop)
        switch play.kind {
        case .catchStars:
            StarCatchView(level: level, buddy: game.buddy) { finish($0) }
        case .bubbles:
            BubblePopView(level: level) { finish($0) }
        case .memory:
            MemoryView(level: level) { finish($0) }
        case .dance:
            DanceView(level: level) { finish($0) }
        case .dress:
            BoutiqueView(onClose: { onDone(0) }, questDone: { finish(GameResult(stars: 3, score: 0)) })
        case .chest:
            Color.clear
        }
    }

    private func finish(_ r: GameResult) {
        newBest = r.score > 0 && game.record(play.kind.rawValue, score: r.score)
        withAnimation(.easeInOut(duration: 0.4)) { result = r }
    }
}

/// Stars pop in one by one, then a big check button goes back to the map.
struct ResultView: View {
    let stars: Int
    var newBest = false
    let onDone: () -> Void

    @State private var shown = 0
    @State private var appear = false

    private var words: String {
        switch stars {
        case 3: return "Amazing!"
        case 2: return "Great job!"
        default: return "Nice try!"
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.25, green: 0.12, blue: 0.3).opacity(0.55).ignoresSafeArea()
            RadialGradient(colors: [Color.white.opacity(0.7), .clear], center: .center, startRadius: 10, endRadius: 420)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 26) {
                Text(words)
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.6), radius: 0, x: 4, y: 4)
                    .shadow(color: Theme.ink.opacity(0.4), radius: 10)
                HStack(spacing: 24) {
                    ForEach(0..<3, id: \.self) { i in
                        let on = i < shown
                        StarShape()
                            .fill(on ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.6), Theme.gold],
                                                                     startPoint: .top, endPoint: .bottom))
                                     : AnyShapeStyle(Color.white.opacity(0.3)))
                            .overlay(StarShape().stroke(Color.white, lineWidth: 6))
                            .frame(width: 150, height: 150)
                            .scaleEffect(on ? 1 : 0.72)
                            .rotationEffect(.degrees(on ? 0 : -24))
                            .shadow(color: on ? Theme.gold : .clear, radius: 18)
                            .offset(y: i == 1 ? -24 : 0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.42), value: shown)
                    }
                }
                if newBest {
                    Text("🏆")
                        .font(.system(size: 70))
                        .transition(.scale)
                }
                CandyButton(symbol: "checkmark", color: Color(red: 0.6, green: 0.92, blue: 0.68), size: 104) { onDone() }
                    .opacity(shown >= stars ? 1 : 0)
                    .scaleEffect(shown >= stars ? 1 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: shown)
            }
            .scaleEffect(appear ? 1 : 0.6)
            .opacity(appear ? 1 : 0)
            if stars == 3, shown == 3 { Confetti() }
        }
        .onAppear {
            Sound.shared.play(.cheer)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
            for i in 0..<max(1, stars) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(i) * 0.45) {
                    shown = i + 1
                    Sound.shared.play(.ding, volume: 0.8)
                    Sound.shared.tapHaptic()
                }
            }
            let line: String
            switch stars {
            case 3: line = newBest ? "Amazing! Three stars! That's your best ever!" : "Amazing! Three stars!"
            case 2: line = newBest ? "Great job! Two stars! Your best ever!" : "Great job! Two stars!"
            default: line = "Nice try! One star! Let's play again soon!"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Sound.shared.say(line) }
        }
    }
}

/// "+1" text that floats up and fades.
struct FloatUpText: View {
    let text: String
    var color: Color = .white
    @State private var go = false
    var body: some View {
        Text(text)
            .font(.system(size: 44, weight: .heavy, design: .rounded))
            .foregroundColor(color)
            .shadow(color: Theme.ink.opacity(0.5), radius: 4, y: 2)
            .offset(y: go ? -80 : 0)
            .opacity(go ? 0 : 1)
            .scaleEffect(go ? 1.3 : 0.8)
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeOut(duration: 0.8)) { go = true } }
    }
}

/// Big "3, 2, 1, Go!" in the middle of the screen.
struct CountdownView: View {
    let value: Int   // 3, 2, 1, then 0 = "Go!"
    var body: some View {
        Text(value > 0 ? "\(value)" : "Go!")
            .font(.system(size: 160, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.6), radius: 0, x: 6, y: 6)
            .shadow(color: Theme.ink.opacity(0.4), radius: 14)
            .id(value)
            .transition(.scale(scale: 2).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}

/// Runs the spoken intro, then 3-2-1-Go, then calls `go`.
private func runCountdown(intro: String, set: @escaping (Int?) -> Void, go: @escaping () -> Void) {
    Sound.shared.say(intro)
    let start = 2.8
    for (i, v) in [3, 2, 1, 0].enumerated() {
        DispatchQueue.main.asyncAfter(deadline: .now() + start + Double(i) * 0.7) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { set(v) }
            Sound.shared.play(v == 0 ? .sparkle : .tap, volume: v == 0 ? 0.7 : 0.8)
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + start + 3 * 0.7 + 0.5) {
        withAnimation { set(nil) }
        go()
    }
}

// MARK: - Star Catch

/// Stars rain down; she slides her Glimmie under them. Rain clouds just make it wet.
final class CatchGame: ObservableObject {
    enum Kind { case star, heart, candy, rainbow, cloud }

    struct Drop: Identifiable {
        let id: Int
        var x: CGFloat
        var y: CGFloat
        let kind: Kind
        let speed: CGFloat
        let spin: Double
        var angle: Double = 0
    }

    struct Pop: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let text: String
        let born: Date
    }

    static let duration = 30.0

    @Published var drops: [Drop] = []
    @Published var pops: [Pop] = []
    @Published var score = 0
    @Published var timeLeft = CatchGame.duration
    @Published var playerX: CGFloat = 0
    @Published var wet = false
    @Published var munch = false

    var running = false
    var targetX: CGFloat = 0
    var size: CGSize = .zero
    var onEnd: (() -> Void)?

    let level: Int
    private var seq = 0
    private var spawnIn = 0.3
    private var last: Date?

    init(level: Int) { self.level = level }

    var playerY: CGFloat { size.height - 140 }
    private var spawnEvery: Double { max(0.4, 0.72 - Double(level) * 0.025) }
    private var baseSpeed: CGFloat { min(400, 230 + CGFloat(level) * 12) }

    func tick(_ now: Date) {
        defer { last = now }
        guard running, size.width > 0, let last else { return }
        let dt = min(0.05, now.timeIntervalSince(last))
        timeLeft = max(0, timeLeft - dt)
        playerX += (targetX - playerX) * min(1, CGFloat(dt) * 16)

        spawnIn -= dt
        if spawnIn <= 0, timeLeft > 0.8 {
            spawn()
            spawnIn = spawnEvery * Double.random(in: 0.7...1.3)
        }

        var keep: [Drop] = []
        for var d in drops {
            d.y += d.speed * CGFloat(dt)
            d.angle += d.spin * dt
            if abs(d.x - playerX) < 100, d.y > playerY - 95, d.y < playerY + 35 {
                caught(d)
                continue
            }
            if d.y < size.height + 80 { keep.append(d) }
        }
        drops = keep
        if !pops.isEmpty { pops.removeAll { now.timeIntervalSince($0.born) > 0.85 } }

        if timeLeft <= 0 {
            running = false
            drops = []
            onEnd?()
        }
    }

    private func spawn() {
        seq += 1
        let r = Double.random(in: 0..<1)
        let kind: Kind = r < 0.45 ? .star : r < 0.63 ? .heart : r < 0.78 ? .candy : r < 0.84 ? .rainbow : .cloud
        let speed = baseSpeed * CGFloat.random(in: 0.8...1.25) * (kind == .rainbow ? 1.3 : 1)
        drops.append(Drop(id: seq, x: CGFloat.random(in: 80...max(81, size.width - 80)), y: -60,
                          kind: kind, speed: speed, spin: Double.random(in: -120...120)))
    }

    private func caught(_ d: Drop) {
        seq += 1
        switch d.kind {
        case .cloud:
            wet = true
            Sound.shared.play(.boing, volume: 0.6)
            if Int.random(in: 0..<2) == 0 { Sound.shared.say(["Brr! Wet!", "Splash!", "Oh no, rain!"].randomElement()!) }
            pops.append(Pop(id: seq, x: d.x, y: playerY - 90, text: "💦", born: Date()))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.wet = false }
        case .rainbow:
            score += 3
            Sound.shared.play(.sparkle)
            Sound.shared.play(.catchIt)
            pops.append(Pop(id: seq, x: d.x, y: playerY - 90, text: "+3", born: Date()))
        default:
            score += 1
            Sound.shared.play(.catchIt, volume: 0.8)
            pops.append(Pop(id: seq, x: d.x, y: playerY - 90, text: "+1", born: Date()))
        }
        if d.kind != .cloud {
            munch = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { self.munch = false }
        }
    }

    static func emoji(_ k: Kind) -> String {
        switch k {
        case .star: return "⭐"
        case .heart: return "💖"
        case .candy: return "🍬"
        case .rainbow: return "🌈"
        case .cloud: return "🌧️"
        }
    }
}

struct StarCatchView: View {
    let level: Int
    let buddy: Int
    let onFinish: (GameResult) -> Void

    @StateObject private var g: CatchGame
    @State private var countdown: Int? = nil
    @State private var started = false
    private let clock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    init(level: Int, buddy: Int, onFinish: @escaping (GameResult) -> Void) {
        self.level = level
        self.buddy = buddy
        self.onFinish = onFinish
        _g = StateObject(wrappedValue: CatchGame(level: level))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.45, green: 0.4, blue: 0.82), Color(red: 0.95, green: 0.62, blue: 0.85)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                FloatingSparkles()
                // soft hills
                Ellipse().fill(Color(red: 0.72, green: 0.9, blue: 0.7))
                    .frame(width: geo.size.width * 1.4, height: 200)
                    .position(x: geo.size.width / 2, y: geo.size.height + 30)

                ForEach(g.drops) { d in
                    Text(CatchGame.emoji(d.kind))
                        .font(.system(size: d.kind == .rainbow ? 84 : 66))
                        .shadow(color: d.kind == .cloud ? .clear : Color.white.opacity(0.9), radius: 10)
                        .rotationEffect(.degrees(d.kind == .cloud ? 0 : d.angle))
                        .position(x: d.x, y: d.y)
                }

                ForEach(g.pops) { p in
                    FloatUpText(text: p.text, color: p.text == "+3" ? Theme.gold : .white)
                        .position(x: p.x, y: p.y)
                }

                // her Glimmie with a little basket
                ZStack {
                    GlimmieView(kind: buddy, bob: false)
                        .frame(width: 190, height: 190)
                    Text("🧺").font(.system(size: 70)).offset(y: 58)
                    if g.wet { Text("💦").font(.system(size: 54)).offset(x: 60, y: -70) }
                }
                .scaleEffect(x: g.munch ? 1.1 : 1, y: g.munch ? 0.92 : 1, anchor: .bottom)
                .rotationEffect(.degrees(g.wet ? 10 : 0))
                .animation(.spring(response: 0.2, dampingFraction: 0.45), value: g.munch)
                .animation(.spring(response: 0.25, dampingFraction: 0.3), value: g.wet)
                .position(x: g.playerX, y: g.playerY)

                // top: time left as a shrinking rainbow, and the score
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        StarShape().fill(Theme.gold).overlay(StarShape().stroke(Color.white, lineWidth: 3))
                            .frame(width: 58, height: 58)
                        Text("\(g.score)")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Theme.ink.opacity(0.5), radius: 4, y: 2)
                            .monospacedDigit()
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.4)).frame(width: 420, height: 26)
                        Capsule()
                            .fill(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(26, 420 * CGFloat(g.timeLeft / CatchGame.duration)), height: 26)
                    }
                    .overlay(Capsule().stroke(Color.white, lineWidth: 4))
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 18)

                if let c = countdown { CountdownView(value: c) }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in g.targetX = min(max(v.location.x, 90), geo.size.width - 90) }
            )
            .onAppear {
                g.size = geo.size
                g.playerX = geo.size.width / 2
                g.targetX = g.playerX
                start()
            }
            .onChange(of: geo.size) { g.size = $0 }
        }
        .onReceive(clock) { g.tick($0) }
    }

    private func start() {
        guard !started else { return }
        started = true
        g.onEnd = {
            Sound.shared.play(.fanfare, volume: 0.7)
            Sound.shared.say("Time's up! You caught \(g.score)!")
            let s = g.score
            let stars = s >= 16 ? 3 : (s >= 8 ? 2 : 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onFinish(GameResult(stars: stars, score: s)) }
        }
        runCountdown(intro: StopKind.catchStars.intro, set: { countdown = $0 }) { g.running = true }
    }
}

// MARK: - Bubble Pop

/// Bubbles float up; she pops the ones of the color the Glimmie asks for.
struct BubblePopView: View {
    let level: Int
    let onFinish: (GameResult) -> Void

    private struct Bubble: Identifiable {
        let id: Int
        let x: CGFloat
        var y: CGFloat
        let color: Int       // Palette.clothes index
        let size: CGFloat
        let speed: CGFloat
        let phase: Double
        let golden: Bool
    }

    private struct Burst: Identifiable {
        let id: Int
        let at: CGPoint
        let color: Color
        let text: String?
    }

    static let goal = 10

    @State private var bubbles: [Bubble] = []
    @State private var bursts: [Burst] = []
    @State private var target = 0
    @State private var popped = 0
    @State private var streak = 0
    @State private var mistakes = 0
    @State private var shaking: Int? = nil
    @State private var size: CGSize = .zero
    @State private var t = 0.0
    @State private var last: Date? = nil
    @State private var spawnIn = 0.0
    @State private var seq = 0
    @State private var running = false
    @State private var finished = false
    @State private var lastWrongSay = Date.distantPast
    @State private var targetPulse = false
    private let clock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    /// The colors in play: pink, blue, yellow, green; purple and orange join later.
    private var colors: [Int] { level >= 4 ? [0, 5, 3, 4, 6, 2] : [0, 5, 3, 4] }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.7, green: 0.92, blue: 1.0), Color(red: 0.86, green: 0.8, blue: 1.0)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                FloatingSparkles()

                ForEach(bubbles) { b in
                    bubbleView(b)
                        .position(x: bx(b), y: b.y)
                }
                ForEach(bursts) { b in
                    ZStack {
                        PopRing(color: b.color)
                        if let text = b.text { FloatUpText(text: text, color: Theme.gold) }
                    }
                    .position(b.at)
                }

                header
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 16)
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { v in tap(at: v.location) })
            .onAppear {
                size = geo.size
                start()
            }
            .onChange(of: geo.size) { size = $0 }
        }
        .onReceive(clock) { tick($0) }
    }

    private var header: some View {
        HStack(spacing: 24) {
            HStack(spacing: 12) {
                Text("👉").font(.system(size: 50))
                bubbleArt(color: target, golden: false)
                    .frame(width: 96, height: 96)
                    .scaleEffect(targetPulse ? 1.25 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.4), value: targetPulse)
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.85)).shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 3))
            .onTapGesture { sayTarget() }

            HStack(spacing: 6) {
                ForEach(0..<Self.goal, id: \.self) { i in
                    Circle()
                        .fill(i < popped ? Palette.clothes[target].color : Color.white.opacity(0.5))
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .frame(width: 30, height: 30)
                        .scaleEffect(i < popped ? 1.1 : 0.9)
                        .animation(.spring(response: 0.3, dampingFraction: 0.45), value: popped)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Capsule().fill(Color.white.opacity(0.6)))
        }
    }

    private func bubbleView(_ b: Bubble) -> some View {
        bubbleArt(color: b.color, golden: b.golden)
            .frame(width: b.size, height: b.size)
            .rotationEffect(.degrees(shaking == b.id ? 14 : 0))
            .animation(.spring(response: 0.12, dampingFraction: 0.2), value: shaking)
    }

    private func bubbleArt(color: Int, golden: Bool) -> some View {
        let c = golden ? Theme.gold : Palette.clothes[color].color
        return ZStack {
            Circle().fill(RadialGradient(colors: [Color.white.opacity(0.9), c.opacity(0.85), c], center: UnitPoint(x: 0.35, y: 0.3),
                                         startRadius: 2, endRadius: 80))
            Circle().stroke(Color.white.opacity(0.9), lineWidth: 4)
            Ellipse().fill(Color.white.opacity(0.8))
                .frame(width: 22, height: 14)
                .rotationEffect(.degrees(-35))
                .offset(x: -16, y: -18)
            if golden { Text("✨").font(.system(size: 34)) }
        }
        .shadow(color: c.opacity(0.6), radius: 6)
    }

    private func bx(_ b: Bubble) -> CGFloat { b.x + CGFloat(sin(t * 1.6 + b.phase)) * 22 }

    private func start() {
        target = colors.randomElement() ?? 0
        Sound.shared.say("Bubble Pop! Pop the \(Palette.clothes[target].name) bubbles!")
        // a few bubbles straight away, already part way up
        for i in 0..<5 { spawn(y: size.height * (0.45 + CGFloat(i) * 0.12)) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { running = true }
    }

    private func sayTarget() {
        targetPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { targetPulse = false }
        Sound.shared.say("Pop the \(Palette.clothes[target].name) bubbles!")
    }

    private func tick(_ now: Date) {
        defer { last = now }
        guard running, size.width > 0, let last else { return }
        let dt = min(0.05, now.timeIntervalSince(last))
        t += dt
        for i in bubbles.indices { bubbles[i].y -= bubbles[i].speed * CGFloat(dt) }
        bubbles.removeAll { $0.y < -100 }
        spawnIn -= dt
        if spawnIn <= 0 {
            spawn(y: size.height + 80)
            spawnIn = max(0.38, 0.62 - Double(level) * 0.02) * Double.random(in: 0.75...1.25)
        }
    }

    private func spawn(y: CGFloat) {
        seq += 1
        let others = colors.filter { $0 != target }
        let isTarget = Double.random(in: 0..<1) < 0.45
        let color = isTarget ? target : (others.randomElement() ?? target)
        let golden = Double.random(in: 0..<1) < 0.06
        let sz = CGFloat.random(in: 110...150)
        let speed = CGFloat.random(in: 80...120) + CGFloat(min(level, 10)) * 6
        bubbles.append(Bubble(id: seq, x: CGFloat.random(in: 90...max(91, size.width - 90)), y: y, color: color, size: sz,
                              speed: speed, phase: Double.random(in: 0...6.28), golden: golden))
    }

    private func tap(at p: CGPoint) {
        guard running, !finished else { return }
        // the front-most (last drawn) bubble under the finger, with a generous edge for small fingers
        guard let b = bubbles.last(where: { hypot(bx($0) - p.x, $0.y - p.y) < $0.size / 2 + 18 }) else { return }
        let at = CGPoint(x: bx(b), y: b.y)
        if b.golden || b.color == target {
            bubbles.removeAll { $0.id == b.id }
            seq += 1
            let gain = b.golden ? 2 : 1
            bursts.append(Burst(id: seq, at: at, color: b.golden ? Theme.gold : Palette.clothes[b.color].color, text: b.golden ? "+2" : nil))
            let id = seq
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { bursts.removeAll { $0.id == id } }
            Sound.shared.play(.bubble)
            if b.golden { Sound.shared.play(.sparkle) }
            Sound.shared.tapHaptic()
            popped = min(Self.goal, popped + gain)
            streak += 1
            if popped >= Self.goal {
                finish()
            } else if streak >= 4 {
                streak = 0
                changeTarget()
            }
        } else {
            mistakes += 1
            shaking = b.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { if shaking == b.id { shaking = nil } }
            Sound.shared.play(.boing, volume: 0.5)
            if Date().timeIntervalSince(lastWrongSay) > 2.5 {
                lastWrongSay = Date()
                Sound.shared.say("That one is \(Palette.clothes[b.color].name)! Find \(Palette.clothes[target].name)!")
            }
        }
    }

    private func changeTarget() {
        let others = colors.filter { $0 != target }
        target = others.randomElement() ?? target
        Sound.shared.play(.whoosh, volume: 0.6)
        targetPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { targetPulse = false }
        Sound.shared.say("Now pop the \(Palette.clothes[target].name) ones!")
    }

    private func finish() {
        finished = true
        Sound.shared.play(.fanfare, volume: 0.7)
        Sound.shared.say("You popped them all!")
        let stars = mistakes <= 2 ? 3 : (mistakes <= 5 ? 2 : 1)
        let score = max(1, 30 - mistakes * 3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            running = false
            onFinish(GameResult(stars: stars, score: score))
        }
    }
}

/// A ring and droplets where a bubble popped.
struct PopRing: View {
    let color: Color
    @State private var go = false
    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: go ? 2 : 10)
                .frame(width: go ? 190 : 60, height: go ? 190 : 60)
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * 2 * .pi
                Circle().fill(color)
                    .frame(width: 16, height: 16)
                    .offset(x: go ? CGFloat(cos(a)) * 100 : 0, y: go ? CGFloat(sin(a)) * 100 : 0)
            }
        }
        .opacity(go ? 0 : 1)
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { go = true } }
    }
}

// MARK: - Match Cards (memory)

struct MemoryView: View {
    let level: Int
    let onFinish: (GameResult) -> Void

    private struct Card: Identifiable {
        let id: Int
        let face: String     // Catalog item id
        var up = false
        var matched = false
    }

    @State private var cards: [Card] = []
    @State private var first: Int? = nil
    @State private var locked = false
    @State private var misses = 0
    @State private var cheer: Set<Int> = []
    @State private var bursts: [Int] = []
    @State private var done = false
    @State private var peek = true

    private var pairs: Int { level < 3 ? 3 : (level < 6 ? 4 : 6) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.96, green: 0.84, blue: 1.0), Color(red: 1.0, green: 0.8, blue: 0.88)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            FloatingSparkles()

            let cols = pairs == 3 ? 3 : 4
            let rows = (pairs * 2 + cols - 1) / cols
            let cardH: CGFloat = rows >= 3 ? 210 : 250
            let cardW: CGFloat = cardH * 0.82
            VStack(spacing: 18) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 18) {
                        ForEach(0..<cols, id: \.self) { c in
                            let i = r * cols + c
                            if i < cards.count {
                                cardView(i)
                                    .frame(width: cardW, height: cardH)
                            }
                        }
                    }
                }
            }
            .padding(.top, 40)

            ForEach(bursts, id: \.self) { _ in SparkleBurst(count: 20, radius: 260) }
        }
        .onAppear(perform: start)
    }

    private func cardView(_ i: Int) -> some View {
        let card = cards[i]
        let item = Catalog.item(card.face)
        let tint = (item?.tintable ?? false) ? Palette.clothes[item?.defaultColor ?? 0].color : nil
        let up = card.up || card.matched || peek
        return ZStack {
            // face
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(card.matched ? Theme.gold : Color(red: 1, green: 0.75, blue: 0.88), lineWidth: card.matched ? 8 : 5))
                .overlay(StickerIcon(name: card.face, tint: tint).padding(22))
                .opacity(up ? 1 : 0)
                .animation(.linear(duration: 0.01).delay(0.14), value: up)
                .rotation3DEffect(.degrees(up ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            // back
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.82), Color(red: 0.72, green: 0.6, blue: 1)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white, lineWidth: 6))
                .overlay(Twinkle().fill(Color.white.opacity(0.9)).frame(width: 70, height: 70))
                .overlay(alignment: .topLeading) { Twinkle().fill(Color.white.opacity(0.6)).frame(width: 26, height: 26).padding(18) }
                .overlay(alignment: .bottomTrailing) { Twinkle().fill(Color.white.opacity(0.6)).frame(width: 26, height: 26).padding(18) }
                .opacity(up ? 0 : 1)
                .animation(.linear(duration: 0.01).delay(0.14), value: up)
                .rotation3DEffect(.degrees(up ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .animation(.easeInOut(duration: 0.3), value: up)
        .shadow(color: card.matched ? Theme.gold.opacity(0.7) : Theme.ink.opacity(0.2), radius: card.matched ? 12 : 6, y: 4)
        .scaleEffect(cheer.contains(i) ? 1.12 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: cheer)
        .contentShape(Rectangle())
        .onTapGesture { flip(i) }
    }

    private func start() {
        guard cards.isEmpty else { return }
        let faces = Catalog.items.shuffled().prefix(pairs).map(\.id)
        cards = (faces + faces).shuffled().enumerated().map { Card(id: $0.offset, face: $0.element) }
        Sound.shared.say("Match the cards! Look carefully!")
        // a quick peek at every card, then they flip over
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            peek = false
            Sound.shared.play(.flip)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Sound.shared.say("Now find two that are the same!") }
        }
    }

    private func flip(_ i: Int) {
        guard !peek, !locked, !done, cards.indices.contains(i), !cards[i].up, !cards[i].matched else { return }
        cards[i].up = true
        Sound.shared.play(.flip)
        Sound.shared.tapHaptic()
        guard let j = first else { first = i; return }
        first = nil
        if cards[j].face == cards[i].face {
            cards[i].matched = true
            cards[j].matched = true
            cheer = [i, j]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { cheer = [] }
            bursts.append(i)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { bursts.removeAll { $0 == i } }
            Sound.shared.play(.ding)
            Sound.shared.play(.sparkle, volume: 0.5)
            if let name = Catalog.item(cards[i].face)?.name {
                Sound.shared.say(["A match!", "Yes!", "You found them!", "Same same!"].randomElement()! + " " + name + "!")
            }
            if cards.allSatisfy(\.matched) { finish() }
        } else {
            misses += 1
            locked = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                cards[i].up = false
                cards[j].up = false
                Sound.shared.play(.flip, volume: 0.6)
                locked = false
            }
        }
    }

    private func finish() {
        done = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            Sound.shared.play(.fanfare, volume: 0.7)
            Sound.shared.say("You matched them all!")
        }
        let stars = misses <= pairs ? 3 : (misses <= pairs * 2 ? 2 : 1)
        let score = max(1, pairs * 10 - misses * 2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { onFinish(GameResult(stars: stars, score: score)) }
    }
}

// MARK: - Glimmie Dance (copy the pattern)

struct DanceView: View {
    let level: Int
    let onFinish: (GameResult) -> Void

    private enum Phase { case intro, watch, yourTurn, done }

    /// The four dancers: Rosie, Bluebell, Minty and Lemony, each with their own note.
    let dancers = [0, 1, 2, 3]
    let notes: [SFX] = [.note1, .note2, .note3, .note4]

    @State private var seq: [Int] = []
    @State private var step = 0
    @State private var phase: Phase = .intro
    @State private var lit: Int? = nil
    @State private var mistakes = 0
    @State private var swing = false
    @State private var party = false
    @State private var roundToken = 0

    private var goalLength: Int { min(6, 4 + level / 6) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.34, green: 0.24, blue: 0.56), Color(red: 0.86, green: 0.45, blue: 0.78)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                discoLights(geo.size)
                Text("🪩")
                    .font(.system(size: 96))
                    .rotationEffect(.degrees(swing ? 8 : -8), anchor: .top)
                    .position(x: geo.size.width / 2, y: 70)

                VStack(spacing: 18) {
                    Spacer(minLength: 120)
                    // how far along the pattern is
                    HStack(spacing: 12) {
                        ForEach(0..<goalLength, id: \.self) { i in
                            Image(systemName: "music.note")
                                .font(.system(size: 34, weight: .heavy))
                                .foregroundColor(i < seq.count ? Theme.gold : Color.white.opacity(0.35))
                                .scaleEffect(i < seq.count ? 1.1 : 0.9)
                        }
                    }
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.18)))

                    Text(phase == .yourTurn ? "👆" : (phase == .watch ? "👀" : " "))
                        .font(.system(size: 64))
                        .frame(height: 76)

                    HStack(spacing: 26) {
                        ForEach(dancers.indices, id: \.self) { i in dancer(i) }
                    }
                    Spacer(minLength: 40)
                }
                if party { Confetti() }
            }
        }
        .onAppear(perform: start)
    }

    private func dancer(_ i: Int) -> some View {
        let on = lit == i
        let color = Glimmies.all[dancers[i]].color
        return ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color.white, color], center: .center, startRadius: 2, endRadius: 110))
                .frame(width: 200, height: 70)
                .shadow(color: on ? color : .clear, radius: 26)
                .opacity(on ? 1 : 0.6)
                .offset(y: 105)
            GlimmieView(kind: dancers[i], bob: false)
                .frame(width: 190, height: 190)
                .offset(y: on ? -46 : (party ? -20 : 0))
                .scaleEffect(on ? 1.12 : 1)
                .rotationEffect(.degrees(on ? (i % 2 == 0 ? -10 : 10) : 0))
            if on { SparkleBurst(count: 10, radius: 140, colors: [.white, color, Theme.gold]) }
        }
        .frame(width: 210, height: 300)
        .animation(.spring(response: 0.22, dampingFraction: 0.45), value: on)
        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: party)
        .contentShape(Rectangle())
        .onTapGesture { tap(i) }
    }

    private func discoLights(_ size: CGSize) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                let colors: [Color] = [.pink, .yellow, .cyan, .mint, .purple]
                Circle()
                    .fill(colors[i].opacity(0.25))
                    .frame(width: 300, height: 300)
                    .blur(radius: 40)
                    .offset(x: CGFloat(i - 2) * size.width * 0.2 + (swing ? 40 : -40), y: swing ? -60 : 60)
            }
        }
        .allowsHitTesting(false)
    }

    private func start() {
        guard seq.isEmpty else { return }
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { swing = true }
        seq = [Int.random(in: 0..<4), Int.random(in: 0..<4)]
        Sound.shared.say(StopKind.dance.intro)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { playSequence() }
    }

    private func light(_ i: Int) {
        lit = i
        Sound.shared.play(notes[i])
        let token = roundToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { if lit == i, token == roundToken { lit = nil } }
    }

    private func playSequence() {
        roundToken += 1
        let token = roundToken
        phase = .watch
        step = 0
        let gap = max(0.48, 0.68 - Double(level) * 0.01)
        for (k, d) in seq.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * gap) {
                guard token == roundToken else { return }
                light(d)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(seq.count) * gap + 0.2) {
            guard token == roundToken else { return }
            lit = nil
            phase = .yourTurn
            Sound.shared.say("Your turn!")
        }
    }

    private func tap(_ i: Int) {
        guard phase == .yourTurn else { return }
        light(i)
        Sound.shared.tapHaptic()
        if seq[step] == i {
            step += 1
            guard step == seq.count else { return }
            phase = .watch
            if seq.count >= goalLength {
                finish()
                return
            }
            Sound.shared.play(.sparkle, volume: 0.5)
            Sound.shared.say(["Yay!", "Great dancing!", "You got it!", "Woo hoo!"].randomElement()!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                seq.append(Int.random(in: 0..<4))
                playSequence()
            }
        } else {
            mistakes += 1
            phase = .watch
            Sound.shared.play(.boing, volume: 0.6)
            Sound.shared.say("Oops! Watch again!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { playSequence() }
        }
    }

    private func finish() {
        phase = .done
        party = true
        Sound.shared.play(.fanfare)
        Sound.shared.say("What a dance party!")
        let stars = mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : 1)
        let score = max(1, seq.count * 10 - mistakes * 3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { onFinish(GameResult(stars: stars, score: score)) }
    }
}
