import SwiftUI

enum DressUpGame {
    static let entry = GameEntry(
        id: "dressup",
        title: "Dress Up",
        tint: Theme.pink,
        icon: { AnyView(Image(systemName: "tshirt.fill").resizable().scaledToFit().foregroundStyle(.white).padding(30)) },
        play: { exit in AnyView(ZStack { Theme.cream.ignoresSafeArea(); HomeButton(action: exit) }) }
    )
}
