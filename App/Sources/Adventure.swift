import SwiftUI

// MARK: - The Sparkle Path
//
// The main goal of the game: a winding path of stops through four worlds.
// Each stop is a short mini-game (or a treasure chest). Games give 1-3 stars for the jar,
// a full jar is a magic egg, chests hold new stage backdrops, and the last chest of a
// world holds an egg too. After the fourth world the path starts over, a little harder.

enum StopKind: String, CaseIterable {
    case catchStars, dress, memory, bubbles, dance, chest

    var emoji: String {
        switch self {
        case .catchStars: return "🌟"
        case .dress: return "👗"
        case .memory: return "🃏"
        case .bubbles: return "🫧"
        case .dance: return "🎵"
        case .chest: return "🎁"
        }
    }

    var title: String {
        switch self {
        case .catchStars: return "Star Catch"
        case .dress: return "Fashion Show"
        case .memory: return "Match Cards"
        case .bubbles: return "Bubble Pop"
        case .dance: return "Glimmie Dance"
        case .chest: return "Treasure"
        }
    }

    /// Spoken when the game starts: what to do, in a few words.
    var intro: String {
        switch self {
        case .catchStars: return "Star Catch! Move your Glimmie and catch the falling stars!"
        case .dress: return "Fashion show! Dress up just right, then walk the runway!"
        case .memory: return "Match the cards! Find two that are the same!"
        case .bubbles: return "Bubble Pop!"
        case .dance: return "Glimmie Dance! Watch the Glimmies, then copy them!"
        case .chest: return "A treasure chest! Tap it to open!"
        }
    }

    var color: Color {
        switch self {
        case .catchStars: return Color(red: 1.0, green: 0.84, blue: 0.4)
        case .dress: return Color(red: 1.0, green: 0.62, blue: 0.82)
        case .memory: return Color(red: 0.72, green: 0.64, blue: 1.0)
        case .bubbles: return Color(red: 0.55, green: 0.82, blue: 1.0)
        case .dance: return Color(red: 0.55, green: 0.9, blue: 0.7)
        case .chest: return Color(red: 1.0, green: 0.72, blue: 0.45)
        }
    }
}

struct World {
    let name: String
    let top: Color
    let bottom: Color
    let path: Color
    let landmark: String     // big emoji at the end of the path
    let decor: [String]      // little emoji scattered round the map
}

enum Adventure {
    static let stopsPerWorld = 12

    static let worlds: [World] = [
        World(name: "Candy Meadow", top: Color(red: 1.0, green: 0.88, blue: 0.93), bottom: Color(red: 0.78, green: 0.94, blue: 0.74),
              path: Color(red: 1.0, green: 0.72, blue: 0.84), landmark: "🍭", decor: ["🍬", "🌸", "🍩", "🌷", "🍓", "🧁"]),
        World(name: "Cloud Castle", top: Color(red: 0.74, green: 0.86, blue: 1.0), bottom: Color(red: 0.94, green: 0.9, blue: 1.0),
              path: Color(red: 0.8, green: 0.74, blue: 1.0), landmark: "🏰", decor: ["☁️", "🌈", "⭐", "🦄", "☁️", "🎈"]),
        World(name: "Mermaid Lagoon", top: Color(red: 0.62, green: 0.92, blue: 0.95), bottom: Color(red: 0.42, green: 0.74, blue: 0.92),
              path: Color(red: 1.0, green: 0.9, blue: 0.7), landmark: "🧜‍♀️", decor: ["🐚", "🐠", "🫧", "🐙", "🪸", "🐬"]),
        World(name: "Starry Sky", top: Color(red: 0.3, green: 0.26, blue: 0.55), bottom: Color(red: 0.62, green: 0.48, blue: 0.85),
              path: Color(red: 1.0, green: 0.86, blue: 0.5), landmark: "🌙", decor: ["⭐", "✨", "🪐", "🌟", "💫", "☄️"]),
    ]

    /// The 9 game stops of a world, in path order. Shifted each world so the order changes.
    private static let games: [StopKind] = [.catchStars, .dress, .memory, .bubbles, .dance, .catchStars, .memory, .dress, .bubbles]

    static func kind(at stop: Int) -> StopKind {
        let p = stop % stopsPerWorld
        if p % 4 == 3 { return .chest }
        let slot = p - p / 4           // 0...8 among the game stops
        let w = stop / stopsPerWorld
        let order: [StopKind] = w % 2 == 0 ? games : Array(games.reversed())
        return order[(slot + w * 2) % order.count]
    }

    static func world(at stop: Int) -> World { worlds[(stop / stopsPerWorld) % worlds.count] }

    /// 0 for the first stop; grows by one every 4 stops. Games read it to get a bit harder.
    static func level(at stop: Int) -> Int { stop / 4 }

    /// True for the chest at the end of a world (holds a magic egg).
    static func isWorldEnd(_ stop: Int) -> Bool { stop % stopsPerWorld == stopsPerWorld - 1 }

    /// Where each of a world's 12 stops sits on the map, as fractions of the map area.
    /// A snake from bottom-left up to the landmark at the top-right.
    static let spots: [CGPoint] = [
        CGPoint(x: 0.08, y: 0.84), CGPoint(x: 0.3, y: 0.88), CGPoint(x: 0.52, y: 0.84), CGPoint(x: 0.76, y: 0.8),
        CGPoint(x: 0.9, y: 0.6), CGPoint(x: 0.68, y: 0.52), CGPoint(x: 0.45, y: 0.56), CGPoint(x: 0.2, y: 0.5),
        CGPoint(x: 0.1, y: 0.28), CGPoint(x: 0.32, y: 0.18), CGPoint(x: 0.55, y: 0.22), CGPoint(x: 0.76, y: 0.16),
    ]
    static let landmarkSpot = CGPoint(x: 0.93, y: 0.12)
}

/// One trip into a stop, shown full screen.
struct Play: Identifiable {
    let id = UUID()
    let kind: StopKind
    let stop: Int
    /// false when replaying a stop she already passed: stars still count, the path doesn't move.
    let advances: Bool
}

// MARK: - Stage backdrops (treasure-chest rewards)

struct Backdrop: Identifiable {
    let id: String
    let name: String
    let top: Color
    let bottom: Color
    let decor: [String]
}

enum Backdrops {
    // Only append: saves keep backdrops by id.
    static let all: [Backdrop] = [
        Backdrop(id: "sea", name: "Under the Sea", top: Color(red: 0.55, green: 0.88, blue: 0.95), bottom: Color(red: 0.3, green: 0.62, blue: 0.88),
                 decor: ["🐠", "🫧", "🐚", "🪸", "🐟", "🫧", "🐙", "🫧"]),
        Backdrop(id: "castle", name: "Castle Ballroom", top: Color(red: 1.0, green: 0.86, blue: 0.68), bottom: Color(red: 0.95, green: 0.66, blue: 0.82),
                 decor: ["👑", "✨", "🕯️", "💎", "✨", "🏰", "💖", "✨"]),
        Backdrop(id: "stars", name: "Starry Night", top: Color(red: 0.22, green: 0.2, blue: 0.48), bottom: Color(red: 0.55, green: 0.4, blue: 0.78),
                 decor: ["⭐", "🌙", "✨", "🌟", "⭐", "💫", "✨", "🪐"]),
        Backdrop(id: "garden", name: "Rainbow Garden", top: Color(red: 0.75, green: 0.92, blue: 1.0), bottom: Color(red: 0.66, green: 0.9, blue: 0.62),
                 decor: ["🌈", "🌷", "🦋", "🌻", "🌸", "🐝", "🌼", "🦋"]),
        Backdrop(id: "snow", name: "Snow Land", top: Color(red: 0.82, green: 0.9, blue: 1.0), bottom: Color(red: 0.97, green: 0.98, blue: 1.0),
                 decor: ["❄️", "⛄", "❄️", "🌨️", "❄️", "🎿", "❄️", "☃️"]),
        Backdrop(id: "beach", name: "Sunny Beach", top: Color(red: 0.6, green: 0.86, blue: 1.0), bottom: Color(red: 1.0, green: 0.88, blue: 0.62),
                 decor: ["☀️", "🌴", "🐚", "🏖️", "🦀", "🌊", "⛱️", "🐚"]),
        Backdrop(id: "candy", name: "Candy Land", top: Color(red: 1.0, green: 0.8, blue: 0.9), bottom: Color(red: 0.86, green: 0.76, blue: 1.0),
                 decor: ["🍭", "🍬", "🧁", "🍩", "🍫", "🍬", "🎂", "🍭"]),
        Backdrop(id: "space", name: "Outer Space", top: Color(red: 0.1, green: 0.1, blue: 0.3), bottom: Color(red: 0.35, green: 0.2, blue: 0.5),
                 decor: ["🚀", "🪐", "⭐", "👽", "🌍", "✨", "☄️", "🛸"]),
    ]
    static func find(_ id: String) -> Backdrop? { all.first { $0.id == id } }
}

/// A stage backdrop: a soft gradient with big floating emoji decorations.
struct BackdropView: View {
    let backdrop: Backdrop
    @State private var drift = false

    // fixed spots so the decorations never jump around between redraws
    private static let spots: [(CGFloat, CGFloat, CGFloat)] = [
        (0.08, 0.18, 70), (0.3, 0.1, 54), (0.52, 0.16, 64), (0.18, 0.62, 58),
        (0.42, 0.42, 44), (0.06, 0.88, 66), (0.36, 0.82, 52), (0.6, 0.6, 48),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [backdrop.top, backdrop.bottom], startPoint: .top, endPoint: .bottom)
                ForEach(0..<min(Self.spots.count, backdrop.decor.count), id: \.self) { i in
                    let s = Self.spots[i]
                    Text(backdrop.decor[i])
                        .font(.system(size: s.2))
                        .opacity(0.85)
                        .position(x: s.0 * geo.size.width, y: s.1 * geo.size.height)
                        .offset(y: drift ? (i % 2 == 0 ? -10 : 10) : 0)
                }
                FloatingSparkles().opacity(0.7)
            }
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { drift = true } }
    }
}
