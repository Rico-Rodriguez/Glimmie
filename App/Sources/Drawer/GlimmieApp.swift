import SwiftUI

@main
struct GlimmieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct RootView: View {
    @State private var playing: String? = RootView.launchGame

    var body: some View {
        ZStack {
            if let id = playing, let game = GameRegistry.all.first(where: { $0.id == id }) {
                game.play { withAnimation(.easeInOut(duration: 0.35)) { playing = nil } }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            } else {
                DrawerView { id in withAnimation(.easeInOut(duration: 0.35)) { playing = id } }
                    .transition(.opacity)
            }
        }
        .onAppear {
            GameStorage.removeRetiredGameSaves()
            _ = Sound.shared
        }
    }

    /// `-game <id>` on launch opens that game directly (used for simulator screenshots).
    static var launchGame: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-game"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
