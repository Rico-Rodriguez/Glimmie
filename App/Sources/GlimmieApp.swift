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
        .fullScreenCover(isPresented: $editing) {
            AvatarMakerView { editing = false }
                .environmentObject(game)
        }
        .onAppear { _ = Sound.shared; Art.preload() }
    }
}
