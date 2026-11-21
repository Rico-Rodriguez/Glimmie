import Foundation

struct UnicornLook: Codable, Equatable {
    var coat: UInt32 = 0xFFF8F1
    var mane: UInt32 = 0xF59FC4
    var horn: UInt32 = 0xFFC858
    var braided = false
    var gear: UnicornGear = .none
}

enum UnicornGear: String, Codable, CaseIterable {
    case none, bow, saddle, crown, wings

    var symbol: String {
        switch self {
        case .none: return "xmark"
        case .bow: return "ribbon.fill"
        case .saddle: return "heart.fill"
        case .crown: return "crown.fill"
        case .wings: return "sparkles"
        }
    }

    var treasureID: String? {
        switch self {
        case .crown, .wings: return "unicornstable/\(rawValue)"
        default: return nil
        }
    }

    static var available: [UnicornGear] {
        allCases.filter { $0.treasureID.map { Coins.shared.owns($0) } ?? true }
    }
}

enum MeadowVisitor: String, CaseIterable {
    case moonUnicorn, rainbowUnicorn, bunny, butterfly

    var name: String {
        switch self {
        case .moonUnicorn: return "Moon unicorn"
        case .rainbowUnicorn: return "Rainbow unicorn"
        case .bunny: return "Meadow bunny"
        case .butterfly: return "Meadow butterfly"
        }
    }

    var look: UnicornLook? {
        switch self {
        case .moonUnicorn: return UnicornLook(coat: 0xC6B8F9, mane: 0x687CC6, horn: 0xFFF1AB)
        case .rainbowUnicorn: return UnicornLook(coat: 0x9EEAD9, mane: 0xFF99BA, horn: 0xFFC858, braided: true)
        default: return nil
        }
    }
}

enum CareTool: String, CaseIterable {
    case brush, sponge, rinse, feed
}

enum CareSpot: String, CaseIterable, Codable {
    case shoulder, flank, knee, forelock, mane, tail, muzzle

    static let coat = [shoulder, flank, knee]
    static let hair = [forelock, mane, tail]
}

struct StableCare: Codable, Equatable {
    private(set) var burrs = Set(CareSpot.hair)
    private(set) var dirt = Set(CareSpot.coat)
    private(set) var soap: Set<CareSpot> = []
    private(set) var bites = 0

    static let snackBites = 2
    var groomed: Bool { burrs.isEmpty }
    var washed: Bool { dirt.isEmpty && soap.isEmpty }
    var fed: Bool { bites >= Self.snackBites }
    var complete: Bool { groomed && washed && fed }

    func spots(for tool: CareTool) -> Set<CareSpot> {
        switch tool {
        case .brush: return burrs
        case .sponge: return dirt
        case .rinse: return soap
        case .feed: return fed ? [] : [.muzzle]
        }
    }

    /// Returns true when this action changes the current care routine.
    @discardableResult
    mutating func use(_ tool: CareTool, at spot: CareSpot) -> Bool {
        guard spots(for: tool).contains(spot) else { return false }
        switch tool {
        case .brush: burrs.remove(spot)
        case .sponge:
            dirt.remove(spot)
            soap.insert(spot)
        case .rinse: soap.remove(spot)
        case .feed: bites += 1
        }
        return true
    }
}
