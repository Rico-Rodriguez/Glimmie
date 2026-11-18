import SwiftUI

@main
struct GlimmieApp: App {
    @StateObject private var game = GameState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var game: GameState
    @State private var editing = false

    var body: some View {
        DesignCanvas {
            ZStack {
                if game.madeAvatar {
                    BoutiqueView { editing = true }
                        .transition(.opacity)
                } else {
                    AvatarMakerView { }
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: game.madeAvatar)
        }
        .fullScreenCover(isPresented: $editing) {
            DesignCanvas { AvatarMakerView { editing = false } }
                .environmentObject(game)
        }
        .onAppear { _ = Sound.shared; Art.preload() }
    }
}

/// Lays the UI out at an iPad-sized design height (834 pt) and scales it to fit the screen,
/// so the same layout works on every iPad and on iPhones in landscape.
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
        .background(DreamyBackground())
    }
}
