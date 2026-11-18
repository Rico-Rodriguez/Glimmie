import SwiftUI

// MARK: - Colors

struct Swatch: Identifiable, Hashable {
    let id: Int
    let name: String
    let color: Color
}

private func rgb(_ hex: UInt32) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255,
          green: Double((hex >> 8) & 0xFF) / 255,
          blue: Double(hex & 0xFF) / 255)
}

enum Palette {
    /// Clothing colors. Layers are rendered near-white and multiplied by these.
    static let clothes: [Swatch] = [
        Swatch(id: 0, name: "pink", color: rgb(0xFF8FC4)),
        Swatch(id: 1, name: "red", color: rgb(0xFF6470)),
        Swatch(id: 2, name: "orange", color: rgb(0xFFB25C)),
        Swatch(id: 3, name: "yellow", color: rgb(0xFFE36B)),
        Swatch(id: 4, name: "green", color: rgb(0x8EE08A)),
        Swatch(id: 5, name: "blue", color: rgb(0x7DB4FF)),
        Swatch(id: 6, name: "purple", color: rgb(0xB993FF)),
        Swatch(id: 7, name: "white", color: rgb(0xFFFFFF)),
    ]
    static let skin: [Swatch] = [
        Swatch(id: 0, name: "peach", color: rgb(0xFFE2D0)),
        Swatch(id: 1, name: "rosy", color: rgb(0xF6C9AE)),
        Swatch(id: 2, name: "honey", color: rgb(0xE0A97F)),
        Swatch(id: 3, name: "caramel", color: rgb(0xB97E57)),
        Swatch(id: 4, name: "cocoa", color: rgb(0x8A5A3D)),
    ]
    static let hair: [Swatch] = [
        Swatch(id: 0, name: "golden", color: rgb(0xFFD36E)),
        Swatch(id: 1, name: "brown", color: rgb(0x9A6440)),
        Swatch(id: 2, name: "black", color: rgb(0x4A3A44)),
        Swatch(id: 3, name: "red", color: rgb(0xE8774E)),
        Swatch(id: 4, name: "pink", color: rgb(0xFF9AD0)),
        Swatch(id: 5, name: "purple", color: rgb(0xB48CFF)),
        Swatch(id: 6, name: "blue", color: rgb(0x79C3FF)),
        Swatch(id: 7, name: "mint", color: rgb(0x86E6C4)),
    ]
    static let eyes: [Swatch] = [
        Swatch(id: 0, name: "blue", color: rgb(0x6FA2F0)),
        Swatch(id: 1, name: "brown", color: rgb(0xB0784E)),
        Swatch(id: 2, name: "green", color: rgb(0x6CCB86)),
        Swatch(id: 3, name: "purple", color: rgb(0xB27CF0)),
        Swatch(id: 4, name: "pink", color: rgb(0xF07CB4)),
    ]
}

// MARK: - Catalog

enum Category: String, CaseIterable, Codable, Identifiable {
    case dress, shoes, hat, hold, wings
    var id: String { rawValue }
    /// Generic noun used in wishes ("a blue dress").
    var noun: String {
        switch self {
        case .dress: return "dress"
        case .shoes: return "shoes"
        case .hat: return "hat"
        case .hold: return "something to hold"
        case .wings: return "wings"
        }
    }
    var tabIcon: String {
        switch self {
        case .dress: return "dress_aline"
        case .shoes: return "shoes_mary"
        case .hat: return "hat_bow"
        case .hold: return "hold_wand"
        case .wings: return "wings_fairy"
        }
    }
    var tabColor: Color {
        switch self {
        case .dress: return rgb(0xFF9AC8)
        case .shoes: return rgb(0xFFC37A)
        case .hat: return rgb(0xB9A2FF)
        case .hold: return rgb(0x8ED7FF)
        case .wings: return rgb(0x98E3B5)
        }
    }
}

struct Item: Identifiable, Hashable {
    let id: String          // layer name, e.g. "dress_aline"
    let category: Category
    let name: String        // spoken name, e.g. "princess gown"
    let tintable: Bool
    let defaultColor: Int   // default clothing palette index for tintable items
    let plural: Bool
}

enum Catalog {
    static let items: [Item] = [
        Item(id: "dress_aline", category: .dress, name: "sundress", tintable: true, defaultColor: 0, plural: false),
        Item(id: "dress_tutu", category: .dress, name: "tutu", tintable: true, defaultColor: 6, plural: false),
        Item(id: "dress_gown", category: .dress, name: "princess gown", tintable: true, defaultColor: 5, plural: false),
        Item(id: "dress_puff", category: .dress, name: "puffy dress", tintable: true, defaultColor: 3, plural: false),
        Item(id: "shoes_mary", category: .shoes, name: "party shoes", tintable: true, defaultColor: 1, plural: true),
        Item(id: "shoes_boots", category: .shoes, name: "boots", tintable: true, defaultColor: 6, plural: true),
        Item(id: "hat_crown", category: .hat, name: "crown", tintable: false, defaultColor: 0, plural: false),
        Item(id: "hat_flowers", category: .hat, name: "flower crown", tintable: false, defaultColor: 0, plural: false),
        Item(id: "hat_star", category: .hat, name: "star clips", tintable: false, defaultColor: 0, plural: true),
        Item(id: "hat_bow", category: .hat, name: "bow", tintable: true, defaultColor: 0, plural: false),
        Item(id: "hat_ears", category: .hat, name: "bunny ears", tintable: true, defaultColor: 7, plural: true),
        Item(id: "hold_wand", category: .hold, name: "magic wand", tintable: false, defaultColor: 0, plural: false),
        Item(id: "hold_bouquet", category: .hold, name: "bouquet", tintable: false, defaultColor: 0, plural: false),
        Item(id: "hold_balloon", category: .hold, name: "balloon", tintable: true, defaultColor: 1, plural: false),
        Item(id: "hold_purse", category: .hold, name: "purse", tintable: true, defaultColor: 0, plural: false),
        Item(id: "wings_fairy", category: .wings, name: "fairy wings", tintable: true, defaultColor: 6, plural: true),
    ]
    static func item(_ id: String) -> Item? { items.first { $0.id == id } }
    static func items(in c: Category) -> [Item] { items.filter { $0.category == c } }

    static let hairStyles = ["hair_curls", "hair_long", "hair_buns"]
    static let hairStyleNames = ["curly", "long", "buns"]
}

// MARK: - Glimmies (collectible pets)

struct GlimmieKind: Identifiable {
    let id: Int
    let name: String
    let color: Color
}

enum Glimmies {
    static let all: [GlimmieKind] = [
        GlimmieKind(id: 0, name: "Rosie", color: rgb(0xFFA6D2)),
        GlimmieKind(id: 1, name: "Bluebell", color: rgb(0x9FD6FF)),
        GlimmieKind(id: 2, name: "Minty", color: rgb(0x9EEBC6)),
        GlimmieKind(id: 3, name: "Lemony", color: rgb(0xFFEA8A)),
        GlimmieKind(id: 4, name: "Lulu", color: rgb(0xC9AEFF)),
        GlimmieKind(id: 5, name: "Peachy", color: rgb(0xFFC29E)),
        GlimmieKind(id: 6, name: "Cherry", color: rgb(0xFF8A96)),
        GlimmieKind(id: 7, name: "Snowy", color: rgb(0xF4F1FF)),
    ]
}

// MARK: - Avatar + outfit
// Avatar and Worn are saved, so they live in SaveData.swift with the rules for changing them.

typealias Outfit = [Category: Worn]

// MARK: - Wishes

struct Want: Equatable {
    let category: Category
    let item: String?   // nil = any item of the category
    let color: Int?     // nil = any color

    func isMet(by outfit: Outfit) -> Bool {
        guard let w = outfit[category] else { return false }
        if let item, w.item != item { return false }
        if let color {
            guard let it = Catalog.item(w.item), it.tintable, w.color == color else { return false }
        }
        return true
    }

    /// Picture used in the wish bubble.
    var iconItem: String { item ?? Catalog.items(in: category).first(where: { $0.tintable })!.id }

    var phrase: String {
        let colorWord = color.map { Palette.clothes[$0].name + " " } ?? ""
        let noun: String
        let plural: Bool
        if let item, let it = Catalog.item(item) {
            noun = it.name; plural = it.plural
        } else {
            if category == .hold { return "something to hold" }
            noun = category.noun; plural = category == .shoes || category == .wings
        }
        let words = colorWord + noun
        if plural { return words }
        return (words.first.map { "aeiou".contains($0) } == true ? "an " : "a ") + words
    }
}

struct Wish: Equatable {
    let wants: [Want]
    let glimmie: Int

    func isMet(by outfit: Outfit) -> Bool { wants.allSatisfy { $0.isMet(by: outfit) } }

    var sentence: String {
        let parts = wants.map(\.phrase)
        let list: String
        switch parts.count {
        case 1: list = parts[0]
        case 2: list = parts[0] + " and " + parts[1]
        default: list = parts.dropLast().joined(separator: ", ") + ", and " + parts.last!
        }
        return "Can you wear " + list + "?"
    }

    static func make(level: Int, glimmies: [Int], avoid outfit: Outfit) -> Wish {
        let count = level < 3 ? 1 : (level < 8 ? 2 : 3)
        let colorChance = level < 2 ? 0.0 : (level < 6 ? 0.4 : 0.7)
        let glim = glimmies.filter { Glimmies.all.indices.contains($0) }.randomElement() ?? 0
        for _ in 0..<30 {
            let cats = Category.allCases.shuffled().prefix(count)
            var wants: [Want] = []
            for c in cats {
                let pick = Catalog.items(in: c).randomElement()!
                let wantColor = pick.tintable && Double.random(in: 0..<1) < colorChance
                let color = wantColor ? Int.random(in: 0..<Palette.clothes.count) : nil
                // Sometimes ask for "a blue dress" (any dress) instead of a specific one.
                let anyItem = wantColor && c == .dress && Bool.random()
                wants.append(Want(category: c, item: anyItem ? nil : pick.id, color: color))
            }
            let w = Wish(wants: wants, glimmie: glim)
            if !w.isMet(by: outfit) { return w }
        }
        return Wish(wants: [Want(category: .hat, item: "hat_crown", color: nil)], glimmie: glim)
    }
}

// MARK: - Secret looks

struct SecretLook: Identifiable {
    let id: String
    let name: String
    let badgeItem: String
    let wants: [Want]
    func isMet(by outfit: Outfit) -> Bool { wants.allSatisfy { $0.isMet(by: outfit) } }
}

enum Secrets {
    static let all: [SecretLook] = [
        SecretLook(id: "fairy_queen", name: "Fairy Queen", badgeItem: "hat_crown", wants: [
            Want(category: .hat, item: "hat_crown", color: nil),
            Want(category: .dress, item: "dress_gown", color: nil),
            Want(category: .wings, item: "wings_fairy", color: nil)]),
        SecretLook(id: "star_fairy", name: "Star Fairy", badgeItem: "hat_star", wants: [
            Want(category: .hat, item: "hat_star", color: nil),
            Want(category: .hold, item: "hold_wand", color: nil),
            Want(category: .wings, item: "wings_fairy", color: nil)]),
        SecretLook(id: "garden_girl", name: "Garden Girl", badgeItem: "hat_flowers", wants: [
            Want(category: .hat, item: "hat_flowers", color: nil),
            Want(category: .hold, item: "hold_bouquet", color: nil),
            Want(category: .dress, item: nil, color: 4)]),
        SecretLook(id: "party_bunny", name: "Party Bunny", badgeItem: "hat_ears", wants: [
            Want(category: .hat, item: "hat_ears", color: nil),
            Want(category: .hold, item: "hold_balloon", color: nil),
            Want(category: .dress, item: "dress_tutu", color: nil)]),
    ]
}

// MARK: - Game state

/// The live game. Saved through SaveStore (SaveData.swift) on every change.
final class GameState: ObservableObject {
    static let jarSize = 5

    @Published var avatar: Avatar { didSet { save() } }
    @Published var outfit: Outfit { didSet { save() } }
    @Published var madeAvatar: Bool { didSet { save() } }
    @Published var stars: Int { didSet { save() } }
    @Published var wishesDone: Int { didSet { save() } }
    @Published var owned: [Int] { didSet { save() } }
    @Published var secrets: [String] { didSet { save() } }
    @Published var eggWaiting: Bool { didSet { save() } }

    private var loading = true
    private let store: SaveStore
    /// The save version written back; never lower than the one loaded.
    private var version = SaveData.currentVersion
    /// Glimmie kinds that only a newer build knows: kept in the save, hidden here.
    private var futureOwned: [Int] = []

    init(defaults: UserDefaults = .standard) {
        store = SaveStore(defaults: defaults)
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetSave") { defaults.removeObject(forKey: SaveStore.key) }
        var d = store.load()
        if args.contains("-demoBoutique") {
            d.madeAvatar = true
            d.avatar = Avatar(skin: 1, hairStyle: 1, hairColor: 0, eyes: 0)
            d.outfit = ["dress": Worn(item: "dress_gown", color: 5), "hat": Worn(item: "hat_crown", color: 0),
                        "shoes": Worn(item: "shoes_mary", color: 1)]
            d.stars = 3; d.owned = [0, 1, 2]
        }
        if args.contains("-demoEgg") {
            d.madeAvatar = true
            d.eggWaiting = true
        }
        version = max(d.version, SaveData.currentVersion)
        futureOwned = d.owned.filter { $0 >= Glimmies.all.count }
        d = Self.sanitized(d)
        avatar = d.avatar
        madeAvatar = d.madeAvatar
        stars = d.stars
        wishesDone = d.wishesDone
        owned = d.owned
        secrets = d.secrets
        eggWaiting = d.eggWaiting
        outfit = Self.outfit(from: d.outfit)
        loading = false
    }

    func save() {
        guard !loading else { return }
        var d = SaveData()
        d.version = version
        d.madeAvatar = madeAvatar; d.avatar = avatar; d.stars = stars; d.wishesDone = wishesDone
        d.owned = owned + futureOwned.filter { !owned.contains($0) }
        d.secrets = secrets; d.eggWaiting = eggWaiting
        d.outfit = Dictionary(uniqueKeysWithValues: outfit.map { ($0.key.rawValue, $0.value) })
        store.save(d)
    }

    var nextGlimmie: Int? { Glimmies.all.map(\.id).first { !owned.contains($0) } }

    /// Starts over. The old save is kept under a backup key in case it was an accident.
    func resetAll() {
        store.reset()
        let d = SaveData()
        loading = true
        version = SaveData.currentVersion
        futureOwned = []
        avatar = d.avatar; madeAvatar = d.madeAvatar; stars = d.stars; wishesDone = d.wishesDone
        owned = d.owned; secrets = d.secrets; eggWaiting = d.eggWaiting
        outfit = Self.outfit(from: d.outfit)
        loading = false
        save()
    }

    /// Makes any loaded save safe to show: indices in range, items in their own slot,
    /// and a full star jar becomes the egg (the app was closed right after the 5th star).
    static func sanitized(_ save: SaveData) -> SaveData {
        var s = save
        func clamp(_ v: Int, _ count: Int) -> Int { min(max(v, 0), count - 1) }
        s.avatar.skin = clamp(s.avatar.skin, Palette.skin.count)
        s.avatar.hairStyle = clamp(s.avatar.hairStyle, Catalog.hairStyles.count)
        s.avatar.hairColor = clamp(s.avatar.hairColor, Palette.hair.count)
        s.avatar.eyes = clamp(s.avatar.eyes, Palette.eyes.count)
        var outfit: [String: Worn] = [:]
        for (slot, w) in s.outfit {
            guard let c = Category(rawValue: slot), let it = Catalog.item(w.item), it.category == c else { continue }
            outfit[slot] = Worn(item: it.id, color: clamp(w.color, Palette.clothes.count))
        }
        s.outfit = outfit
        s.stars = max(0, s.stars)
        s.wishesDone = max(0, s.wishesDone)
        if s.stars >= jarSize { s.stars = 0; s.eggWaiting = true }
        var seen = Set<Int>()
        s.owned = s.owned.filter { Glimmies.all.indices.contains($0) && seen.insert($0).inserted }
        if s.owned.isEmpty { s.owned = [0] }
        return s
    }

    static func outfit(from saved: [String: Worn]) -> Outfit {
        var o: Outfit = [:]
        for (k, v) in saved { if let c = Category(rawValue: k) { o[c] = v } }
        return o
    }
}
