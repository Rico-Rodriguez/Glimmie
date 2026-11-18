import SwiftUI

// MARK: - Glimmie House catalog

/// A snack the child can feed a Glimmie.
struct Food: Identifiable {
    let id: String
    let emoji: String
    let name: String    // spoken, e.g. "strawberry"
    let loves: String   // spoken, e.g. "I love strawberries!"
}

/// Something a Glimmie can wear. Positions are fractions of the square Glimmie canvas.
struct PetAccessory: Identifiable {
    let id: String
    let name: String
    let art: String?    // icon art name (I_/B_ prefix added); nil = drawn sunglasses
    let width: CGFloat
    let x: CGFloat
    let y: CGFloat
    let tinted: Bool
}

enum CareMode: String, CaseIterable, Identifiable {
    case feed, bath, dress
    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .feed: return "🍓"
        case .bath: return "🧽"
        case .dress: return "🎀"
        }
    }
    var color: Color {
        switch self {
        case .feed: return Color(red: 1.0, green: 0.72, blue: 0.62)
        case .bath: return Color(red: 0.62, green: 0.84, blue: 1.0)
        case .dress: return Color(red: 0.98, green: 0.7, blue: 0.9)
        }
    }
    var spoken: String {
        switch self {
        case .feed: return "Snacks!"
        case .bath: return "Bath time!"
        case .dress: return "Dress up!"
        }
    }
}

enum Need: CaseIterable, Identifiable {
    case tummy, clean, love
    var id: Self { self }
    var emoji: String {
        switch self {
        case .tummy: return "🍓"
        case .clean: return "🫧"
        case .love: return "💗"
        }
    }
    var color: Color {
        switch self {
        case .tummy: return Color(red: 1.0, green: 0.6, blue: 0.55)
        case .clean: return Color(red: 0.5, green: 0.78, blue: 1.0)
        case .love: return Color(red: 1.0, green: 0.55, blue: 0.8)
        }
    }
    var mode: CareMode {
        switch self {
        case .tummy: return .feed
        case .clean: return .bath
        case .love: return .dress
        }
    }
}

enum HouseCatalog {
    static let foods: [Food] = [
        Food(id: "strawberry", emoji: "🍓", name: "strawberry", loves: "I love strawberries!"),
        Food(id: "apple", emoji: "🍎", name: "apple", loves: "Crunchy apple!"),
        Food(id: "banana", emoji: "🍌", name: "banana", loves: "Bananas are yummy!"),
        Food(id: "cupcake", emoji: "🧁", name: "cupcake", loves: "A sweet cupcake!"),
        Food(id: "cookie", emoji: "🍪", name: "cookie", loves: "Cookie! Nom nom!"),
        Food(id: "watermelon", emoji: "🍉", name: "watermelon", loves: "Juicy watermelon!"),
    ]
    static let accessories: [PetAccessory] = [
        PetAccessory(id: "crown", name: "crown", art: "hat_crown", width: 0.34, x: 0.5, y: 0.25, tinted: false),
        PetAccessory(id: "flowers", name: "flower crown", art: "hat_flowers", width: 0.52, x: 0.5, y: 0.31, tinted: false),
        PetAccessory(id: "bow", name: "bow", art: "hat_bow", width: 0.27, x: 0.66, y: 0.31, tinted: true),
        PetAccessory(id: "stars", name: "star clips", art: "hat_star", width: 0.46, x: 0.5, y: 0.33, tinted: false),
        PetAccessory(id: "glasses", name: "sunglasses", art: nil, width: 0.44, x: 0.5, y: 0.535, tinted: false),
    ]
    static func food(_ id: String) -> Food? { foods.first { $0.id == id } }
    static func accessory(_ id: String) -> PetAccessory? { accessories.first { $0.id == id } }

    /// Bow color that stands out on each Glimmie.
    static func bowColor(for kind: Int) -> Color {
        kind == 0 || kind == 6 ? Palette.clothes[6].color : Palette.clothes[0].color
    }
}

// MARK: - Care state

/// How one Glimmie is doing. Each need is 0...1 and slowly drains from `at`.
struct PetCare: Codable, Equatable {
    var tummy = 0.25
    var clean = 0.35
    var love = 0.3
    var at = Date()
    var wearing: String? = nil

    init(tummy: Double = 0.25, clean: Double = 0.35, love: Double = 0.3, at: Date = Date(), wearing: String? = nil) {
        self.tummy = tummy; self.clean = clean; self.love = love; self.at = at; self.wearing = wearing
    }

    // Tolerant decoding: a field added in a later update never wipes saved care.
    private enum CodingKeys: String, CodingKey { case tummy, clean, love, at, wearing }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tummy = (try? c.decodeIfPresent(Double.self, forKey: .tummy)) ?? 0.25
        clean = (try? c.decodeIfPresent(Double.self, forKey: .clean)) ?? 0.35
        love = (try? c.decodeIfPresent(Double.self, forKey: .love)) ?? 0.3
        at = (try? c.decodeIfPresent(Date.self, forKey: .at)) ?? Date()
        wearing = (try? c.decodeIfPresent(String.self, forKey: .wearing)) ?? nil
    }

    func value(_ n: Need) -> Double {
        switch n {
        case .tummy: return tummy
        case .clean: return clean
        case .love: return love
        }
    }
    var lowest: Need { Need.allCases.min { value($0) < value($1) } ?? .tummy }
    var lowestValue: Double { value(lowest) }
    var allHappy: Bool { tummy >= 0.95 && clean >= 0.95 && love >= 0.95 }
}

final class HouseState: ObservableObject {
    /// A full need drains to empty over this many hours (gentle: a day away never feels like neglect).
    static let hoursToEmpty = 10.0
    private static let key = "glimmie.house.v1"

    @Published private(set) var pets: [Int: PetCare] = [:]

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetSave") { UserDefaults.standard.removeObject(forKey: Self.key) }
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Int: PetCare].self, from: data) {
            pets = saved
        }
        if args.contains("-demoHouse") {
            pets[0] = PetCare(tummy: 0.15, clean: 0.2, love: 0.55, at: Date(), wearing: "bow")
            pets[1] = PetCare(tummy: 0.9, clean: 0.9, love: 0.2, at: Date(), wearing: nil)
        }
    }

    /// The pet's needs right now.
    func care(_ id: Int, now: Date = Date()) -> PetCare {
        var p = pets[id] ?? PetCare()
        let drain = max(0, now.timeIntervalSince(p.at)) / 3600 / Self.hoursToEmpty
        p.tummy = max(0, p.tummy - drain)
        p.clean = max(0, p.clean - drain)
        p.love = max(0, p.love - drain)
        p.at = max(p.at, now)
        return p
    }

    func update(_ id: Int, _ change: (inout PetCare) -> Void) {
        var p = care(id)
        change(&p)
        p.tummy = min(1, max(0, p.tummy))
        p.clean = min(1, max(0, p.clean))
        p.love = min(1, max(0, p.love))
        pets[id] = p
        save()
    }

    func resetAll() {
        pets = [:]
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pets) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}
