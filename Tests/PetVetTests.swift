import XCTest
@testable import Glimmie

final class PetVetTests: XCTestCase {
    let art = VetArt.shared

    func testArtLoads() {
        XCTAssertEqual(art.order.count, 16)
        for id in art.order {
            guard let a = art.animals[id] else { return XCTFail(id) }
            XCTAssertFalse(a.body.isEmpty, id)
            for e in ["open", "blink", "happy", "wince", "sad", "tired", "sparkle"] { XCTAssertNotNil(a.eyes[e], "\(id) \(e)") }
            for m in ["smile", "grin", "frown", "wavy", "ouch", "o", "yum", "wide"] { XCTAssertNotNil(a.mouths[m], "\(id) \(m)") }
        }
        for t in VetTool.allCases { XCTAssertNotNil(art.tools[t], t.rawValue) }
        XCTAssertNotNil(art.rooms["exam"])
        XCTAssertNotNil(art.rooms["lobby"])
    }

    func testEveryPropTheGameUsesExists() {
        var names = ["bubbles", "scrapeClean", "bandage", "cast", "rednose", "drip", "chill", "medal", "seat",
                     "bugGreen", "bugPink", "leafGold", "leafRed"] + (0..<6).map { "bow\($0)" }
        names += VetAilment.allCases.map(\.icon)
        for n in names { XCTAssertNotNil(art.props[n], n) }
    }

    func testAnchorsMatchTheArt() {
        XCTAssertEqual(Set(art.anchors.keys), Set(VetAnchors.all.keys))
        for (k, p) in VetAnchors.all { XCTAssertEqual(art.anchors[k], p, k) }
        for a in VetAilment.allCases {
            for p in a.places { XCTAssertNotNil(VetAnchors.all[p], p) }
            for s in a.steps { if let p = s.anchor { XCTAssertNotNil(VetAnchors.all[p], p) } }
        }
    }

    func testRandomVisitsUseFreeSpots() {
        var g = VetSeededGenerator(seed: 42)
        for _ in 0..<300 {
            let v = VetVisit.random(animal: "puppy", using: &g)
            XCTAssertGreaterThanOrEqual(v.ailments.count, 2)
            XCTAssertLessThanOrEqual(v.ailments.count, 3)
            XCTAssertEqual(Set(v.spots.map(\.anchor)).count, v.spots.count)
            XCTAssertFalse(v.ailments.contains(.cold) && v.ailments.contains(.toothache))
            XCTAssertFalse(v.healed)
        }
    }

    func testEveryAilmentCanBeHealed() {
        for a in VetAilment.allCases {
            var v = VetVisit(animal: "kitty", spots: [VetSpot(id: 0, ailment: a, anchor: a.places[0])])
            var events: [VetVisit.Event] = []
            var guardCount = 0
            while !v.healed && guardCount < 2000 {
                guard let step = v.spots[0].step else { break }
                let p = v.spots[0].target
                // wiggle back and forth over the spot
                let tip = CGPoint(x: p.x + (guardCount % 2 == 0 ? 10 : -10), y: p.y)
                events += v.use(step.tool, at: tip, moved: 20, dt: 1.0 / 30)
                guardCount += 1
            }
            XCTAssertTrue(v.healed, a.rawValue)
            XCTAssertTrue(events.contains(.allHealed), a.rawValue)
            XCTAssertTrue(events.contains(.spotHealed(spot: 0, ailment: a)), a.rawValue)
        }
    }

    func testWrongToolOrFarAwayDoesNothing() {
        var v = VetVisit(animal: "bear", spots: [VetSpot(id: 0, ailment: .thorns, anchor: "pawL")])
        XCTAssertTrue(v.use(.sponge, at: VetAnchors.point("pawL"), moved: 30, dt: 0.1).isEmpty)
        XCTAssertTrue(v.use(.tweezers, at: CGPoint(x: 560, y: 40), moved: 30, dt: 0.1).isEmpty)
        XCTAssertEqual(v.neededTools, [.tweezers])
        let e = v.use(.tweezers, at: VetAnchors.point("pawL"), moved: 0, dt: 0)
        XCTAssertTrue(e.contains(.allHealed))
    }

    func testSaveRoundTrips() throws {
        var s = VetClinicSave()
        s.healed["fox"] = 3
        s.stickers["fox"] = [VetSticker(prop: "bow2", x: 300, y: 150)]
        s.visits["fox"] = VetVisit.random(animal: "fox")
        let d = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(VetClinicSave.self, from: d), s)
    }
}

/// A tiny deterministic generator for tests.
struct VetSeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
