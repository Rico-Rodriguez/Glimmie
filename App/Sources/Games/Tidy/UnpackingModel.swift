import Foundation
import SwiftUI

// MARK: - Unpacking Mode Domain Model

enum UnpackingRoomID: String, CaseIterable, Identifiable, Codable {
    case bedroom
    case artNook
    case koreanKitchen
    case fairyPlayroom
    case livingRoom
    case starlightBalcony

    var id: String { rawValue }

    var accentHex: UInt32 {
        switch self {
        case .bedroom: return 0xFF9AC2
        case .artNook: return 0xFFBE6B
        case .koreanKitchen: return 0x8EDBC6
        case .fairyPlayroom: return 0xC6A8FF
        case .livingRoom: return 0x9AD1A8
        case .starlightBalcony: return 0x8DB8FF
        }
    }

    var badgeSymbol: String {
        switch self {
        case .bedroom: return "bed.double.fill"
        case .artNook: return "paintpalette.fill"
        case .koreanKitchen: return "cup.and.saucer.fill"
        case .fairyPlayroom: return "sparkles"
        case .livingRoom: return "sofa.fill"
        case .starlightBalcony: return "moon.stars.fill"
        }
    }

    var next: UnpackingRoomID {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self) else { return .bedroom }
        return all[(idx + 1) % all.count]
    }
}

enum SurfaceKind: String, CaseIterable, Codable {
    case shelf
    case desk
    case bed
    case floor
    case wall
}

struct SurfaceZone: Identifiable, Equatable {
    let id: String
    let kind: SurfaceKind
    let rect: CGRect
    /// Baseline Y where standing items ground their bottom edge (ignored for free-2D `.wall` surfaces).
    let restY: CGFloat
}

enum UnpackingItemKind: String, CaseIterable, Codable {
    // 18 brand-new personal Unpacking treasures
    case deskLamp
    case hanbokDoll
    case jewelCompact
    case familyPhoto
    case piggyBank
    case succulentPot
    case alarmClock
    case diaryBook
    case plushBunny
    case fairyLights
    case riceCooker
    case kettle
    case teapot
    case slippers
    case artPoster
    case flowerVase
    case plushCat
    case musicBox

    // 18 classic Tidy items adapted to cozy room scale
    case book
    case teddy
    case plant
    case crayon
    case mug
    case bowl
    case plate
    case shoe
    case hat
    case ball
    case car
    case star
    case lunchbox
    case jar
    case jam
    case frame
    case block
    case duck

    var tidyKind: TidyKind? {
        switch self {
        case .book: return .book
        case .teddy: return .teddy
        case .plant: return .plant
        case .crayon: return .crayon
        case .mug: return .mug
        case .bowl: return .bowl
        case .plate: return .plate
        case .shoe: return .shoe
        case .hat: return .hat
        case .ball: return .ball
        case .car: return .car
        case .star: return .star
        case .lunchbox: return .lunchbox
        case .jar: return .jar
        case .jam: return .jam
        case .frame: return .frame
        case .block: return .block
        case .duck: return .duck
        default: return nil
        }
    }

    var size: CGSize {
        switch self {
        case .deskLamp: return CGSize(width: 66, height: 92)
        case .hanbokDoll: return CGSize(width: 64, height: 92)
        case .jewelCompact: return CGSize(width: 56, height: 50)
        case .familyPhoto: return CGSize(width: 78, height: 68)
        case .piggyBank: return CGSize(width: 72, height: 56)
        case .succulentPot: return CGSize(width: 56, height: 64)
        case .alarmClock: return CGSize(width: 60, height: 64)
        case .diaryBook: return CGSize(width: 58, height: 70)
        case .plushBunny: return CGSize(width: 66, height: 90)
        case .fairyLights: return CGSize(width: 176, height: 42)
        case .riceCooker: return CGSize(width: 82, height: 72)
        case .kettle: return CGSize(width: 72, height: 66)
        case .teapot: return CGSize(width: 76, height: 60)
        case .slippers: return CGSize(width: 86, height: 42)
        case .artPoster: return CGSize(width: 86, height: 102)
        case .flowerVase: return CGSize(width: 58, height: 88)
        case .plushCat: return CGSize(width: 74, height: 66)
        case .musicBox: return CGSize(width: 64, height: 74)
        // Reused classic items scaled naturally for full rooms
        case .book: return CGSize(width: 24, height: 84)
        case .teddy: return CGSize(width: 68, height: 76)
        case .plant: return CGSize(width: 60, height: 80)
        case .crayon: return CGSize(width: 20, height: 72)
        case .mug: return CGSize(width: 48, height: 44)
        case .bowl: return CGSize(width: 68, height: 32)
        case .plate: return CGSize(width: 82, height: 18)
        case .shoe: return CGSize(width: 68, height: 38)
        case .hat: return CGSize(width: 72, height: 44)
        case .ball: return CGSize(width: 54, height: 54)
        case .car: return CGSize(width: 72, height: 42)
        case .star: return CGSize(width: 58, height: 58)
        case .lunchbox: return CGSize(width: 80, height: 56)
        case .jar: return CGSize(width: 44, height: 58)
        case .jam: return CGSize(width: 44, height: 50)
        case .frame: return CGSize(width: 64, height: 78)
        case .block: return CGSize(width: 46, height: 46)
        case .duck: return CGSize(width: 52, height: 46)
        }
    }

    var material: TidyMaterial {
        if let tk = tidyKind { return tk.material }
        switch self {
        case .deskLamp, .alarmClock, .kettle: return .metal
        case .hanbokDoll, .plushBunny, .plushCat, .slippers: return .plush
        case .jewelCompact, .riceCooker: return .plastic
        case .familyPhoto, .artPoster, .diaryBook: return .paper
        case .piggyBank, .succulentPot, .teapot: return .ceramic
        case .flowerVase, .fairyLights: return .glass
        case .musicBox: return .wood
        default: return .plastic
        }
    }

    /// Forgiving natural surface compatibility: never traps the player in a 1-slot riddle.
    var allowedSurfaces: Set<SurfaceKind> {
        switch self {
        case .artPoster, .familyPhoto, .frame:
            return [.wall, .shelf, .desk]
        case .fairyLights:
            return [.wall, .shelf]
        case .slippers, .shoe:
            return [.floor]
        case .riceCooker:
            return [.desk, .shelf, .floor]
        default:
            return [.shelf, .desk, .bed, .floor]
        }
    }

    var prefersWall: Bool {
        switch self {
        case .artPoster, .familyPhoto, .frame, .fairyLights:
            return true
        default:
            return false
        }
    }

    var isLighting: Bool {
        self == .deskLamp || self == .fairyLights
    }

    var isInteractive: Bool {
        switch self {
        case .deskLamp, .fairyLights, .musicBox, .alarmClock, .plushBunny, .plushCat,
             .riceCooker, .hanbokDoll, .jewelCompact, .piggyBank, .kettle, .teapot, .teddy:
            return true
        default:
            return false
        }
    }

    static let newUnpackingItems: [UnpackingItemKind] = [
        .deskLamp, .hanbokDoll, .jewelCompact, .familyPhoto, .piggyBank, .succulentPot,
        .alarmClock, .diaryBook, .plushBunny, .fairyLights, .riceCooker, .kettle,
        .teapot, .slippers, .artPoster, .flowerVase, .plushCat, .musicBox
    ]
}

struct UnpackingItemSpec: Equatable, Codable, Identifiable {
    let id: String
    let kind: UnpackingItemKind
    let color: Int
}

struct UnpackingBoxSpec: Equatable, Identifiable {
    let id: String
    let rect: CGRect
    let items: [UnpackingItemSpec]
}

struct UnpackingRoomSpec: Identifiable {
    let id: UnpackingRoomID
    let floorY: CGFloat
    let surfaces: [SurfaceZone]
    let boxes: [UnpackingBoxSpec]

    var allItems: [UnpackingItemSpec] {
        boxes.flatMap(\.items)
    }

    func surface(id: String) -> SurfaceZone? {
        surfaces.first { $0.id == id }
    }
}

// MARK: - Persistence (`Games/tidy/unpacking.json`)

struct SavedUnpackingItem: Codable, Equatable {
    var itemID: String
    var kind: UnpackingItemKind
    var color: Int
    var surfaceID: String
    var x: CGFloat
    var y: CGFloat
    var z: Int
    var isLit: Bool
}

struct SavedUnpackingRoom: Codable, Equatable {
    var completed: Bool
    var placed: [SavedUnpackingItem]
    var openedBoxes: [String]
}

struct UnpackingSave: Codable, Equatable {
    var rooms: [String: SavedUnpackingRoom] = [:]
}

final class UnpackingStore: ObservableObject {
    static let fileName = "unpacking.json"

    @Published var data: UnpackingSave

    init(loadFromDisk: Bool = true) {
        if loadFromDisk,
           let saved = GameStorage.load(UnpackingSave.self, game: TidyGame.id, file: Self.fileName) {
            data = saved
        } else {
            data = UnpackingSave()
        }
    }

    func roomSave(for id: UnpackingRoomID) -> SavedUnpackingRoom? {
        data.rooms[id.rawValue]
    }

    func isCompleted(_ id: UnpackingRoomID) -> Bool {
        data.rooms[id.rawValue]?.completed == true
    }

    var completedCount: Int {
        UnpackingRoomID.allCases.filter { isCompleted($0) }.count
    }

    func update(room id: UnpackingRoomID, save roomSave: SavedUnpackingRoom, persist: Bool = true) {
        data.rooms[id.rawValue] = roomSave
        if persist {
            GameStorage.saveAsync(data, game: TidyGame.id, file: Self.fileName)
        }
    }

    func clear(room id: UnpackingRoomID, persist: Bool = true) {
        data.rooms.removeValue(forKey: id.rawValue)
        if persist {
            GameStorage.saveAsync(data, game: TidyGame.id, file: Self.fileName)
        }
    }

    func saveSync() {
        GameStorage.save(data, game: TidyGame.id, file: Self.fileName)
    }
}
