import SwiftUI

enum FairyHairStyle: String, Codable, Equatable {
    case twinPuffs
    case twinTails
    case curls
    case bob
    case braidCrown
}

struct FairyPalette: Equatable {
    let hair: UInt32
    let hairShade: UInt32
    let dress: UInt32
    let dressAccent: UInt32
    let wing: UInt32
    let wingInner: UInt32
    let emblem: UInt32
    let emblemAccent: UInt32
    let skin: UInt32
    let cheek: UInt32
    let eye: UInt32
}

enum FairyStation: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case stage
    case salon
    case teaTable

    var id: String { rawValue }
}

enum FairySalonTool: Equatable, Hashable {
    case brush(WingBrushColor)
    case glitter(UInt32)
    case stamp(WingStampKind)
    case wipe
    case wandBuilder

    static let glitterPalette: [UInt32] = [
        0xFFE378,
        0xFF8EC8,
        0x8CE6FF,
        0xD2A8FF,
        0x9AEBC8,
    ]
}

enum FairyWish: String, CaseIterable, Codable, Identifiable, Hashable {
    case snack
    case bubbles
    case swing
    case dance
    case sleep
    case carousel
    case wingSalon
    case pixieTea

    var id: String { rawValue }

    var matchingSpot: CompactSpot? {
        switch self {
        case .snack: return .treatTable
        case .bubbles: return .teacupBath
        case .swing: return .rainbowSwing
        case .dance: return .danceStage
        case .sleep: return .cloudBed
        case .carousel, .wingSalon, .pixieTea: return nil
        }
    }

    var matchingStation: FairyStation? {
        switch self {
        case .wingSalon: return .salon
        case .pixieTea: return .teaTable
        case .snack, .bubbles, .swing, .dance, .sleep, .carousel: return nil
        }
    }
}

enum CompactTableTreatKind: String, CaseIterable, Equatable {
    case macaron
    case bungeoppang
    case celadonTea
}

enum TeaNectar: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case rosePetal
    case moonberry
    case sunflowerHoney
    case jadeMint

    var id: String { rawValue }

    var liquidHex: UInt32 {
        switch self {
        case .rosePetal: return 0xFF9AC8
        case .moonberry: return 0xB89EFF
        case .sunflowerHoney: return 0xFFD866
        case .jadeMint: return 0x82E3C4
        }
    }

    var highlightHex: UInt32 {
        switch self {
        case .rosePetal: return 0xFFD6EA
        case .moonberry: return 0xE6DCFF
        case .sunflowerHoney: return 0xFFF4B8
        case .jadeMint: return 0xCCF8EA
        }
    }

    var potHex: UInt32 {
        switch self {
        case .rosePetal: return 0xFFB8DA
        case .moonberry: return 0xD2C0FF
        case .sunflowerHoney: return 0xFFE694
        case .jadeMint: return 0xA2ECD4
        }
    }

    var flowerHex: UInt32 {
        switch self {
        case .rosePetal: return 0xFF6FA8
        case .moonberry: return 0x9E7CF8
        case .sunflowerHoney: return 0xFFB830
        case .jadeMint: return 0x5CCCA8
        }
    }
}

enum TeaTransformKind: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case glow
    case tinyShrink
    case rainbowTrail
    case floatingBubbles

    var id: String { rawValue }

    var accentHex: UInt32 {
        switch self {
        case .glow: return 0xFFE066
        case .tinyShrink: return 0x82E6C8
        case .rainbowTrail: return 0xFF8EC8
        case .floatingBubbles: return 0x98DEFF
        }
    }
}

enum SugarStarKind: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case sunbeam
    case pixieMint
    case rainbowPrism
    case cloudPearl

    var id: String { rawValue }

    var colorHex: UInt32 {
        switch self {
        case .sunbeam: return 0xFFE066
        case .pixieMint: return 0x7CE6C4
        case .rainbowPrism: return 0xFF94D2
        case .cloudPearl: return 0x9CDFFF
        }
    }

    var fizzHex: UInt32 {
        switch self {
        case .sunbeam: return 0xFFE680
        case .pixieMint: return 0x94F0D8
        case .rainbowPrism: return 0xEEA8FF
        case .cloudPearl: return 0xB8ECFF
        }
    }

    var transform: TeaTransformKind {
        switch self {
        case .sunbeam: return .glow
        case .pixieMint: return .tinyShrink
        case .rainbowPrism: return .rainbowTrail
        case .cloudPearl: return .floatingBubbles
        }
    }
}

enum FairyTeaTreatKind: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case macaron
    case bungeoppang
    case berryTart
    case hwajeon

    var id: String { rawValue }

    var accentHex: UInt32 {
        switch self {
        case .macaron: return 0xFF9AC8
        case .bungeoppang: return 0xF5BE5C
        case .berryTart: return 0xFF6B92
        case .hwajeon: return 0xFFD6E6
        }
    }
}

struct ActiveTeaTransform: Equatable {
    let kind: TeaTransformKind
    var remaining: Double
    let duration: Double
}

struct PixieTeaWish: Codable, Equatable, Hashable {
    let nectar: TeaNectar
    let sugarStar: SugarStarKind
    let treat: FairyTeaTreatKind
}

struct TeaCupDraft: Equatable {
    var nectar: TeaNectar?
    var fillLevel: CGFloat = 0
    var sugarStars: [SugarStarKind] = []
    var platedTreat: FairyTeaTreatKind?
    var liquidHex: UInt32 = 0xFFE6F2
    var fizzTimer: Double = 0
    var steamPhase: Double = 0

    var hasNectar: Bool {
        nectar != nil && fillLevel >= 0.85
    }

    var isReadyToServe: Bool {
        hasNectar && !sugarStars.isEmpty && platedTreat != nil
    }

    var dominantTransform: TeaTransformKind {
        sugarStars.last?.transform ?? .glow
    }
}

enum TeaSessionPhase: Equatable {
    case awaitingPour(fairy: FairyKind, wish: PixieTeaWish, draft: TeaCupDraft)
    case pouring(fairy: FairyKind, wish: PixieTeaWish, draft: TeaCupDraft, activeNectar: TeaNectar)
    case ready(fairy: FairyKind, wish: PixieTeaWish, draft: TeaCupDraft)
    case sipping(fairy: FairyKind, wish: PixieTeaWish, draft: TeaCupDraft, progress: CGFloat)
    case transformed(fairy: FairyKind, wish: PixieTeaWish, transform: TeaTransformKind, remaining: Double)

    var fairy: FairyKind {
        switch self {
        case .awaitingPour(let fairy, _, _),
             .pouring(let fairy, _, _, _),
             .ready(let fairy, _, _),
             .sipping(let fairy, _, _, _),
             .transformed(let fairy, _, _, _):
            return fairy
        }
    }

    var wish: PixieTeaWish {
        switch self {
        case .awaitingPour(_, let wish, _),
             .pouring(_, let wish, _, _),
             .ready(_, let wish, _),
             .sipping(_, let wish, _, _),
             .transformed(_, let wish, _, _):
            return wish
        }
    }

    var draft: TeaCupDraft? {
        switch self {
        case .awaitingPour(_, _, let draft),
             .pouring(_, _, let draft, _),
             .ready(_, _, let draft),
             .sipping(_, _, let draft, _):
            return draft
        case .transformed:
            return nil
        }
    }
}

enum FairyKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case heart
    case star
    case berry
    case cloud
    case ribbon
    case moon
    case melody
    case peach
    case dewdrop
    case honey
    case blossom
    case silk

    var id: String { rawValue }

    static let pinnedDefaultsKey = PinnedFairyCodec.legacyFairyKey

    var hairStyle: FairyHairStyle {
        switch self {
        case .heart, .cloud, .honey: return .twinPuffs
        case .ribbon, .peach, .melody: return .twinTails
        case .star, .moon: return .curls
        case .berry, .dewdrop, .blossom: return .bob
        case .silk: return .braidCrown
        }
    }

    var palette: FairyPalette {
        switch self {
        case .heart:
            return FairyPalette(
                hair: 0xFF88BA, hairShade: 0xE85C96,
                dress: 0xFFB5D6, dressAccent: 0xFF6FA8,
                wing: 0xFFD9EE, wingInner: 0xFFF5FA,
                emblem: 0xFF5D9E, emblemAccent: 0xFFF0F7,
                skin: 0xFFE9DB, cheek: 0xFF96BA, eye: 0x9C2B66
            )
        case .star:
            return FairyPalette(
                hair: 0xFFE07D, hairShade: 0xF0B941,
                dress: 0xFFF0A6, dressAccent: 0xFFC547,
                wing: 0xFFF4C4, wingInner: 0xFFFFFF,
                emblem: 0xFFC93C, emblemAccent: 0xFFF9D6,
                skin: 0xFFEBD9, cheek: 0xFFA4A8, eye: 0x7A4B9E
            )
        case .berry:
            return FairyPalette(
                hair: 0xFF7B9C, hairShade: 0xDE4D72,
                dress: 0xFF9EB5, dressAccent: 0x7CD992,
                wing: 0xFFE0EB, wingInner: 0xE6FFF0,
                emblem: 0xFF5C82, emblemAccent: 0x6FD486,
                skin: 0xFFECDF, cheek: 0xFF8AA8, eye: 0x8F2850
            )
        case .cloud:
            return FairyPalette(
                hair: 0xB8E4FF, hairShade: 0x7CC2F2,
                dress: 0xDCF2FF, dressAccent: 0x9AD2FF,
                wing: 0xF2FAFF, wingInner: 0xD4EEFF,
                emblem: 0xFFFFFF, emblemAccent: 0x9FD8FF,
                skin: 0xFFEBE0, cheek: 0xFFA8C6, eye: 0x3D6BA6
            )
        case .ribbon:
            return FairyPalette(
                hair: 0xD2A8FF, hairShade: 0xA876E8,
                dress: 0xE5CCFF, dressAccent: 0xFF94C8,
                wing: 0xF2E3FF, wingInner: 0xFFE6F4,
                emblem: 0xFF78B8, emblemAccent: 0xFFE2F2,
                skin: 0xFFEADC, cheek: 0xFF9AC0, eye: 0x6B3B9E
            )
        case .moon:
            return FairyPalette(
                hair: 0xB9B4FF, hairShade: 0x837DE0,
                dress: 0xCFCBFF, dressAccent: 0xFFE07A,
                wing: 0xE4E2FF, wingInner: 0xFFF7D1,
                emblem: 0xFFE066, emblemAccent: 0xFFF9DC,
                skin: 0xFFEBE2, cheek: 0xFFA3C4, eye: 0x4A4296
            )
        case .melody:
            return FairyPalette(
                hair: 0x8FE8D4, hairShade: 0x56C7AE,
                dress: 0xBFF5E8, dressAccent: 0xFFA6D2,
                wing: 0xDCFDF5, wingInner: 0xFFF2FA,
                emblem: 0xFF84BE, emblemAccent: 0xFFE67D,
                skin: 0xFFEADB, cheek: 0xFF9CB8, eye: 0x2B7A78
            )
        case .peach:
            return FairyPalette(
                hair: 0xFFB896, hairShade: 0xED8A61,
                dress: 0xFFD4BE, dressAccent: 0xFF9680,
                wing: 0xFFEBE0, wingInner: 0xFFF6E8,
                emblem: 0xFF9E82, emblemAccent: 0x7ED692,
                skin: 0xFFE8D8, cheek: 0xFF9494, eye: 0x8C4238
            )
        case .dewdrop:
            return FairyPalette(
                hair: 0x8CD4FF, hairShade: 0x52B0F0,
                dress: 0xBBE7FF, dressAccent: 0x7AE5DA,
                wing: 0xDDF5FF, wingInner: 0xFFFFFF,
                emblem: 0x5EC7FF, emblemAccent: 0xE6F8FF,
                skin: 0xFFECE2, cheek: 0xFFA3BE, eye: 0x2B6AA3
            )
        case .honey:
            return FairyPalette(
                hair: 0xF7C96B, hairShade: 0xD99A36,
                dress: 0xFFE484, dressAccent: 0x9C6834,
                wing: 0xFFF7D6, wingInner: 0xFFFFFF,
                emblem: 0xFFB830, emblemAccent: 0x8C5828,
                skin: 0xFFE8D4, cheek: 0xFF9E94, eye: 0x78481C
            )
        case .blossom:
            return FairyPalette(
                hair: 0xFFC2D9, hairShade: 0xED8FB2,
                dress: 0xFFE0EC, dressAccent: 0xFF8EB8,
                wing: 0xFFF0F6, wingInner: 0xFFE8A8,
                emblem: 0xFF9BC2, emblemAccent: 0xFFE378,
                skin: 0xFFEBE0, cheek: 0xFF94B4, eye: 0x8F3A62
            )
        case .silk:
            return FairyPalette(
                hair: 0x5B527A, hairShade: 0x3D3559,
                dress: 0xFFC5D0, dressAccent: 0x9EE3CB,
                wing: 0xE8FBF4, wingInner: 0xFFEAF0,
                emblem: 0xFF7B9E, emblemAccent: 0xFFE17D,
                skin: 0xFFECDF, cheek: 0xFF9AB4, eye: 0x4A3666
            )
        }
    }
}

enum CompactSpot: String, CaseIterable, Codable, Identifiable, Hashable {
    case cloudBed
    case rainbowSwing
    case teacupBath
    case danceStage
    case treatTable

    var id: String { rawValue }

    var center: CGPoint {
        switch self {
        case .cloudBed: return CGPoint(x: 288, y: 306)
        case .rainbowSwing: return CGPoint(x: 736, y: 302)
        case .danceStage: return CGPoint(x: 512, y: 404)
        case .teacupBath: return CGPoint(x: 300, y: 492)
        case .treatTable: return CGPoint(x: 724, y: 492)
        }
    }

    var fairyOffset: CGPoint {
        switch self {
        case .cloudBed: return CGPoint(x: 0, y: -14)
        case .rainbowSwing: return CGPoint(x: 0, y: 8)
        case .danceStage: return CGPoint(x: 0, y: -32)
        case .teacupBath: return CGPoint(x: 0, y: -18)
        case .treatTable: return CGPoint(x: 0, y: -26)
        }
    }

    var hitRadius: CGFloat { 88 }

    var mood: FairyMood {
        switch self {
        case .cloudBed: return .sleepy
        case .rainbowSwing: return .giggle
        case .teacupBath: return .happy
        case .danceStage: return .celebrate
        case .treatTable: return .yum
        }
    }
}

enum FairyAccessory: String, CaseIterable, Codable, Identifiable, Hashable {
    case bow
    case crown
    case flower
    case starClip
    case daenggiRibbon

    var id: String { rawValue }

    var accentHex: UInt32 {
        switch self {
        case .bow: return 0xFF7EB8
        case .crown: return 0xFFD452
        case .flower: return 0xFFA2C9
        case .starClip: return 0xFFE378
        case .daenggiRibbon: return 0xFF789C
        }
    }
}

enum FairyMood: Equatable {
    case happy
    case giggle
    case sleepy
    case yum
    case celebrate
}

struct FairiesSave: Equatable {
    static let maxCompactFairies = 8

    var befriended: [FairyKind]
    var spotOccupants: [CompactSpot: FairyKind]
    var accessories: [FairyKind: FairyAccessory]
    var pinnedFairy: FairyKind?
    var totalCatches: Int
    var roamingFairies: [FairyKind]
    var wingDesigns: [FairyKind: FairyWingDesign]
    var wands: [FairyKind: FairyWandDesign]
    var teasServed: Int

    init(
        befriended: [FairyKind] = FairyKind.allCases,
        spotOccupants: [CompactSpot: FairyKind],
        accessories: [FairyKind: FairyAccessory],
        pinnedFairy: FairyKind?,
        totalCatches: Int,
        roamingFairies: [FairyKind]? = nil,
        wingDesigns: [FairyKind: FairyWingDesign] = [:],
        wands: [FairyKind: FairyWandDesign] = [:],
        teasServed: Int = 0
    ) {
        self.befriended = FairyKind.allCases
        self.spotOccupants = spotOccupants
        self.accessories = accessories
        self.pinnedFairy = pinnedFairy
        self.totalCatches = max(0, totalCatches)
        self.teasServed = max(0, teasServed)

        var cleanDesigns: [FairyKind: FairyWingDesign] = [:]
        for (kind, design) in wingDesigns {
            var trimmed = design
            trimmed.trimToBudget()
            if !trimmed.isEmpty {
                cleanDesigns[kind] = trimmed
            }
        }
        self.wingDesigns = cleanDesigns
        self.wands = wands

        if let roaming = roamingFairies {
            var unique: [FairyKind] = []
            for kind in roaming where !unique.contains(kind) && unique.count < Self.maxCompactFairies {
                unique.append(kind)
            }
            for spot in CompactSpot.allCases {
                if let kind = spotOccupants[spot], !unique.contains(kind), unique.count < Self.maxCompactFairies {
                    unique.append(kind)
                }
            }
            self.roamingFairies = unique
        } else {
            self.roamingFairies = CompactSpot.allCases.compactMap { spotOccupants[$0] }
        }
    }

    static var starter: FairiesSave {
        FairiesSave(
            befriended: FairyKind.allCases,
            spotOccupants: [.danceStage: .heart, .cloudBed: .star],
            accessories: [:],
            pinnedFairy: nil,
            totalCatches: 0,
            roamingFairies: [.heart, .star, .blossom],
            wingDesigns: [:],
            wands: [:],
            teasServed: 0
        )
    }
}

extension FairiesSave: Codable {
    private enum CodingKeys: String, CodingKey {
        case befriended
        case spotOccupants
        case accessories
        case pinnedFairy
        case totalCatches
        case roamingFairies
        case wingDesigns
        case wands
        case teasServed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.befriended = FairyKind.allCases

        let rawSpots = (try? c.decode([String: FairyKind].self, forKey: .spotOccupants)) ?? [:]
        var spots: [CompactSpot: FairyKind] = [:]
        var usedFairies: Set<FairyKind> = []
        for (k, v) in rawSpots {
            if let spot = CompactSpot(rawValue: k), !usedFairies.contains(v) {
                spots[spot] = v
                usedFairies.insert(v)
            }
        }
        self.spotOccupants = spots

        let rawAccessories = (try? c.decode([String: FairyAccessory].self, forKey: .accessories)) ?? [:]
        var acc: [FairyKind: FairyAccessory] = [:]
        for (k, v) in rawAccessories {
            if let fairy = FairyKind(rawValue: k) {
                acc[fairy] = v
            }
        }
        self.accessories = acc

        self.pinnedFairy = try? c.decodeIfPresent(FairyKind.self, forKey: .pinnedFairy)
        self.totalCatches = max(0, (try? c.decodeIfPresent(Int.self, forKey: .totalCatches)) ?? 0)
        self.teasServed = max(0, (try? c.decodeIfPresent(Int.self, forKey: .teasServed)) ?? 0)

        let rawDesigns = (try? c.decodeIfPresent([String: FairyWingDesign].self, forKey: .wingDesigns)) ?? [:]
        var decodedDesigns: [FairyKind: FairyWingDesign] = [:]
        for (k, v) in rawDesigns {
            if let fairy = FairyKind(rawValue: k) {
                var trimmed = v
                trimmed.trimToBudget()
                if !trimmed.isEmpty {
                    decodedDesigns[fairy] = trimmed
                }
            }
        }
        self.wingDesigns = decodedDesigns

        let rawWands = (try? c.decodeIfPresent([String: FairyWandDesign].self, forKey: .wands)) ?? [:]
        var decodedWands: [FairyKind: FairyWandDesign] = [:]
        for (k, v) in rawWands {
            if let fairy = FairyKind(rawValue: k) {
                decodedWands[fairy] = v
            }
        }
        self.wands = decodedWands

        let decodedRoaming = try? c.decodeIfPresent([FairyKind].self, forKey: .roamingFairies)
        if let decodedRoaming {
            var uniqueRoaming: [FairyKind] = []
            for kind in decodedRoaming where !uniqueRoaming.contains(kind) && uniqueRoaming.count < Self.maxCompactFairies {
                uniqueRoaming.append(kind)
            }
            for spot in CompactSpot.allCases {
                if let kind = spots[spot], !uniqueRoaming.contains(kind), uniqueRoaming.count < Self.maxCompactFairies {
                    uniqueRoaming.append(kind)
                }
            }
            self.roamingFairies = uniqueRoaming
        } else {
            self.roamingFairies = CompactSpot.allCases.compactMap { spots[$0] }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(befriended, forKey: .befriended)
        var spotDict: [String: FairyKind] = [:]
        for (k, v) in spotOccupants {
            spotDict[k.rawValue] = v
        }
        try c.encode(spotDict, forKey: .spotOccupants)
        var accDict: [String: FairyAccessory] = [:]
        for (k, v) in accessories {
            accDict[k.rawValue] = v
        }
        try c.encode(accDict, forKey: .accessories)
        try c.encodeIfPresent(pinnedFairy, forKey: .pinnedFairy)
        try c.encode(totalCatches, forKey: .totalCatches)
        try c.encode(roamingFairies, forKey: .roamingFairies)

        var designDict: [String: FairyWingDesign] = [:]
        for (k, v) in wingDesigns where !v.isEmpty {
            designDict[k.rawValue] = v
        }
        try c.encode(designDict, forKey: .wingDesigns)

        var wandDict: [String: FairyWandDesign] = [:]
        for (k, v) in wands {
            wandDict[k.rawValue] = v
        }
        try c.encode(wandDict, forKey: .wands)
        try c.encode(teasServed, forKey: .teasServed)
    }
}

enum FGeo {
    static let compactCenter = CGPoint(x: 512, y: 406)
    static let compactWidth: CGFloat = 824
    static let compactHeight: CGFloat = 556
    static let carouselCenter = CGPoint(x: 398, y: 444)
    static let chandelierCenter = CGPoint(x: 512, y: 244)
    static let returnDropY: CGFloat = 656
    static let returnBadgeCenter = CGPoint(x: 512, y: 644)

    static let salonMirrorCenter = CGPoint(x: 512, y: 390)
    static let salonWingCenter = CGPoint(x: 512, y: 400)
    static let salonWingHalfSpan = CGSize(width: 248, height: 184)
    static let salonWandCenter = CGPoint(x: 512, y: 396)
    static let salonWandFairyCenter = CGPoint(x: 274, y: 422)

    static let teaFairyCenter = CGPoint(x: 332, y: 342)
    static let teaWishBubbleCenter = CGPoint(x: 196, y: 214)
    static let teaTableCenter = CGPoint(x: 512, y: 504)
    static let teaCupCenter = CGPoint(x: 472, y: 472)
    static let teaPlateCenter = CGPoint(x: 648, y: 486)

    static func teapotShelfCenter(for nectar: TeaNectar) -> CGPoint {
        switch nectar {
        case .rosePetal: return CGPoint(x: 742, y: 242)
        case .moonberry: return CGPoint(x: 866, y: 242)
        case .sunflowerHoney: return CGPoint(x: 742, y: 356)
        case .jadeMint: return CGPoint(x: 866, y: 356)
        }
    }

    static func clampToCompactInterior(_ point: CGPoint) -> CGPoint {
        let cy = compactCenter.y
        let y = max(258, min(556, point.y))
        let lowerRatio = max(0, (y - (cy + 30)) / 140)
        let halfW: CGFloat = 296 - lowerRatio * 124
        let x = max(compactCenter.x - halfW, min(compactCenter.x + halfW, point.x))
        return CGPoint(x: x, y: y)
    }
}
