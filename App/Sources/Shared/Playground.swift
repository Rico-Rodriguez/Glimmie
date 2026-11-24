import SwiftUI

enum PlaygroundLaunch {
    static func hasDemo(_ flags: [String]) -> Bool {
        flags.contains { ProcessInfo.processInfo.arguments.contains($0) }
    }
}

struct Playground<Stage: View, Tools: View, Classic: View>: View {
    let exit: () -> Void
    let title: String
    let classicTitle: String
    let tint: Color
    @ViewBuilder let stage: () -> Stage
    @ViewBuilder let tools: () -> Tools
    @ViewBuilder let classic: (@escaping () -> Void) -> Classic
    @State private var showingClassic = false

    var body: some View {
        if showingClassic {
            classic { showingClassic = false }
        } else {
            DesignCanvas {
                VStack(spacing: 16) {
                    HStack {
                        HomeButton(action: exit)
                        Spacer()
                        Text(title).font(.system(size: 38, weight: .heavy, design: .rounded))
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        PlaygroundButton(title: classicTitle, icon: "square.grid.2x2") { showingClassic = true }
                    }
                    stage()
                        .frame(width: 950, height: 580)
                        .clipShape(RoundedRectangle(cornerRadius: 36))
                        .overlay {
                            RoundedRectangle(cornerRadius: 36).strokeBorder(.white.opacity(0.8), lineWidth: 5)
                                .allowsHitTesting(false)
                        }
                    HStack(spacing: 12) { tools() }
                }
                .padding(28)
                .frame(width: 1024)
                .foregroundStyle(Theme.ink)
            }
            .background(LinearGradient(colors: [.white, tint], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        }
    }
}

struct PlaygroundButton: View {
    let title: String
    let icon: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button {
            Sound.shared.play(.whoosh, volume: 0.35)
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(selected ? Theme.lemon : .white, in: Capsule())
        }
        .buttonStyle(Squish())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension GraphicsContext {
    func playgroundDot(_ point: CGPoint, radius: CGFloat, color: Color) {
        fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                    width: radius * 2, height: radius * 2)), with: .color(color))
    }
}
