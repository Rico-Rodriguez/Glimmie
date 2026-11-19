import SwiftUI

enum DressUpGame {
    static let entry = GameEntry(
        id: "dressup",
        title: "Dress Up",
        tint: Color(hex: 0xFF9EC0),
        icon: { AnyView(DressUpTileIcon()) },
        play: { exit in AnyView(DressUpView(exit: exit)) }
    )
}

/// The drawer tile shows her own doll, as she last dressed it.
private struct DressUpTileIcon: View {
    var body: some View {
        let look = (GameStorage.load(Look.self, game: LookStore.game, file: "current.json") ?? .starter).sanitized()
        DollView(look: look, box: CGRect(x: 100, y: 50, width: 400, height: 470))
            .padding(-14)
    }
}
