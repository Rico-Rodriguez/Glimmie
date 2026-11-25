import XCTest
@testable import Glimmie

final class PetVetTests: XCTestCase {
    let art = VetArt.shared

    override func setUp() {
        super.setUp()
        Coins.shared.resetForTests()
        StickerBook.shared.demo = true
    }

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

    func testEveryProblemSpotCountsAsOnThePatient() {
        // the magnifier, the see-through tool and the tip ring show only over the patient,
        // so every place a tool is needed must count as "on the patient"
        for (k, p) in VetAnchors.all { XCTAssertTrue(VetExamView.onPatient(p), k) }
        XCTAssertFalse(VetExamView.onPatient(CGPoint(x: -100, y: 300)))
    }

    func testAllEightPetVetStickersRegistered() {
        XCTAssertEqual(PetVetFind.allCases.count, 8)
        XCTAssertEqual(PetVetFind.stickers.count, 8)
        XCTAssertEqual(PetVetGame.entry.stickers.count, 8)
        XCTAssertEqual(Set(PetVetGame.entry.stickers.map(\.id)), Set(PetVetFind.allCases.map(\.rawValue)))
    }

    func testAllHealedAwardsFiveCoinsAndUnlocksStickers() {
        let clinic = VetClinic(save: VetClinicSave(), persist: false)
        var v = VetVisit(animal: "puppy", spots: [
            VetSpot(id: 0, ailment: .mud, anchor: "headL"),
            VetSpot(id: 1, ailment: .tummy, anchor: "tummy"),
            VetSpot(id: 2, ailment: .toothache, anchor: "cheekR"),
        ])
        for i in v.spots.indices {
            v.spots[i].stage = v.spots[i].ailment.steps.count
        }
        XCTAssertTrue(v.healed)

        let before = Coins.shared.balance
        let paid = clinic.completeVisit(for: "puppy", visit: v)
        XCTAssertEqual(paid, 5)
        XCTAssertEqual(Coins.shared.balance, before + 5)
        XCTAssertEqual(clinic.healedCount("puppy"), 1)
        XCTAssertTrue(StickerBook.shared.has(game: PetVetGame.id, id: PetVetFind.firstHeal.rawValue))
        XCTAssertTrue(StickerBook.shared.has(game: PetVetGame.id, id: PetVetFind.sparkleBath.rawValue))
        XCTAssertTrue(StickerBook.shared.has(game: PetVetGame.id, id: PetVetFind.tummyHero.rawValue))
        XCTAssertTrue(StickerBook.shared.has(game: PetVetGame.id, id: PetVetFind.sweetTooth.rawValue))
    }

    func testAutoToolHoldBoostCompletesEveryHoldStepInSingleTap() {
        let holdAilments: [VetAilment] = [.cold, .tummy, .toothache, .sprain]
        let ticks = Int(AutoTool.work * 30)
        for a in holdAilments {
            var v = VetVisit(animal: "kitty", spots: [VetSpot(id: 0, ailment: a, anchor: a.places[0])])
            guard let step = v.spots[0].step else { return XCTFail(a.rawValue) }
            for _ in 0..<ticks {
                _ = v.use(step.tool, at: v.spots[0].target, moved: 0, dt: (1.0 / 30) * VetExamView.autoHoldBoost)
            }
            XCTAssertGreaterThanOrEqual(v.spots[0].stage, 1, "AutoTool hold should finish stage 0 of \(a.rawValue)")
        }
    }

    func testSyrupPrerequisiteAndGentleLobbyCheckIn() {
        var coldVisit = VetVisit(animal: "puppy", spots: [VetSpot(id: 0, ailment: .cold, anchor: "nose")])
        XCTAssertEqual(coldVisit.syrupPrerequisite, .thermometer)
        coldVisit.spots[0].stage = 1
        XCTAssertNil(coldVisit.syrupPrerequisite)

        let tummyVisit = VetVisit(animal: "puppy", spots: [VetSpot(id: 0, ailment: .tummy, anchor: "tummy")])
        XCTAssertEqual(tummyVisit.syrupPrerequisite, .stethoscope)

        var save = VetClinicSave()
        var healedVisit = VetVisit(animal: "fox", spots: [VetSpot(id: 0, ailment: .thorns, anchor: "pawL")])
        healedVisit.spots[0].stage = 1
        save.visits["fox"] = healedVisit
        save.stickers["fox"] = [
            VetSticker(prop: "bow1", x: 300, y: 150),
            VetSticker(prop: "bandage", x: 220, y: 450),
        ]
        let clinic = VetClinic(save: save, persist: false)

        // Tapping a healed patient keeps them healed for happy pamper play.
        clinic.checkIn("fox")
        XCTAssertTrue(clinic.visit("fox").healed)

        // Explicitly starting a fresh checkup re-rolls ailments, keeps bows, and removes old bandages.
        let fresh = clinic.startNewVisit(for: "fox")
        XCTAssertFalse(fresh.healed)
        XCTAssertEqual(clinic.stickers("fox").map(\.prop), ["bow1"])
    }

    func testAllTwentyToolsAreGroupedWithoutDuplicates() {
        let grouped = VetExamView.examTools + VetExamView.washBandageTools + VetExamView.pamperTools
        XCTAssertEqual(grouped.count, VetTool.allCases.count)
        XCTAssertEqual(Set(grouped), Set(VetTool.allCases))
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
