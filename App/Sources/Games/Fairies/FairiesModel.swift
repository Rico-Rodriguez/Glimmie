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

enum FairyEncounterKind: String, CaseIterable, Codable, Equatable, Hashable {
    case flutterDash
    case bubblePop
    case chimeEcho
    case treatLure
}

enum MeadowTreatKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case strawberry
    case honeyDrop
    case bungeoppang
    case silkSwirl

    var id: String { rawValue }

    var accentHex: UInt32 {
        switch self {
        case .strawberry: return 0xFF6B92
        case .honeyDrop: return 0xFFC53D
        case .bungeoppang: return 0xF5B54D
        case .silkSwirl: return 0x9EE3CB
        }
    }
}

enum FairyWish: String, CaseIterable, Codable, Identifiable, Hashable {
    case snack
    case bubbles
    case swing
    case dance
    case sleep
    case carousel

    var id: String { rawValue }

    var matchingSpot: CompactSpot? {
        switch self {
        case .snack: return .treatTable
        case .bubbles: return .teacupBath
        case .swing: return .rainbowSwing
        case .dance: return .danceStage
        case .sleep: return .cloudBed
        case .carousel: return nil
        }
    }
}

enum CompactTableTreatKind: String, CaseIterable, Equatable {
    case macaron
    case bungeoppang
    case celadonTea
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

    static let starters: [FairyKind] = [.heart, .star]
    static let pinnedDefaultsKey = "glimmie.pinnedFairy"

    var hairStyle: FairyHairStyle {
        switch self {
        case .heart, .cloud, .honey: return .twinPuffs
        case .ribbon, .peach, .melody: return .twinTails
        case .star, .moon: return .curls
        case .berry, .dewdrop, .blossom: return .bob
        case .silk: return .braidCrown
        }
    }

    var encounterKind: FairyEncounterKind {
        switch self {
        case .heart, .ribbon, .blossom: return .flutterDash
        case .dewdrop, .cloud: return .bubblePop
        case .melody, .star, .moon: return .chimeEcho
        case .berry, .peach, .honey, .silk: return .treatLure
        }
    }

    var preferredSpot: MeadowSpot {
        switch self {
        case .heart, .blossom, .berry: return .blossomBush
        case .dewdrop, .cloud, .melody: return .bubbleFountain
        case .star, .moon, .silk: return .teacupLantern
        case .ribbon, .peach, .honey: return .rainbowMushroom
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

enum FairiesMode: String, CaseIterable, Codable, Equatable {
    case meadow
    case compact
}

enum MeadowSpot: String, CaseIterable, Codable, Identifiable, Hashable {
    case blossomBush
    case bubbleFountain
    case teacupLantern
    case rainbowMushroom

    var id: String { rawValue }

    var center: CGPoint {
        switch self {
        case .blossomBush: return CGPoint(x: 186, y: 516)
        case .bubbleFountain: return CGPoint(x: 416, y: 478)
        case .teacupLantern: return CGPoint(x: 644, y: 404)
        case .rainbowMushroom: return CGPoint(x: 842, y: 516)
        }
    }

    var popOrigin: CGPoint {
        switch self {
        case .blossomBush: return CGPoint(x: 190, y: 438)
        case .bubbleFountain: return CGPoint(x: 416, y: 382)
        case .teacupLantern: return CGPoint(x: 644, y: 332)
        case .rainbowMushroom: return CGPoint(x: 836, y: 420)
        }
    }

    var hitRadius: CGFloat {
        switch self {
        case .blossomBush: return 96
        case .bubbleFountain: return 92
        case .teacupLantern: return 88
        case .rainbowMushroom: return 96
        }
    }

    var shimmerHex: UInt32 {
        switch self {
        case .blossomBush: return 0xFF9EC9
        case .bubbleFountain: return 0x8EDBFF
        case .teacupLantern: return 0xFFE27D
        case .rainbowMushroom: return 0xC8A8FF
        }
    }
}

enum MeadowChime: Int, CaseIterable, Identifiable, Hashable {
    case left = 0
    case middle = 1
    case right = 2

    var id: Int { rawValue }

    var sfx: SFX {
        switch self {
        case .left: return .note1
        case .middle: return .note2
        case .right: return .note3
        }
    }

    var anchor: CGPoint {
        switch self {
        case .left: return CGPoint(x: 412, y: 120)
        case .middle: return CGPoint(x: 512, y: 110)
        case .right: return CGPoint(x: 612, y: 120)
        }
    }

    var center: CGPoint {
        switch self {
        case .left: return CGPoint(x: 412, y: 186)
        case .middle: return CGPoint(x: 512, y: 174)
        case .right: return CGPoint(x: 612, y: 186)
        }
    }

    var colorHex: UInt32 {
        switch self {
        case .left: return 0xFFA2CE
        case .middle: return 0xFFE27D
        case .right: return 0x99E6D8
        }
    }

    var hitRadius: CGFloat { 50 }
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

    init(
        befriended: [FairyKind],
        spotOccupants: [CompactSpot: FairyKind],
        accessories: [FairyKind: FairyAccessory],
        pinnedFairy: FairyKind?,
        totalCatches: Int,
        roamingFairies: [FairyKind]? = nil
    ) {
        self.befriended = befriended
        self.spotOccupants = spotOccupants
        self.accessories = accessories
        self.pinnedFairy = pinnedFairy
        self.totalCatches = totalCatches
        if let roaming = roamingFairies {
            var unique: [FairyKind] = []
            for kind in roaming where befriended.contains(kind) && !unique.contains(kind) && unique.count < Self.maxCompactFairies {
                unique.append(kind)
            }
            for spot in CompactSpot.allCases {
                if let kind = spotOccupants[spot], befriended.contains(kind), !unique.contains(kind), unique.count < Self.maxCompactFairies {
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
            befriended: FairyKind.starters,
            spotOccupants: [.danceStage: .heart, .cloudBed: .star],
            accessories: [:],
            pinnedFairy: nil,
            totalCatches: 0
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
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawBefriended = (try? c.decode([FairyKind].self, forKey: .befriended)) ?? []
        var unique: [FairyKind] = []
        for kind in FairyKind.starters + rawBefriended where !unique.contains(kind) {
            unique.append(kind)
        }
        self.befriended = unique

        let rawSpots = (try? c.decode([String: FairyKind].self, forKey: .spotOccupants)) ?? [:]
        var spots: [CompactSpot: FairyKind] = [:]
        var usedFairies: Set<FairyKind> = []
        for (k, v) in rawSpots {
            if let spot = CompactSpot(rawValue: k), unique.contains(v), !usedFairies.contains(v) {
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

        let rawPinned = try? c.decodeIfPresent(FairyKind.self, forKey: .pinnedFairy)
        self.pinnedFairy = rawPinned.flatMap { unique.contains($0) ? $0 : nil }
        self.totalCatches = max(0, (try? c.decode(Int.self, forKey: .totalCatches)) ?? 0)

        let decodedRoaming = try? c.decodeIfPresent([FairyKind].self, forKey: .roamingFairies)
        if let decodedRoaming {
            var uniqueRoaming: [FairyKind] = []
            for kind in decodedRoaming where unique.contains(kind) && !uniqueRoaming.contains(kind) && uniqueRoaming.count < Self.maxCompactFairies {
                uniqueRoaming.append(kind)
            }
            for spot in CompactSpot.allCases {
                if let kind = spots[spot], !uniqueRoaming.contains(kind), uniqueRoaming.count < Self.maxCompactFairies {
                    uniqueRoaming.append(kind)
                }
            }
            self.roamingFairies = uniqueRoaming
        } else {
            // Backward compatibility with legacy saves that only persisted spotOccupants.
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
    }
}

enum FGeo {
    static let compactCenter = CGPoint(x: 512, y: 406)
    static let compactWidth: CGFloat = 824
    static let compactHeight: CGFloat = 556
    static let meadowHorizonY: CGFloat = 456
    static let treatMatCenter = CGPoint(x: 512, y: 506)
    static let treatMatRadius: CGFloat = 104
    static let catchCenter = CGPoint(x: 512, y: 332)
    static let carouselCenter = CGPoint(x: 398, y: 444)
    static let chandelierCenter = CGPoint(x: 512, y: 244)
    static let returnDropY: CGFloat = 656
    static let returnBadgeCenter = CGPoint(x: 512, y: 644)
    static let wandHomeCenter = CGPoint(x: 118, y: GameChromeLayout.dockY)

    static let flutterPerches: [CGPoint] = [
        CGPoint(x: 204, y: 404),
        CGPoint(x: 312, y: 246),
        CGPoint(x: 472, y: 342),
        CGPoint(x: 716, y: 244),
        CGPoint(x: 816, y: 402),
    ]

    static func clampToCompactInterior(_ point: CGPoint) -> CGPoint {
        let cy = compactCenter.y
        let y = max(258, min(556, point.y))
        // Taper horizontal bounds gently near the pointed bottom of the heart compact.
        let lowerRatio = max(0, (y - (cy + 30)) / 140)
        let halfW: CGFloat = 296 - lowerRatio * 124
        let x = max(compactCenter.x - halfW, min(compactCenter.x + halfW, point.x))
        return CGPoint(x: x, y: y)
    }
}
