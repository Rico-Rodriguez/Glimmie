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

struct MeadowRide {
    struct Stop {
        let visitor: MeadowVisitor
        let stars: Int
        let puddles: Int
    }

    // Each stretch has three jumps. A missed jump splashes and still moves the ride forward.
    static let jumps: Set<Int> = [1, 3, 4]
    static let route: [MeadowVisitor] = [.bunny, .moonUnicorn, .butterfly, .rainbowUnicorn]
    private(set) var step = 0
    private(set) var stars = 0
    private(set) var puddles = 0
    private(set) var stop: Stop?
    private(set) var stretch = 0

    init(stretch: Int = 0) {
        self.stretch = max(0, stretch) % Self.route.count
    }

    var needsJump: Bool { Self.jumps.contains(step) }

    @discardableResult
    mutating func move(jump: Bool) -> Bool {
        guard stop == nil else { return false }
        let splash = needsJump && !jump
        if splash { puddles += 1 } else { stars += 1 }
        step += 1
        if step == 6 {
            stop = Stop(visitor: Self.route[stretch % Self.route.count], stars: stars, puddles: puddles)
        }
        return splash
    }

    mutating func continueRide() {
        guard stop != nil else { return }
        stretch = (stretch + 1) % Self.route.count
        step = 0
        stars = 0
        puddles = 0
        stop = nil
    }
}
