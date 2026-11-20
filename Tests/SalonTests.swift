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
                XCTAssertEqual(a.z[i], b.z[i], accuracy: 1)
            }
        }
        XCTAssertEqual(back.clips.count, 1)
    }

    /// A clip holds its bit of hair where it was clipped, even when the rest swings.
    func testClipHoldsHairInPlace() {
        let s = sim()
        s.settle(seconds: 1)
        guard let si = s.strands.indices.first(where: { s.strands[$0].kind == .side && s.strands[$0].free > 6 }) else {
            return XCTFail("no long side lock")
        }
        let node = s.strands[si].pinned + 4
        let at = s.strands[si].p[node]
        XCTAssertTrue(s.attach(.bow, color: 4, at: at))
        XCTAssertNotNil(s.clips.last?.hx)
        for i in s.strands[si].pinned..<s.strands[si].p.count { s.strands[si].p[i] += HairV(40, -30) }
        s.settle(seconds: 1)
        let c = s.clips.last!
        XCTAssertLessThan(s.strands[c.strand].p[c.node].dist(HairV(c.hx!, c.hy!)), 1)
        // leaves don't hold anything
        XCTAssertFalse(HairClip(kind: .leaf, color: 0, strand: 0, node: 0, dx: 0, dy: 0).holds)
    }

    func testScrunchieMakesAPonytail() {
        let s = sim()
        s.settle(seconds: 1)
        XCTAssertTrue(s.tie(at: HairV(168, 420), color: 3))
        s.settle(seconds: 1)
        let t = s.ties[0]
        for m in t.members { XCTAssertLessThan(s.strands[m.strand].p[m.node].dist(t.at), 12) }
    }

    /// She can be turned all the way around; the hair follows her head, stays out of it and settles.
    func testTurningAroundKeepsTheHairOnHerHead() {
        let s = HairSim(recipe: HairRecipe(seed: 5, color: 2, length: 3, fringe: 4, curl: 0, tangle: 0.5), palette: DressUpArt.shared.hair)
        s.settle(seconds: 1)
        for k in 1...60 {
            s.yaw = .pi * CGFloat(k) / 60
            s.step(1.0 / 120)
        }
        s.settle(seconds: 6)
        let before = s.strands.map(\.p)
        s.settle(seconds: 1)
        var most: CGFloat = 0
        for (i, st) in s.strands.enumerated() {
            for k in st.p.indices {
                XCTAssertTrue(st.p[k].x.isFinite && st.p[k].y.isFinite && st.z[k].isFinite)
                if k < before[i].count { most = max(most, st.p[k].dist(before[i][k])) }
                if k >= st.pinned {
                    // free hair is never inside her head
                    let ex = (st.p[k].x - 300) / SalonBody.rx, ey = (st.p[k].y - 287) / SalonBody.ry, ez = st.z[k] / SalonBody.rx
                    XCTAssertGreaterThan(ex * ex + ey * ey + ez * ez, 0.8)
                }
            }
        }
        XCTAssertLessThan(most, 2)
        // her bangs are on the far side now, behind her head
        for st in s.strands where st.kind == .fringe { XCTAssertLessThan(st.depth, 0) }
    }

    func testScrunchieTapsMakeABraidThenABun() {
        let s = HairSim(recipe: HairRecipe(seed: 4, color: 2, length: 3, fringe: 4, curl: 0, tangle: 0.5), palette: DressUpArt.shared.hair)
        s.yaw = .pi
        s.settle(seconds: 1.5)
        XCTAssertTrue(s.tie(at: HairV(300, 380), color: 3))
        XCTAssertGreaterThan(s.ties[0].members.count, 12)
        XCTAssertEqual(s.restyle(near: HairV(300, 380)), .braid)
        s.settle(seconds: 1.5)
        XCTAssertGreaterThan(s.braidChain(s.ties[0]).count, 5)
        XCTAssertNotNil(s.drawnEnd(s.ties[0].members[0].strand))
        XCTAssertEqual(s.restyle(near: HairV(300, 380)), .bun)
        XCTAssertEqual(s.restyle(near: HairV(300, 380)), .pony)
        XCTAssertNil(s.restyle(near: HairV(40, 40)))
        // turning back to the front carries the scrunchie around with her head
        s.ties[0].style = .bun
        s.yaw = 0
        s.settle(seconds: 1)
        XCTAssertLessThan(s.ties[0].z, 0)
        let save = s.save(positions: true)
        let back = HairSim(save: try! JSONDecoder().decode(HairSim.Save.self, from: JSONEncoder().encode(save)), palette: DressUpArt.shared.hair)
        XCTAssertEqual(back.ties.first?.style, .bun)
        XCTAssertEqual(back.yaw, 0, accuracy: 0.001)
    }

    func testOldSavesStartFresh() {
        var save = sim().save(positions: true)
        save.layout = nil
        save.strands.removeLast(10)
        let s = HairSim(save: save, palette: DressUpArt.shared.hair)
        XCTAssertEqual(s.strands.count, sim().strands.count)
        for st in s.strands { XCTAssertEqual(st.z.count, st.p.count) }
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
