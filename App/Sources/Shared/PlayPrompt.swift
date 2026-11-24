import SwiftUI

/// A single reachable control for starting a round or putting a selected tool away.
struct PlayPrompt<Icon: View>: View {
    let title: String
    let actionSymbol: String
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon().frame(width: 56, height: 48)
                Text(title).font(.system(size: 23, weight: .bold, design: .rounded))
                Image(systemName: actionSymbol).font(.system(size: 18, weight: .bold))
            }
            .padding(.horizontal, 18)
            .frame(height: 62)
            .foregroundStyle(Theme.ink)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 3))
        }
        .buttonStyle(Squish())
    }
}
