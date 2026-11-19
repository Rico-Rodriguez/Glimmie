import SwiftUI

/// The home screen: a toy drawer with one big tile per game.
struct DrawerView: View {
    let open: (String) -> Void

    var body: some View {
        ZStack {
            DrawerBackground()
            DesignCanvas {
                VStack(spacing: 0) {
                    Title()
                        .padding(.top, 54)
                    Spacer(minLength: 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 44) {
                            ForEach(GameRegistry.all) { game in
                                GameTile(game: game) {
                                    Sound.shared.play(.pop)
                                    Sound.shared.tap()
                                    open(game.id)
                                }
                            }
                        }
                        .padding(.horizontal, 70)
                        .padding(.vertical, 30)
                        .frame(minWidth: 1024)
                    }
                    Spacer(minLength: 60)
                }
            }
        }
    }
}

private struct Title: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles").foregroundStyle(Theme.lemon)
            Text("Glimmie")
                .foregroundStyle(Theme.ink)
            Image(systemName: "sparkles").foregroundStyle(Theme.lemon)
        }
        .font(.system(size: 64, weight: .heavy, design: .rounded))
        .shadow(color: .white, radius: 0, x: 0, y: 3)
    }
}

private struct GameTile: View {
    let game: GameEntry
    let tap: () -> Void
    @State private var bob = false

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 56, style: .continuous)
                        .fill(game.tint.gradient)
                    game.icon()
                        .padding(26)
                }
                .frame(width: 300, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 56, style: .continuous).stroke(.white, lineWidth: 10))
                .shadow(color: Theme.ink.opacity(0.22), radius: 14, y: 10)
                .offset(y: bob ? -6 : 4)

                Text(game.title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }
        }
        .buttonStyle(Squish())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                .delay(Double(abs(game.id.hashValue % 7)) * 0.15)) { bob = true }
        }
    }
}

/// Soft cream with pastel polka dots.
struct DrawerBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF1F6), Color(hex: 0xF3ECFF)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let colors = [Theme.blush, Color(hex: 0xE4DBFF), Color(hex: 0xD8F3EA), Color(hex: 0xFFF0C4)]
            let step: CGFloat = 70
            var row = 0
            var y: CGFloat = 20
            while y < size.height + step {
                var x: CGFloat = row % 2 == 0 ? 20 : 20 + step / 2
                var i = row
                while x < size.width + step {
                    let r: CGFloat = 9
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(colors[i % colors.count]))
                    x += step
                    i += 1
                }
                y += step * 0.866
                row += 1
            }
        }
        .ignoresSafeArea()
    }
}
