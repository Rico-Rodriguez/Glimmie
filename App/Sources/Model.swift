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
        Item(id: "dress_skirt", category: .dress, name: "skirt and top", tintable: true, defaultColor: 6, plural: false),
        Item(id: "dress_overalls", category: .dress, name: "overalls", tintable: true, defaultColor: 5, plural: true),
        Item(id: "dress_mermaid", category: .dress, name: "mermaid dress", tintable: true, defaultColor: 4, plural: false),
        Item(id: "dress_swim", category: .dress, name: "swimsuit", tintable: true, defaultColor: 1, plural: false),
        Item(id: "dress_pjs", category: .dress, name: "pajamas", tintable: true, defaultColor: 5, plural: true),
        Item(id: "shoes_mary", category: .shoes, name: "party shoes", tintable: true, defaultColor: 1, plural: true),
        Item(id: "shoes_boots", category: .shoes, name: "boots", tintable: true, defaultColor: 6, plural: true),
        Item(id: "shoes_sandals", category: .shoes, name: "sandals", tintable: true, defaultColor: 2, plural: true),
        Item(id: "shoes_slippers", category: .shoes, name: "bunny slippers", tintable: true, defaultColor: 0, plural: true),
        Item(id: "hat_crown", category: .hat, name: "crown", tintable: false, defaultColor: 0, plural: false),
        Item(id: "hat_flowers", category: .hat, name: "flower crown", tintable: false, defaultColor: 0, plural: false),
        Item(id: "hat_star", category: .hat, name: "star clips", tintable: false, defaultColor: 0, plural: true),
        Item(id: "hat_bow", category: .hat, name: "bow", tintable: true, defaultColor: 0, plural: false),
        Item(id: "hat_ears", category: .hat, name: "bunny ears", tintable: true, defaultColor: 7, plural: true),
        Item(id: "hat_cat", category: .hat, name: "kitty ears", tintable: true, defaultColor: 6, plural: true),
        Item(id: "hat_sunhat", category: .hat, name: "sun hat", tintable: true, defaultColor: 3, plural: false),
        Item(id: "hat_hearts", category: .hat, name: "heart clips", tintable: false, defaultColor: 0, plural: true),
        Item(id: "hold_wand", category: .hold, name: "magic wand", tintable: false, defaultColor: 0, plural: false),
        Item(id: "hold_bouquet", category: .hold, name: "bouquet", tintable: false, defaultColor: 0, plural: false),
        Item(id: "hold_balloon", category: .hold, name: "balloon", tintable: true, defaultColor: 1, plural: false),
        Item(id: "hold_purse", category: .hold, name: "purse", tintable: true, defaultColor: 0, plural: false),
        Item(id: "hold_teddy", category: .hold, name: "teddy bear", tintable: false, defaultColor: 0, plural: false),
        Item(id: "hold_icecream", category: .hold, name: "ice cream", tintable: false, defaultColor: 0, plural: false),
        Item(id: "wings_fairy", category: .wings, name: "fairy wings", tintable: true, defaultColor: 6, plural: true),
        Item(id: "wings_butterfly", category: .wings, name: "butterfly wings", tintable: true, defaultColor: 4, plural: true),
    ]
    static func item(_ id: String) -> Item? { items.first { $0.id == id } }
    static func items(in c: Category) -> [Item] { items.filter { $0.category == c } }

    // Order matters: Avatar.hairStyle is an index into this list, so only append.
    static let hairStyles = ["hair_curls", "hair_long", "hair_buns", "hair_pony", "hair_braids"]
    static let hairStyleNames = ["curly", "long", "buns", "ponytail", "braids"]
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

/// Things a Glimmie can wear. Each is a full-canvas layer (L_glim_acc_*) drawn over
/// L_glim_body + L_glim_face, with I_/B_ sticker icons like the closet items.
struct GlimmieAccessory: Identifiable, Hashable {
    let id: String      // e.g. "glim_acc_bow"
    let name: String
}

enum GlimmieAccessories {
    static let all: [GlimmieAccessory] = [
        GlimmieAccessory(id: "glim_acc_bow", name: "bow"),
        GlimmieAccessory(id: "glim_acc_crown", name: "crown"),
        GlimmieAccessory(id: "glim_acc_flower", name: "flower"),
        GlimmieAccessory(id: "glim_acc_partyhat", name: "party hat"),
        GlimmieAccessory(id: "glim_acc_glasses", name: "heart glasses"),
    ]
}

// MARK: - Avatar + outfit

struct Avatar: Codable, Equatable {
    var skin = 1
    var hairStyle = 1
    var hairColor = 0
    var eyes = 0
}

struct Worn: Codable, Equatable {
    var item: String
    var color: Int
}

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
        let glim = glimmies.randomElement() ?? 0
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
        SecretLook(id: "sleepy_time", name: "Sleepy Time", badgeItem: "hold_teddy", wants: [
            Want(category: .dress, item: "dress_pjs", color: nil),
            Want(category: .shoes, item: "shoes_slippers", color: nil),
            Want(category: .hold, item: "hold_teddy", color: nil)]),
        SecretLook(id: "beach_day", name: "Beach Day", badgeItem: "hat_sunhat", wants: [
            Want(category: .dress, item: "dress_swim", color: nil),
            Want(category: .hat, item: "hat_sunhat", color: nil),
            Want(category: .hold, item: "hold_icecream", color: nil)]),
        SecretLook(id: "mermaid_princess", name: "Mermaid Princess", badgeItem: "dress_mermaid", wants: [
            Want(category: .dress, item: "dress_mermaid", color: nil),
            Want(category: .hat, item: "hat_crown", color: nil)]),
        SecretLook(id: "kitty_cat", name: "Kitty Cat", badgeItem: "hat_cat", wants: [
            Want(category: .hat, item: "hat_cat", color: nil),
            Want(category: .dress, item: "dress_overalls", color: nil)]),
        SecretLook(id: "butterfly_garden", name: "Butterfly Garden", badgeItem: "wings_butterfly", wants: [
            Want(category: .wings, item: "wings_butterfly", color: nil),
            Want(category: .hat, item: "hat_flowers", color: nil)]),
        SecretLook(id: "sweetheart", name: "Sweetheart", badgeItem: "hat_hearts", wants: [
            Want(category: .hat, item: "hat_hearts", color: nil),
            Want(category: .dress, item: "dress_skirt", color: 0)]),
    ]
}

// MARK: - Save data

struct SaveData: Codable {
    var madeAvatar = false
    var avatar = Avatar()
    var outfit: [String: Worn] = ["dress": Worn(item: "dress_aline", color: 0),
                                  "shoes": Worn(item: "shoes_mary", color: 1)]
    var stars = 0
    var wishesDone = 0
    var owned: [Int] = [0]
    var secrets: [String] = []
    var eggWaiting = false
}

final class GameState: ObservableObject {
    static let jarSize = 5
    private static let key = "glimmie.save.v1"

    @Published var avatar: Avatar { didSet { save() } }
    @Published var outfit: Outfit { didSet { save() } }
    @Published var madeAvatar: Bool { didSet { save() } }
    @Published var stars: Int { didSet { save() } }
    @Published var wishesDone: Int { didSet { save() } }
    @Published var owned: [Int] { didSet { save() } }
    @Published var secrets: [String] { didSet { save() } }
    @Published var eggWaiting: Bool { didSet { save() } }

    private var loading = true

    init() {
        var d = SaveData()
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetSave") { UserDefaults.standard.removeObject(forKey: Self.key) }
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data) { d = saved }
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
        avatar = d.avatar
        madeAvatar = d.madeAvatar
        stars = d.stars
        wishesDone = d.wishesDone
        owned = d.owned.isEmpty ? [0] : d.owned
        secrets = d.secrets
        eggWaiting = d.eggWaiting
        var o: Outfit = [:]
        for (k, v) in d.outfit { if let c = Category(rawValue: k), Catalog.item(v.item) != nil { o[c] = v } }
        outfit = o
        loading = false
    }

    func save() {
        guard !loading else { return }
        var d = SaveData()
        d.madeAvatar = madeAvatar; d.avatar = avatar; d.stars = stars; d.wishesDone = wishesDone
        d.owned = owned; d.secrets = secrets; d.eggWaiting = eggWaiting
        d.outfit = Dictionary(uniqueKeysWithValues: outfit.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(d) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    var nextGlimmie: Int? { Glimmies.all.map(\.id).first { !owned.contains($0) } }

    func resetAll() {
        let d = SaveData()
        loading = true
        avatar = d.avatar; madeAvatar = false; stars = 0; wishesDone = 0; owned = [0]; secrets = []; eggWaiting = false
        outfit = [.dress: Worn(item: "dress_aline", color: 0), .shoes: Worn(item: "shoes_mary", color: 1)]
        loading = false
        save()
    }
}
