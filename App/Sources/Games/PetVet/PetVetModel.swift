import Foundation
import CoreGraphics

// MARK: - Pet Vet rules (no UI here, so tests can drive it)
//
// A visit is a few ailments, each with one or more spots on the patient. Every ailment is a short
// recipe of steps; each step needs one tool, used one of three ways: rub it over the spot, hold it
// there, or just touch the spot. Any spot can be treated in any order. Nothing can go wrong and
// nothing is locked: pamper tools (treat, bow, spray, feather...) always do something fun.

enum VetTool: String, CaseIterable, Codable {
    case sponge, shower, towel, tweezers, swab, bandage, thermometer, syrup, tissue, toothbrush
    case icepack, comb, cream, stethoscope, wrap, brush, treat, bow, spray, feather
}

enum VetAction: Equatable {
    /// Rub back and forth over the spot: this many points of finger travel.
    case rub(CGFloat)
    /// Hold the tool on the spot for this many seconds.
    case hold(Double)
    /// Touch the spot once.
    case touch
}

struct VetStep: Equatable {
    let tool: VetTool
    let action: VetAction
    /// Where this step happens, if not on the spot itself (e.g. medicine goes in the mouth).
    var anchor: String? = nil
}

/// Problem anchors in the 600 x 660 patient art. Must match tools/petvet/animals.py ANCHORS.
enum VetAnchors {
    static let all: [String: CGPoint] = [
        "forehead": CGPoint(x: 300, y: 168), "headL": CGPoint(x: 190, y: 205), "headR": CGPoint(x: 410, y: 205),
        "cheekL": CGPoint(x: 196, y: 322), "cheekR": CGPoint(x: 404, y: 322),
        "nose": CGPoint(x: 300, y: 308), "mouth": CGPoint(x: 300, y: 334),
        "chest": CGPoint(x: 300, y: 412), "tummy": CGPoint(x: 300, y: 500),
        "sideL": CGPoint(x: 200, y: 455), "sideR": CGPoint(x: 400, y: 455),
        "pawL": CGPoint(x: 222, y: 505), "pawR": CGPoint(x: 378, y: 505),
        "lowL": CGPoint(x: 252, y: 560), "lowR": CGPoint(x: 348, y: 560),
        "footL": CGPoint(x: 226, y: 604), "footR": CGPoint(x: 374, y: 604),
    ]
    static func point(_ name: String) -> CGPoint { all[name] ?? CGPoint(x: 300, y: 400) }
}

enum VetAilment: String, CaseIterable, Codable {
    case mud, thorns, scrape, cold, toothache, fleas, rash, tummy, sprain, leaves

    var steps: [VetStep] {
        switch self {
        case .mud: return [VetStep(tool: .sponge, action: .rub(240)), VetStep(tool: .shower, action: .rub(160))]
        case .thorns: return [VetStep(tool: .tweezers, action: .touch)]
        case .scrape: return [VetStep(tool: .swab, action: .rub(150)), VetStep(tool: .bandage, action: .touch)]
        case .cold: return [VetStep(tool: .thermometer, action: .hold(1.5), anchor: "mouth"),
                            VetStep(tool: .syrup, action: .touch, anchor: "mouth"),
                            VetStep(tool: .tissue, action: .rub(140), anchor: "nose")]
        case .toothache: return [VetStep(tool: .icepack, action: .hold(1.3)),
                                 VetStep(tool: .toothbrush, action: .rub(220), anchor: "mouth")]
        case .fleas: return [VetStep(tool: .comb, action: .rub(80))]
        case .rash: return [VetStep(tool: .cream, action: .rub(120))]
        case .tummy: return [VetStep(tool: .stethoscope, action: .hold(1.6)),
                             VetStep(tool: .syrup, action: .touch, anchor: "mouth")]
        case .sprain: return [VetStep(tool: .icepack, action: .hold(1.2)), VetStep(tool: .wrap, action: .touch)]
        case .leaves: return [VetStep(tool: .brush, action: .rub(100))]
        }
    }

    /// How many spots one visit gets.
    var spots: ClosedRange<Int> {
        switch self {
        case .mud: return 3...4
        case .thorns: return 2...3
        case .scrape: return 1...2
        case .fleas: return 3...5
        case .rash: return 2...3
        case .leaves: return 2...4
        case .cold, .toothache, .tummy, .sprain: return 1...1
        }
    }

    /// Anchors this ailment can sit on, in order of preference after shuffling.
    var places: [String] {
        switch self {
        case .mud: return ["headL", "headR", "forehead", "sideL", "sideR", "pawL", "pawR", "lowL", "lowR", "footL", "footR", "chest"]
        case .thorns: return ["pawL", "pawR", "footL", "footR", "lowL", "lowR"]
        case .scrape: return ["headL", "headR", "sideL", "sideR", "pawL", "pawR", "lowL", "lowR"]
        case .cold: return ["nose"]
        case .toothache: return ["cheekR", "cheekL"]
        case .fleas: return ["headL", "headR", "forehead", "sideL", "sideR", "chest", "lowL", "lowR"]
        case .rash: return ["chest", "sideL", "sideR", "headL", "headR", "lowL", "lowR"]
        case .tummy: return ["tummy"]
        case .sprain: return ["footL", "footR", "pawL", "pawR"]
        case .leaves: return ["forehead", "headL", "headR", "sideL", "sideR", "lowL", "lowR"]
        }
    }

    /// The sticker shown in the waiting room's thought bubble.
    var icon: String {
        switch self {
        case .mud: return "mud"
        case .thorns: return "thorn"
        case .scrape: return "scrape"
        case .cold: return "drip"
        case .toothache: return "swelling"
        case .fleas: return "bug"
        case .rash: return "rash"
        case .tummy: return "swirl"
        case .sprain: return "bump"
        case .leaves: return "leaf"
        }
    }

    /// Treating it pinches a little, so the patient winces (then cheers).
    var stings: Bool { self == .thorns || self == .scrape }

    /// What stays on the patient once it is healed.
    var keepsake: String? {
        switch self {
        case .scrape: return "bandage"
        case .sprain: return "cast"
        default: return nil
        }
    }
}

struct VetSpot: Identifiable, Codable, Equatable {
    let id: Int
    let ailment: VetAilment
    let anchor: String
    var stage = 0
    var progress = 0.0

    var healed: Bool { stage >= ailment.steps.count }
    var step: VetStep? { healed ? nil : ailment.steps[stage] }
    /// Where the current step happens.
    var target: CGPoint { VetAnchors.point(step?.anchor ?? anchor) }
    var point: CGPoint { VetAnchors.point(anchor) }
}

/// A sticker she put on a patient (bows, extra bandages), in patient art coordinates.
struct VetSticker: Codable, Equatable {
    var prop: String
    var x: Double
    var y: Double
    var scale: Double = 0.8
    var rotation: Double = 0
    var point: CGPoint { CGPoint(x: x, y: y) }
}

struct VetVisit: Codable, Equatable {
    var animal: String
    var spots: [VetSpot]

    var healed: Bool { spots.allSatisfy(\.healed) }
    var ailments: [VetAilment] {
        var seen: [VetAilment] = []
        for s in spots where !seen.contains(s.ailment) { seen.append(s.ailment) }
        return seen
    }
    var openAilments: [VetAilment] { ailments.filter { a in spots.contains { $0.ailment == a && !$0.healed } } }
    var neededTools: Set<VetTool> { Set(spots.compactMap { $0.step?.tool }) }
    func has(_ a: VetAilment) -> Bool { spots.contains { $0.ailment == a && !$0.healed } }

    /// A new visit with 2 or 3 different ailments on free spots.
    static func random<G: RandomNumberGenerator>(animal: String, using rng: inout G) -> VetVisit {
        let count = Int.random(in: 2...3, using: &rng)
        var pool = VetAilment.allCases.shuffled(using: &rng)
        // keep the two face ailments apart so the mouth isn't crowded
        if let c = pool.firstIndex(of: .cold), let t = pool.firstIndex(of: .toothache) {
            pool.remove(at: max(c, t))
        }
        var used = Set<String>()
        var spots: [VetSpot] = []
        var picked = 0
        for a in pool where picked < count {
            let want = Int.random(in: a.spots, using: &rng)
            let free = a.places.shuffled(using: &rng).filter { !used.contains($0) }
            guard free.count >= a.spots.lowerBound else { continue }
            for p in free.prefix(want) {
                used.insert(p)
                spots.append(VetSpot(id: spots.count, ailment: a, anchor: p))
            }
            picked += 1
        }
        return VetVisit(animal: animal, spots: spots)
    }

    static func random(animal: String) -> VetVisit {
        var g = SystemRandomNumberGenerator()
        return random(animal: animal, using: &g)
    }

    enum Event: Equatable {
        case working(spot: Int, tool: VetTool)
        case stepDone(spot: Int, ailment: VetAilment, step: Int)
        case spotHealed(spot: Int, ailment: VetAilment)
        case allHealed
    }

    /// How close (in art points) the tool tip must be to a spot.
    static let reach: CGFloat = 78

    /// The tool tip is at `tip` (patient art coordinates), moved `moved` points and was held `dt`
    /// seconds since the last call. Works on the nearest spot that needs this tool.
    mutating func use(_ tool: VetTool, at tip: CGPoint, moved: CGFloat, dt: Double) -> [Event] {
        var best: Int?
        var bestD = CGFloat.greatestFiniteMagnitude
        for (i, s) in spots.enumerated() where s.step?.tool == tool {
            let t = s.target
            let d = hypot(t.x - tip.x, t.y - tip.y)
            if d < VetVisit.reach && d < bestD { best = i; bestD = d }
        }
        guard let i = best, let step = spots[i].step else { return [] }
        let gain: Double
        switch step.action {
        case .rub(let need): gain = Double(moved / need)
        case .hold(let secs): gain = dt / secs
        case .touch: gain = 1
        }
        guard gain > 0 else { return [] }
        let wasHealed = healed
        let id = spots[i].id
        var events: [Event] = [.working(spot: id, tool: tool)]
        spots[i].progress += gain
        if spots[i].progress >= 1 {
            let done = spots[i].stage
            spots[i].stage += 1
            spots[i].progress = 0
            events.append(.stepDone(spot: id, ailment: spots[i].ailment, step: done))
            if spots[i].healed { events.append(.spotHealed(spot: id, ailment: spots[i].ailment)) }
        }
        if !wasHealed && healed { events.append(.allHealed) }
        return events
    }
}

/// What she has done in the clinic. Saved in Application Support/Games/petvet/clinic.json.
struct VetClinicSave: Codable, Equatable {
    var healed: [String: Int] = [:]
    var stickers: [String: [VetSticker]] = [:]
    var visits: [String: VetVisit] = [:]
}
