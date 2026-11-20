import XCTest
@testable import Glimmie

final class SalonTests: XCTestCase {
    private func sim(_ seed: UInt64 = 3) -> HairSim {
        HairSim(recipe: HairRecipe(seed: seed, color: 2, length: 2, fringe: 4, curl: 0, tangle: 0.5), palette: DressUpArt.shared.hair)
    }

    func testHairSettlesAndStaysFinite() {
        let s = sim()
        s.settle(seconds: 2)
        for st in s.strands {
            for p in st.p {
                XCTAssertTrue(p.x.isFinite && p.y.isFinite)
                XCTAssertLessThanOrEqual(p.y, SalonBody.floorY + 0.5)
            }
            for i in st.pinned..<st.p.count {
                XCTAssertLessThan(st.p[i].dist(st.p[i - 1]), HairSim.seg * 1.6)
            }
        }
    }

    /// Hair left alone comes to rest (it used to flicker and fly around the head forever).
    func testHairComesToRest() {
        for seed: UInt64 in [3, 8, 21] {
            for length in 0...3 {
                let s = HairSim(recipe: HairRecipe(seed: seed, color: 2, length: length, fringe: 6, curl: seed == 8 ? 0.8 : 0,
                                                   tangle: 0.8), palette: DressUpArt.shared.hair)
                s.settle(seconds: 6)
                let before = s.strands.map(\.p)
                s.settle(seconds: 1)
                var most: CGFloat = 0
                var where_ = ""
                for (i, st) in s.strands.enumerated() {
                    for k in st.p.indices where k < before[i].count {
                        let d = st.p[k].dist(before[i][k])
                        if d > most { most = d; where_ = "\(st.kind) lock, point \(k - st.pinned) at \(Int(st.p[k].x)),\(Int(st.p[k].y))" }
                    }
                    // bangs stop above her eyebrows
                    if st.kind == .fringe { XCTAssertLessThan(st.tip.y, 300) }
                }
                XCTAssertLessThan(most, 2, "seed \(seed) length \(length): \(where_)")
            }
        }
    }

    func testScissorsCutAndPiecesFall() {
        let s = sim()
        s.settle(seconds: 1)
        let before = s.strands.map(\.free).reduce(0, +)
        let cuts = s.cut(from: HairV(60, 520), to: HairV(540, 520))
        XCTAssertFalse(cuts.isEmpty)
        XCTAssertEqual(s.pieces.count, cuts.count)
        XCTAssertLessThan(s.strands.map(\.free).reduce(0, +), before)
        for st in s.strands { XCTAssertGreaterThanOrEqual(st.free, 1) }
        s.settle(seconds: 3)
        for p in s.pieces { for q in p.p { XCTAssertLessThanOrEqual(q.y, SalonBody.floorY + 0.5) } }
    }

    func testGrowPotionRegrows() {
        let s = sim()
        _ = s.cut(from: HairV(60, 360), to: HairV(540, 360))
        let short = s.strands.map(\.free).reduce(0, +)
        for _ in 0..<60 {
            for st in s.strands { _ = s.grow(near: st.tip, radius: 10, dt: 1.0 / 30) }
            s.step(1.0 / 60)
        }
        XCTAssertGreaterThan(s.strands.map(\.free).reduce(0, +), short)
        for st in s.strands { XCTAssertLessThanOrEqual(st.free, HairSim.maxFree) }
    }

    func testCurlDyeAndSaveRoundTrip() {
        let s = sim()
        s.settle(seconds: 1)
        for st in s.strands { _ = s.curlUp(st.tip, dt: 0.5) }
        _ = s.dye(HairV(300, 200), dt: 1) { _ in RGB(1, 0, 0) }
        _ = s.attach(.bow, color: 4, at: HairV(390, 200))
        let save = s.save(positions: true)
        let data = try! JSONEncoder().encode(save)
        let back = HairSim(save: try! JSONDecoder().decode(HairSim.Save.self, from: data), palette: DressUpArt.shared.hair)
        XCTAssertEqual(back.strands.count, s.strands.count)
        for (a, b) in zip(s.strands, back.strands) {
            XCTAssertEqual(a.free, b.free)
            for i in 0..<a.p.count {
                XCTAssertEqual(HairSim.hex(a.color[i]), HairSim.hex(b.color[i]))
                XCTAssertEqual(a.curl[i], b.curl[i], accuracy: 0.03)
                XCTAssertEqual(a.p[i].x, b.p[i].x, accuracy: 1)
            }
        }
        XCTAssertEqual(back.clips.count, 1)
    }

    func testScrunchieMakesAPonytail() {
        let s = sim()
        s.settle(seconds: 1)
        XCTAssertTrue(s.tie(at: HairV(168, 420), color: 3))
        s.settle(seconds: 1)
        let t = s.ties[0]
        for m in t.members { XCTAssertLessThan(s.strands[m.strand].p[m.node].dist(t.at), 12) }
    }

    func testSoundsAndClientsExist() {
        for sfx in SalonSFX.allCases { XCTAssertNotNil(GameFiles.url(sfx.rawValue, "wav", game: "Salon"), sfx.rawValue) }
        let c = SalonWorld.makeClient(seed: 9)
        XCTAssertNil(c.0.picks["hairBack"])
        XCTAssertNotNil(c.0.picks["eyes"])
        XCTAssertTrue(GameRegistry.all.contains { $0.id == "salon" })
        for h in SalonView.hats { XCTAssertNotNil(DressUpArt.shared.items[h], h) }
    }
}
