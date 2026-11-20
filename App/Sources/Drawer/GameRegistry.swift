import SwiftUI

// MARK: - Game drawer registry
//
// Every game in the drawer is one `GameEntry`. To add a game:
//   1. Put its code in App/Sources/Games/<Name>/ and its files in App/Resources/Games/<Name>/
//      (load them with `GameFiles.url("name", "png", game: "<Name>")`).
//   2. Give it a `static let entry = GameEntry(...)`.
//   3. Add that entry to `GameRegistry.all` below. Order here is the order in the drawer.
//
// Rules every game follows: no ads, no purchases, nothing locked. No system text-to-speech.
// A game keeps its own saves in `GameStorage.folder(game.id)` and never touches another game's.

struct GameEntry: Identifiable {
    /// Stable id, also the name of the game's save folder. Never change it after release.
    let id: String
    /// Short name under the tile.
    let title: String
    /// The tile's background color.
    let tint: Color
    /// The tile's picture, drawn in a square. Make it big and bold: she can't read yet.
    let icon: () -> AnyView
    /// The game's root view. Call `exit` to go back to the drawer.
    let play: (_ exit: @escaping () -> Void) -> AnyView
}

enum GameRegistry {
    static let all: [GameEntry] = [
        DressUpGame.entry,
        ColoringGame.entry,
        PetVetGame.entry,
        BakeryGame.entry,
        GardenGame.entry,
        AquariumGame.entry,
        SalonGame.entry,
        TidyGame.entry,
    ]
}
