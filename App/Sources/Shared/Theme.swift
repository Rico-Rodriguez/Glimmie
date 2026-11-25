import SwiftUI

extension Color {
    /// `Color(hex: 0xFF8FC4)`
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum Theme {
    static let ink = Color(hex: 0x5B3A68)
    static let cream = Color(hex: 0xFFF7F2)
    static let blush = Color(hex: 0xFFD9E6)
    static let pink = Color(hex: 0xFF8FB8)
    static let lilac = Color(hex: 0xC9B6FF)
    static let mint = Color(hex: 0x9FE3CF)
    static let sky = Color(hex: 0x9CCBFF)
    static let lemon = Color(hex: 0xFFE38A)
    static let peach = Color(hex: 0xFFC09F)
}

/// Lays a screen out at an iPad-sized design height (834 pt) and scales it to fit,
/// so one layout works on every iPad and on iPhones in landscape.
struct DesignCanvas<Content: View>: View {
    static var designHeight: CGFloat { 834 }
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let h = Self.designHeight
            let scale = max(0.1, geo.size.height / h)
            let w = max(1024, geo.size.width / scale)
            let s = min(scale, geo.size.width / w)
            content()
                .frame(width: w, height: h)
                .scaleEffect(s)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// The round "back to the drawer" button every game shows in its top-left corner.
struct HomeButton: View {
    var size: CGFloat = 72
    let action: () -> Void
    var body: some View {
        Button {
            Sound.shared.play(.whoosh, volume: 0.6)
            action()
        } label: {
            Image(systemName: "house.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.pink))
                .overlay(Circle().stroke(.white, lineWidth: 5))
                .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 4)
        }
        .buttonStyle(Squish())
        .accessibilityLabel("Home")
    }
}

/// Buttons shrink a little while pressed.
struct Squish: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
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

/// A one-shot burst of sparkles. Give it a new `.id` to play it again.
struct SparkleBurst: View {
    var colors: [Color] = [.white, Theme.lemon, Theme.pink]
    var count = 12
    var radius: CGFloat = 170
    @State private var go = false

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let a = Double(i) / Double(count) * 2 * .pi + Double(i % 3) * 0.2
                let r = radius * (0.7 + 0.3 * CGFloat(i % 3) / 2)
                Twinkle()
                    .fill(colors[i % colors.count])
                    .frame(width: CGFloat(18 + (i % 3) * 8), height: CGFloat(18 + (i % 3) * 8))
                    .offset(x: go ? cos(a) * r : 0, y: go ? sin(a) * r : 0)
                    .scaleEffect(go ? 0.3 : 1.1)
                    .opacity(go ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { go = true } }
    }
}

/// A round white button with a symbol, for top-bar actions.
struct RoundButton: View {
    let symbol: String
    var tint: Color = Theme.pink
    var size: CGFloat = 72
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(.white))
                .overlay(Circle().stroke(tint.opacity(0.35), lineWidth: 4))
                .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
        }
        .buttonStyle(Squish())
    }
}
