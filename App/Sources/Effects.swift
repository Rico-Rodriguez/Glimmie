import SwiftUI

// MARK: - Theme

enum Theme {
    static let ink = Color(red: 0.36, green: 0.22, blue: 0.42)
    static let pinkTop = Color(red: 1.0, green: 0.86, blue: 0.93)
    static let pinkBottom = Color(red: 0.96, green: 0.74, blue: 0.9)
    static let lilac = Color(red: 0.86, green: 0.8, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.32)
    static let panel = Color.white.opacity(0.72)
}

/// A four-point twinkle star.
struct Twinkle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let R = min(r.width, r.height) / 2, k = R * 0.22
        p.move(to: CGPoint(x: c.x, y: c.y - R))
        p.addQuadCurve(to: CGPoint(x: c.x + R, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + R), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - R, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - R), control: CGPoint(x: c.x - k, y: c.y - k))
        return p
    }
}

/// Five-point star.
struct StarShape: Shape {
    var inner: CGFloat = 0.45
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2
        for i in 0..<10 {
            let a = Double(i) * .pi / 5 - .pi / 2
            let rr = i % 2 == 0 ? R : R * inner
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Backgrounds

/// Dreamy gradient with slowly drifting sparkles.
struct DreamyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pinkTop, Theme.lilac.opacity(0.9), Theme.pinkBottom],
                           startPoint: .top, endPoint: .bottom)
            FloatingSparkles()
        }
        .ignoresSafeArea()
    }
}

struct FloatingSparkles: View {
    private struct Seed { let x, y, size, speed, phase: Double; let hue: Int }
    @State private var seeds: [Seed] = (0..<34).map { _ in
        Seed(x: .random(in: 0...1), y: .random(in: 0...1), size: .random(in: 6...18),
             speed: .random(in: 0.012...0.035), phase: .random(in: 0...(2 * .pi)), hue: .random(in: 0..<3))
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for s in seeds {
                    let y = (s.y - t * s.speed).truncatingRemainder(dividingBy: 1)
                    let yy = (y < 0 ? y + 1 : y) * (size.height + 40) - 20
                    let xx = s.x * size.width + sin(t * 0.6 + s.phase) * 18
                    let tw = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 2.2 + s.phase))
                    let d = s.size * tw
                    let rect = CGRect(x: xx - d / 2, y: yy - d / 2, width: d, height: d)
                    let col: Color = [Color.white, Theme.gold.opacity(0.9), Color(red: 1, green: 0.7, blue: 0.9)][s.hue]
                    ctx.opacity = 0.55 + 0.45 * tw
                    ctx.fill(Twinkle().path(in: rect), with: .color(col))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Soft spotlight + round stage under the avatar.
struct StageFloor: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0.4), .clear],
                                     center: .center, startRadius: 4, endRadius: 260))
                .frame(width: 520, height: 130)
            Ellipse()
                .stroke(Color.white.opacity(0.8), lineWidth: 4)
                .frame(width: 400, height: 80)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Bursts

/// Particles that fly out from the center and fade.
struct SparkleBurst: View {
    var count = 16
    var radius: CGFloat = 160
    var colors: [Color] = [.white, Theme.gold, Color(red: 1, green: 0.6, blue: 0.85), Color(red: 0.7, green: 0.8, blue: 1)]
    @State private var go = false
    @State private var parts: [(Double, CGFloat, CGFloat, Int)] = (0..<24).map { _ in
        (.random(in: 0...(2 * .pi)), .random(in: 0.55...1.0), .random(in: 12...30), .random(in: 0..<4))
    }

    var body: some View {
        ZStack {
            ForEach(0..<min(count, parts.count), id: \.self) { i in
                let p = parts[i]
                Twinkle()
                    .fill(colors[p.3 % colors.count])
                    .frame(width: p.2, height: p.2)
                    .shadow(color: .white, radius: 4)
                    .offset(x: go ? CGFloat(cos(p.0)) * radius * p.1 : 0,
                            y: go ? CGFloat(sin(p.0)) * radius * p.1 : 0)
                    .scaleEffect(go ? 0.3 : 1.2)
                    .opacity(go ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { go = true } }
    }
}

/// Confetti that rains down over the whole screen.
struct Confetti: View {
    private struct Bit { let x, delay, spin, drift, w: Double; let color: Color; let round: Bool }
    @State private var bits: [Bit] = (0..<90).map { _ in
        Bit(x: .random(in: 0...1), delay: .random(in: 0...0.6), spin: .random(in: 2...7),
            drift: .random(in: -60...60), w: .random(in: 8...16),
            color: [Color(red: 1, green: 0.5, blue: 0.75), Theme.gold, Color(red: 0.55, green: 0.75, blue: 1),
                    Color(red: 0.6, green: 0.9, blue: 0.7), Color(red: 0.8, green: 0.6, blue: 1), .white].randomElement()!,
            round: .random())
    }
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                for b in bits {
                    let tt = t - b.delay
                    guard tt > 0 else { continue }
                    let y = -30 + tt * (size.height * 0.42)
                    guard y < size.height + 30 else { continue }
                    let x = b.x * size.width + sin(tt * 2 + b.drift) * 30 + b.drift * tt * 0.4
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(tt * b.spin))
                    c.scaleBy(x: 1, y: abs(cos(tt * b.spin * 0.8)) * 0.8 + 0.2)
                    let r = CGRect(x: -b.w / 2, y: -b.w / 3, width: b.w, height: b.w * 0.66)
                    c.fill(b.round ? Path(ellipseIn: r) : Path(roundedRect: r, cornerRadius: 2), with: .color(b.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Egg

struct EggShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height, x = r.minX, y = r.minY
        p.move(to: CGPoint(x: x + w * 0.5, y: y))
        p.addCurve(to: CGPoint(x: x + w, y: y + h * 0.62),
                   control1: CGPoint(x: x + w * 0.82, y: y), control2: CGPoint(x: x + w, y: y + h * 0.34))
        p.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h),
                   control1: CGPoint(x: x + w, y: y + h * 0.88), control2: CGPoint(x: x + w * 0.78, y: y + h))
        p.addCurve(to: CGPoint(x: x, y: y + h * 0.62),
                   control1: CGPoint(x: x + w * 0.22, y: y + h), control2: CGPoint(x: x, y: y + h * 0.88))
        p.addCurve(to: CGPoint(x: x + w * 0.5, y: y),
                   control1: CGPoint(x: x, y: y + h * 0.34), control2: CGPoint(x: x + w * 0.18, y: y))
        return p
    }
}

/// A zig-zag crack across the egg; `amount` 0...3 grows it.
struct CrackShape: Shape {
    var amount: Int
    func path(in r: CGRect) -> Path {
        var p = Path()
        guard amount > 0 else { return p }
        let pts: [CGPoint] = [
            CGPoint(x: 0.08, y: 0.5), CGPoint(x: 0.22, y: 0.42), CGPoint(x: 0.32, y: 0.55), CGPoint(x: 0.45, y: 0.43),
            CGPoint(x: 0.56, y: 0.56), CGPoint(x: 0.68, y: 0.44), CGPoint(x: 0.8, y: 0.55), CGPoint(x: 0.92, y: 0.47),
        ]
        let n = min(pts.count, 1 + amount * 3)
        let mid = pts.count / 2
        let lo = max(0, mid - n / 2), hi = min(pts.count - 1, lo + n - 1)
        for i in lo...hi {
            let pt = CGPoint(x: r.minX + pts[i].x * r.width, y: r.minY + pts[i].y * r.height)
            if i == lo { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

struct EggView: View {
    var cracks: Int
    var body: some View {
        ZStack {
            EggShape()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.98), Color(red: 1, green: 0.82, blue: 0.92), Color(red: 0.86, green: 0.74, blue: 1)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    // pastel spots and stars
                    ZStack {
                        Circle().fill(Color(red: 1, green: 0.7, blue: 0.85)).frame(width: 34, height: 34).offset(x: -46, y: 30)
                        Circle().fill(Color(red: 0.7, green: 0.85, blue: 1)).frame(width: 26, height: 26).offset(x: 50, y: -10)
                        Circle().fill(Color(red: 0.75, green: 0.95, blue: 0.8)).frame(width: 22, height: 22).offset(x: 20, y: 74)
                        StarShape().fill(Theme.gold).frame(width: 40, height: 40).offset(x: -18, y: -58)
                        StarShape().fill(Color(red: 1, green: 0.75, blue: 0.9)).frame(width: 28, height: 28).offset(x: 54, y: 58)
                        Twinkle().fill(Color.white).frame(width: 30, height: 30).offset(x: -40, y: -90)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(EggShape())
                )
                .overlay(
                    Ellipse().fill(Color.white.opacity(0.55))
                        .frame(width: 46, height: 80).rotationEffect(.degrees(24))
                        .offset(x: -48, y: -46).blur(radius: 4)
                )
                .shadow(color: Theme.ink.opacity(0.25), radius: 16, y: 10)
            CrackShape(amount: cracks)
                .stroke(Theme.ink.opacity(0.75), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 200, height: 250)
    }
}

// MARK: - Buttons

/// Big round candy button used for icon-only controls.
struct CandyButton: View {
    let symbol: String
    var color: Color = .white
    var size: CGFloat = 64
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            Sound.shared.play(.tap, volume: 0.6)
            action()
        } label: {
            ZStack {
                Circle().fill(color)
                    .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.7), .clear], startPoint: .top, endPoint: .center)).padding(4))
                    .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 4)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(SquishStyle())
    }
}

struct SquishStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// Round color dot.
struct ColorDot: View {
    let color: Color
    var selected: Bool
    var size: CGFloat = 46
    var body: some View {
        Circle()
            .fill(color)
            .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .center)).padding(5))
            .overlay(Circle().stroke(Color.white, lineWidth: selected ? 5 : 3))
            .overlay(Circle().stroke(Theme.ink.opacity(selected ? 0.7 : 0.12), lineWidth: selected ? 3 : 1).padding(-3))
            .shadow(color: Theme.ink.opacity(0.2), radius: 3, y: 2)
            .frame(width: size, height: size)
            .scaleEffect(selected ? 1.12 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selected)
    }
}
