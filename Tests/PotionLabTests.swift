import XCTest
@testable import Glimmie

final class PotionLabTests: XCTestCase {
    private func freshSim() -> PotionSim {
        let sim = PotionSim(save: nil)
        sim.demo = true
        return sim
    }

    private func run(_ sim: PotionSim, seconds: Double) {
        for _ in 0..<Int(seconds * 60) { sim.step(dt: 1.0 / 60) }
    }

    func testTheLevelFollowsTheVolumeAndTheFlasksShape() {
        XCTAssertEqual(PGeo.level(for: 0), PGeo.bottomY, accuracy: 0.5)
        XCTAssertEqual(PGeo.level(for: PGeo.capacity), PGeo.rimY, accuracy: 0.5)
        var last = PGeo.bottomY + 1
        for k in 1..<20 {
            let v = PGeo.capacity * CGFloat(k) / 20
            let y = PGeo.level(for: v)
            XCTAssertLessThan(y, last, "more potion, higher surface")
            XCTAssertEqual(PGeo.volume(below: y), v, accuracy: v * 0.01)
            last = y
        }
        // the round body is wider than the neck, so the same amount rises less in the middle than in the neck
        let mid = PGeo.level(for: PGeo.capacity * 0.5) - PGeo.level(for: PGeo.capacity * 0.55)
        let neck = PGeo.level(for: PGeo.capacity * 0.9) - PGeo.level(for: PGeo.capacity * 0.95)
        XCTAssertGreaterThan(neck, mid)
    }

    func testBottleShapesHoldLiquidThatStaysLevelWhenTipped() {
        for s in PBottleShape.allCases {
            XCTAssertGreaterThan(s.area, 2500, "\(s) holds something")
            let poly = PPoly.transform(s.outline, at: .zero, angle: 0.9, scale: 1)
            let y = PPoly.level(poly, fill: 0.5)
            XCTAssertEqual(PPoly.area(PPoly.below(poly, y)), s.area * 0.5, accuracy: s.area * 0.03, "\(s)")
        }
    }

    func testPouringAddsLiquidAndColorsThePotion() {
        let sim = freshSim()
        let before = sim.volume
        XCTAssertEqual(sim.meanColor().1, 0, accuracy: 0.001, "it starts as clear water")
        sim.pickUp(.ingredient(.nectar), finger: CGPoint(x: 470, y: 220), at: CGPoint(x: 470, y: 110))
        for _ in 0..<150 {
            sim.carry(to: CGPoint(x: 470, y: 110), finger: CGPoint(x: 470, y: 220))
            sim.step(dt: 1.0 / 60)
        }
        sim.release()
        run(sim, seconds: 2)
        XCTAssertGreaterThan(sim.volume, before + 2000, "the stream lands in the flask")
        let (c, a) = sim.meanColor()
        XCTAssertGreaterThan(a, 0.05)
        XCTAssertGreaterThan(c.r, c.g, "and turns it pink")
        XCTAssertGreaterThan(sim.doses[.nectar] ?? 0, 0.5)
    }

    func testHeavyLiquidSinksAndStirringMixesIt() {
        let sim = freshSim()
        // a layer of heavy night sky poured in on top
        for x in stride(from: CGFloat(440), through: 584, by: 16) {
            sim.addLiquid(at: CGPoint(x: x, y: sim.level + 10), vol: 1500, color: PIngredient.night.color, conc: 1.25, density: PIngredient.night.density, v: .zero)
        }
        sim.updateLiquid()
        func depthOfColor() -> CGFloat {
            var sum: CGFloat = 0, w: CGFloat = 0
            for k in sim.da.indices where sim.liquid[k] {
                let y = PGeo.cellCenter(k % PotionSim.NX, k / PotionSim.NX).y
                sum += y * CGFloat(sim.da[k]); w += CGFloat(sim.da[k])
            }
            return sum / max(0.001, w)
        }
        let start = depthOfColor()
        run(sim, seconds: 6)
        XCTAssertGreaterThan(depthOfColor(), start + 20, "it sinks to the bottom")

        func spread() -> Float {
            var vals: [Float] = []
            for k in sim.da.indices where sim.liquid[k] { vals.append(sim.da[k]) }
            let m = vals.reduce(0, +) / Float(max(1, vals.count))
            return vals.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Float(max(1, vals.count))
        }
        let unmixed = spread()
        sim.pickUp(.spoon, finger: PGeo.C, at: sim.spoon)
        for i in 0..<(60 * 6) {
            let a = CGFloat(i) / 60 * 5
            sim.carry(to: CGPoint(x: PGeo.C.x + cos(a) * 110, y: PGeo.C.y + 40 + sin(a) * 80), finger: PGeo.C)
            sim.step(dt: 1.0 / 60)
        }
        sim.release()
        XCTAssertLessThan(spread(), unmixed * 0.6, "stirring mixes the layers")
    }

    func testSecretCombosMakeRarePotions() {
        let sim = freshSim()
        XCTAssertNil(sim.rareKind())
        sim.doses = [.night: 1, .stars: 2]
        XCTAssertEqual(sim.rareKind(), .galaxy)
        sim.doses = [.nectar: 1, .petals: 2]
        XCTAssertEqual(sim.rareKind(), .love)
        sim.doses = [.hair: 1, .nectar: 1, .mermaid: 1, .moon: 1]
        XCTAssertEqual(sim.rareKind(), .rainbow)
        sim.doses = [.stars: 2, .dragon: 1, .moon: 1]
        XCTAssertEqual(sim.rareKind(), .golden, "golden comes before galaxy and dream")
        sim.doses = [.moon: 1]
        XCTAssertNil(sim.rareKind())
        sim.night = 1
        XCTAssertEqual(sim.rareKind(), .moonlight, "moon milk glows into moonlight with the lights off")
        sim.night = 0
        sim.doses = [.dragon: 1]
        sim.boilTime = 3
        XCTAssertEqual(sim.rareKind(), .dragon)
        sim.doses = [.nectar: 1, .mermaid: 1, .dragon: 1, .night: 1, .stars: 2, .berries: 2, .lavender: 2]
        XCTAssertEqual(sim.rareKind(), .wild)
        // every rare potion has a picture recipe that really makes it
        for k in PotionKind.allCases {
            let s = freshSim()
            for ing in k.recipe { s.doses[ing] = ing.need + 0.1 }
            if k.needsFire { s.boilTime = 3 }
            if k.needsNight { s.night = 1 }
            XCTAssertEqual(s.rareKind(), k, "the hint card's recipe for \(k)")
        }
    }

    func testDippingABottleFillsItAndTheRareOneGoesOnTheRack() {
        let sim = freshSim()
        sim.doses = [.night: 2, .stars: 3]
        run(sim, seconds: 1)
        XCTAssertEqual(sim.rare, .galaxy)
        let before = sim.volume
        sim.pickUp(.empty, finger: CGPoint(x: 512, y: 200), at: CGPoint(x: 512, y: 100))
        // down through the mouth into the potion
        for k in 0...105 {
            let y = 100 + CGFloat(k) * 4
            sim.carry(to: CGPoint(x: 512, y: y), finger: CGPoint(x: 512, y: y + 100))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertTrue(sim.dipInside, "it goes in through the mouth")
        for _ in 0..<180 {
            sim.carry(to: CGPoint(x: 512, y: 520), finger: CGPoint(x: 512, y: 620))
            sim.step(dt: 1.0 / 60)
        }
        XCTAssertGreaterThan(sim.dipFill, 0.8)
        XCTAssertLessThan(sim.volume, before - 3000, "the potion went into the bottle")
        sim.release()
        XCTAssertEqual(sim.rack.last?.kind, PotionKind.galaxy.rawValue)
        XCTAssertEqual(sim.rack.last?.bottleShape, PotionKind.galaxy.shape)
    }

    func testABottleCantGoThroughTheGlass() {
        let sim = freshSim()
        sim.pickUp(.empty, finger: CGPoint(x: 800, y: 500), at: CGPoint(x: 800, y: 400))
        for k in 0...60 {
            let x = 800 - CGFloat(k) * 5
            sim.carry(to: CGPoint(x: x, y: 460), finger: CGPoint(x: x, y: 560))
        }
        XCTAssertFalse(sim.dipInside)
        XCTAssertFalse(PGeo.inside(sim.heldPos), "it stays outside the round body")
    }

    func testTheTapDrainsItAll() {
        let sim = freshSim()
        sim.addLiquid(at: CGPoint(x: 512, y: 500), vol: 4000, color: PIngredient.mermaid.color, conc: 1, density: 0, v: .zero)
        sim.toggleDrain()
        run(sim, seconds: 12)
        XCTAssertEqual(sim.volume, 0, accuracy: 1)
        XCTAssertFalse(sim.draining)
        XCTAssertGreaterThan(sim.bucketFill, 0.2)
    }

    func testBoilingMakesBubblesAndFrostCoolsIt() {
        let sim = freshSim()
        sim.setHeat(3)
        run(sim, seconds: 25)
        XCTAssertGreaterThan(sim.boiling, 0.3)
        XCTAssertFalse(sim.bubbles.isEmpty)
        let hot = sim.temp
        for k in 0..<4 { sim.addPiece(.frost, at: CGPoint(x: 480 + CGFloat(k) * 20, y: 150), v: CGVector(dx: 0, dy: 100)) }
        sim.setHeat(0)
        run(sim, seconds: 3)
        XCTAssertLessThan(sim.temp, hot)
    }

    func testAPotionPouredOnTheUnicornChangesHer() {
        let sim = freshSim()
        sim.rack = [PotionBottle(id: 1, r: 1, g: 0.54, b: 0.82, fill: 1, shape: PBottleShape.star.rawValue, kind: PotionKind.rainbow.rawValue,
                                 magic: ["rainbow": 1], glow: 0.5, sparkle: 0.7)]
        sim.pickUp(.rack(0), finger: CGPoint(x: 250, y: 470), at: CGPoint(x: 250, y: 360))
        for _ in 0..<150 {
            sim.carry(to: CGPoint(x: 250, y: 360), finger: CGPoint(x: 250, y: 470))
            sim.step(dt: 1.0 / 60)
        }
        sim.release()
        run(sim, seconds: 1)
        XCTAssertGreaterThan(sim.uni.rainbow, 0, "rainbow potion makes a rainbow unicorn")
        XCTAssertGreaterThan(sim.uni.tintAmt, 0)
    }

    func testSavesComeBack() {
        let sim = freshSim()
        sim.rack = [PotionBottle(id: 4, r: 0.2, g: 0.3, b: 0.9, fill: 0.5, shape: 1, kind: nil, magic: ["bubble": 0.6], glow: 0, sparkle: 0)]
        let save = PotionSave(bottles: sim.rack, nextID: 5, volume: 50000, pr: 0.2, pg: 0.1, pb: 0.3, pa: 0.4, doses: ["nectar": 1], lightsOn: false, heat: 2, made: 3)
        let data = try! JSONEncoder().encode(save)
        let back = try! JSONDecoder().decode(PotionSave.self, from: data)
        let s2 = PotionSim(save: back)
        XCTAssertEqual(s2.rack.count, 1)
        XCTAssertEqual(s2.heat, 2)
        XCTAssertFalse(s2.lightsOn)
        XCTAssertEqual(s2.volume, 50000, accuracy: 1)
        XCTAssertEqual(s2.doses[.nectar] ?? 0, 1, accuracy: 0.001)
    }

    func testTheStickerPageHasEveryRarePotionAndTheUnicorn() {
        let ids = Set(PotionGame.entry.stickers.map(\.id))
        for k in PotionKind.allCases { XCTAssertTrue(ids.contains(k.rawValue)) }
        XCTAssertTrue(ids.contains("rainbowUnicorn"))
        XCTAssertTrue(ids.contains("floatingUnicorn"))
    }
}
