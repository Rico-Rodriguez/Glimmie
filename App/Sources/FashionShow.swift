import SwiftUI

// MARK: - Fashion show (end of a Fashion Show stop)

/// She walks the runway in the outfit she made, cameras flash, and the Glimmie judges hold up hearts.
struct RunwayView: View {
    let avatar: Avatar
    let outfit: Outfit
    let judges: [Int]
    let onDone: () -> Void

    @State private var walkIn = false
    @State private var step = false
    @State private var pose = false
    @State private var cards = 0
    @State private var flashes: [Int] = []
    @State private var party = false

    /// Always three judges: her own Glimmies first, then friends.
    private var panel: [Int] {
        let own = judges.filter { Glimmies.all.indices.contains($0) }
        let extra = Glimmies.all.map(\.id).filter { !own.contains($0) }
        return Array((own + extra).prefix(3))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [Color(red: 0.26, green: 0.12, blue: 0.34), Color(red: 0.58, green: 0.26, blue: 0.52)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                spotlight.position(x: w * 0.3, y: h * 0.3).rotationEffect(.degrees(pose ? -4 : 4))
                spotlight.position(x: w * 0.7, y: h * 0.3).rotationEffect(.degrees(pose ? 4 : -4))
                FloatingSparkles()

                RunwayShape()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.78, blue: 0.9), Color(red: 0.95, green: 0.5, blue: 0.75)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RunwayShape().stroke(Color.white.opacity(0.9), lineWidth: 6))
                    .frame(width: w * 0.56, height: h * 0.42)
                    .position(x: w / 2, y: h * 0.8)

                ForEach(flashes, id: \.self) { f in
                    CameraFlash()
                        .position(x: CGFloat((f * 137) % 100) / 100 * w, y: h * (0.15 + CGFloat((f * 61) % 40) / 100))
                }

                DollView(avatar: avatar, outfit: outfit, happy: pose)
                    .frame(height: h * 0.7)
                    .rotationEffect(.degrees(walkIn && !pose ? (step ? 3 : -3) : 0), anchor: .bottom)
                    .scaleEffect(pose ? 1.06 : 1, anchor: .bottom)
                    .offset(x: walkIn ? 0 : -w * 0.75, y: step && !pose ? -8 : 0)
                    .position(x: w / 2, y: h * 0.42)

                HStack(spacing: 60) {
                    ForEach(Array(panel.enumerated()), id: \.offset) { i, g in
                        VStack(spacing: 0) {
                            scoreCard
                                .scaleEffect(i < cards ? 1 : 0.2)
                                .opacity(i < cards ? 1 : 0)
                                .offset(y: i < cards ? 0 : 40)
                                .animation(.spring(response: 0.35, dampingFraction: 0.45), value: cards)
                            GlimmieView(kind: g)
                                .frame(width: 130, height: 130)
                                .offset(y: party ? -14 : 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.35).delay(Double(i) * 0.08), value: party)
                        }
                    }
                }
                .position(x: w / 2, y: h - 120)

                if party { Confetti() }
            }
        }
        .onAppear(perform: run)
    }

    private var spotlight: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color.white.opacity(0.35), .clear], center: .center, startRadius: 4, endRadius: 260))
            .frame(width: 420, height: 720)
            .allowsHitTesting(false)
    }

    private var scoreCard: some View {
        Text("💖")
            .font(.system(size: 54))
            .frame(width: 96, height: 86)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white).shadow(color: Theme.ink.opacity(0.3), radius: 5, y: 3))
    }

    private func run() {
        Sound.shared.play(.whoosh)
        Sound.shared.say("Fashion show! Here she comes!")
        withAnimation(.easeOut(duration: 1.8)) { walkIn = true }
        withAnimation(.easeInOut(duration: 0.22).repeatCount(8, autoreverses: true)) { step = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            step = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { pose = true }
            Sound.shared.play(.sparkle)
            Sound.shared.say("Strike a pose!", interrupt: false)
            for k in 0..<6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.17) {
                    flashes.append(k + 1)
                    Sound.shared.play(.flip, volume: 0.7)
                }
            }
        }
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2 + Double(i) * 0.45) {
                cards = i + 1
                Sound.shared.play(.ding, volume: 0.8)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.7) {
            party = true
            Sound.shared.play(.fanfare)
            Sound.shared.play(.cheer, volume: 0.7)
            Sound.shared.say("The judges love it! Three hearts!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.2) { onDone() }
    }
}

/// A runway seen from the front: narrow at the back, wide at the front.
struct RunwayShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.32, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.32, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A quick white camera flash.
struct CameraFlash: View {
    @State private var go = false
    var body: some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 60, height: 60).blur(radius: 8)
            Twinkle().fill(Color.white).frame(width: 110, height: 110)
        }
        .scaleEffect(go ? 1.3 : 0.3)
        .opacity(go ? 0 : 1)
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.45)) { go = true } }
    }
}
