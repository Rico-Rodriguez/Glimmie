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
        var where_ = ""
        for (i, st) in s.strands.enumerated() {
            for k in st.p.indices {
                XCTAssertTrue(st.p[k].x.isFinite && st.p[k].y.isFinite && st.z[k].isFinite)
                if k < before[i].count, st.p[k].dist(before[i][k]) > most {
                    most = st.p[k].dist(before[i][k])
                    where_ = "\(st.kind) lock, point \(k - st.pinned) at \(Int(st.p[k].x)),\(Int(st.p[k].y)),\(Int(st.z[k]))"
                }
                if k >= st.pinned {
                    // free hair is never inside her head
                    let ex = (st.p[k].x - 300) / SalonBody.rx, ey = (st.p[k].y - 287) / SalonBody.ry, ez = st.z[k] / SalonBody.rx
                    XCTAssertGreaterThan(ex * ex + ey * ey + ez * ez, 0.8)
                }
            }
        }
        XCTAssertLessThan(most, 2, where_)
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
        for sfx in SalonSFX.allCases { XCTAssertNotNil(SalonSound.url(for: sfx), sfx.rawValue) }
        let c = SalonWorld.makeClient(seed: 9)
        XCTAssertNil(c.0.picks["hairBack"])
        XCTAssertNotNil(c.0.picks["eyes"])
        XCTAssertTrue(GameRegistry.all.contains { $0.id == "salon" })
        for h in SalonView.hats { XCTAssertNotNil(DressUpArt.shared.items[h], h) }
    }

    func testCombDetanglesAddsGlossAndRemovesLeaves() {
        XCTAssertTrue(SalonTool.allCases.contains(.comb))
        let s = HairSim(recipe: HairRecipe(seed: 12, color: 2, length: 2, fringe: 4, curl: 0, tangle: 0.9), palette: DressUpArt.shared.hair)
        s.settle(seconds: 1)
        guard let si = s.strands.indices.first(where: { s.strands[$0].kind == .side && s.strands[$0].free >= 6 }) else {
            return XCTFail("expected a side strand")
        }
        let node = s.strands[si].pinned + 3
        s.clips = [
            HairClip(kind: .leaf, color: 0, strand: si, node: node, dx: 0, dy: 0),
            HairClip(kind: .twig, color: 0, strand: si, node: node + 1, dx: 0, dy: 0),
        ]
        let tangleBefore = s.strands[si].tangle
        XCTAssertGreaterThan(tangleBefore, 0.3)

        var totalCaught = 0
        for k in 0..<12 {
            let cur = s.strands[si].p[node]
            let sign: CGFloat = k % 2 == 0 ? 1 : -1
            totalCaught += s.comb(from: cur + HairV(-28 * sign, -10), to: cur + HairV(28 * sign, 10), radius: 56, detangle: 0.25)
            s.step(1.0 / 60)
        }
        XCTAssertGreaterThan(totalCaught, 0)
        XCTAssertLessThan(s.strands[si].tangle, tangleBefore * 0.2)
        XCTAssertGreaterThan(s.strands[si].gloss, 0.2)
        XCTAssertTrue(s.clips.isEmpty, "comb should knock loose leaves and twigs")
        XCTAssertEqual(s.dropped.compactMap(\.clip).count, 2)
    }

    func testSalonFindStickersRegisteredAndCoinRewardGated() {
        let expected = ["firstCut", "rainbowStylist", "bubbleWash", "updoArtist", "sparkleCrown", "salonStar"]
        XCTAssertEqual(SalonFind.allCases.count, 6)
        XCTAssertEqual(SalonFind.stickers.count, 6)
        XCTAssertEqual(SalonGame.entry.stickers.count, 6)
        XCTAssertEqual(SalonGame.entry.stickers.map(\.id), expected)

        let prevDemo = StickerBook.shared.demo
        StickerBook.shared.demo = true
        defer { StickerBook.shared.demo = prevDemo }

        let w = SalonWorld(visit: nil)
        XCTAssertFalse(w.consumeCoinReward(), "unmodified client should not pay coins before styling")
        w.wearHat("h_crown")
        XCTAssertTrue(w.hasBeenStyled)
        XCTAssertTrue(w.consumeCoinReward(), "first snap after styling should award coins")
        XCTAssertFalse(w.consumeCoinReward(), "repeated snaps without new styling must not spam coins")
    }

    func testCrispSingleSnipScissorsTap() {
        let prevDemo = StickerBook.shared.demo
        StickerBook.shared.demo = true
        defer { StickerBook.shared.demo = prevDemo }

        let base = SalonWorld.makeClient(seed: 7)
        let s = HairSim(recipe: HairRecipe(seed: 7, color: 2, length: 3, fringe: 4, curl: 0, tangle: 0.3), palette: DressUpArt.shared.hair)
        s.settle(seconds: 1)
        let visit = SalonVisit(look: base.0, hair: s.save(positions: true), cape: 3, hat: nil)
        let w = SalonWorld(visit: visit)
        w.tool = .scissors

        guard let targetStrand = w.sim.strands.first(where: { $0.kind == .side && $0.free >= 8 }) else {
            return XCTFail("expected a long side strand")
        }
        let targetArt = (targetStrand.p[targetStrand.pinned + 4] + targetStrand.p[targetStrand.pinned + 5]) * 0.5
        let freeBefore = w.sim.strands.map(\.free).reduce(0, +)
        let cuts = w.tapSnip(at: w.toDesign(targetArt))

        XCTAssertFalse(cuts.isEmpty)
        XCTAssertEqual(w.sim.pieces.count, cuts.count)
        XCTAssertLessThan(w.sim.strands.map(\.free).reduce(0, +), freeBefore)
        XCTAssertNotNil(w.scissorsFlash)
        for c in cuts {
            XCTAssertLessThanOrEqual(abs(c.x - targetArt.x), 52)
        }
    }

    func testFasterDryerDriesWithinTwoSeconds() {
        let s = sim(9)
        s.settle(seconds: 1)
        for i in s.strands.indices { s.makeWet(i, 1.0) }

        let nozzle = HairV(470, 340)
        let dir = (SalonBody.center - nozzle).unit
        let dt: CGFloat = 1.0 / 60
        for _ in 0..<120 {
            _ = s.dry(from: nozzle, dir: dir, dt: dt)
        }

        // Visible strands in the dryer cone should dry from 1.0 to nearly 0 in ~2 seconds.
        var coneWets: [CGFloat] = []
        let focus = nozzle + dir * 140
        for (si, st) in s.strands.enumerated() {
            let inCone = st.p.indices.contains { k in s.visible(si, k) && st.p[k].dist(focus) < 120 }
            if inCone { coneWets.append(st.wet) }
        }
        XCTAssertFalse(coneWets.isEmpty)
        let avgWet = coneWets.reduce(0, +) / CGFloat(coneWets.count)
        XCTAssertLessThan(avgWet, 0.15, "dryer should dry wet hair in ~2 seconds")
    }

    func testGrownBangsStayOffEyesAndRinseClearsFoam() {
        let s = sim(15)
        s.settle(seconds: 1)
        // Grow all fringe strands heavily and confirm they stay cleanly above her eyes (< 300).
        for _ in 0..<80 {
            for st in s.strands where st.kind == .fringe {
                _ = s.grow(near: st.tip, radius: 14, dt: 1.0 / 30)
            }
            s.step(1.0 / 60)
        }
        s.settle(seconds: 1)
        for st in s.strands where st.kind == .fringe {
            XCTAssertLessThan(st.tip.y, 300, "regrown bangs should frame brow and never cover her eyes")
        }

        // Lather then rinse across the suds patch with the boosted 28pt radius & 0.75 clear probability.
        let spot = HairV(300, 210)
        for _ in 0..<6 { _ = s.lather(spot, dt: 0.25) }
        let startFoam = s.foam.count
        XCTAssertGreaterThan(startFoam, 5)
        var cleared = 0
        for dy in stride(from: CGFloat(-70), through: 70, by: 35) {
            for dx in stride(from: CGFloat(-70), through: 70, by: 35) {
                cleared += s.rinse(spot + HairV(dx, dy), radius: 28)
            }
        }
        XCTAssertGreaterThan(cleared, 0)
        XCTAssertLessThan(s.foam.count, max(3, startFoam / 3))
    }

    func testKoreanAndMagicalAccessoriesAttachAndRoundTrip() throws {
        let newKinds: [HairClip.Kind] = [.daenggi, .pastelBow, .heartJewel]
        for kind in newKinds {
            XCTAssertTrue(
                SalonView.clipChoices.contains {
                    if case .clip(let k, _) = $0 { return k == kind }
                    return false
                },
                "expected \(kind.rawValue) in SalonView.clipChoices"
            )
            XCTAssertTrue(HairClip(kind: kind, color: 4, strand: 0, node: 0, dx: 0, dy: 0).holds)
        }

        let s = sim(21)
        s.settle(seconds: 1)
        XCTAssertTrue(s.attach(.daenggi, color: 5, at: HairV(390, 220)))
        XCTAssertTrue(s.attach(.pastelBow, color: 2, at: HairV(210, 220)))
        XCTAssertTrue(s.attach(.heartJewel, color: 4, at: HairV(300, 175)))

        let encoded = try JSONEncoder().encode(s.save(positions: true))
        let decoded = try JSONDecoder().decode(HairSim.Save.self, from: encoded)
        let restored = HairSim(save: decoded, palette: DressUpArt.shared.hair)
        XCTAssertEqual(Set(restored.clips.map(\.kind)), Set(newKinds))
    }

    func testMyDollClientReadsUserDefaultsAndFallsBackCleanly() {
        let suite = "com.glimmie.tests.salon.mydoll.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("could not create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let art = DressUpArt.shared

        // Fallback when Dress Up hasn't written appearance keys yet.
        let fallback = SalonWorld.makeMyDollClient(defaults: defaults)
        XCTAssertEqual(fallback.0.skin, min(SalonDollDefaults.defaultSkinIndex, max(0, art.skin.count - 1)))
        XCTAssertEqual(fallback.0.hair, min(SalonDollDefaults.defaultHairIndex, max(0, art.hair.count - 1)))
        XCTAssertEqual(fallback.0.eye, min(SalonDollDefaults.defaultEyeIndex, max(0, art.eye.count - 1)))
        XCTAssertNil(fallback.0.picks["hairBack"])
        XCTAssertNotNil(fallback.0.picks["eyes"])
        XCTAssertFalse(fallback.1.strands.isEmpty)

        // Exact palette hex lookup when Dress Up writes shared appearance keys.
        let wantSkin = min(3, max(0, art.skin.count - 1))
        let wantHair = min(0, max(0, art.hair.count - 1))
        let wantEye = min(2, max(0, art.eye.count - 1))
        func hexString(_ c: RGB) -> String {
            String(format: "#%02X%02X%02X", Int((c.r * 255).rounded()), Int((c.g * 255).rounded()), Int((c.b * 255).rounded()))
        }
        defaults.set(hexString(art.skin[wantSkin]), forKey: SalonDollDefaults.skinHexKey)
        defaults.set(hexString(art.hair[wantHair]), forKey: SalonDollDefaults.hairHexKey)
        defaults.set(hexString(art.eye[wantEye]), forKey: SalonDollDefaults.eyeHexKey)

        let world = SalonWorld(visit: nil)
        world.loadMyDoll(defaults: defaults)
        XCTAssertEqual(world.look.skin, wantSkin)
        XCTAssertEqual(world.look.hair, wantHair)
        XCTAssertEqual(world.look.eye, wantEye)
        XCTAssertFalse(world.hasBeenStyled)

        // Malformed hex falls back safely without crashing.
        defaults.set("not-a-hex", forKey: SalonDollDefaults.skinHexKey)
        let safe = SalonWorld.makeMyDollClient(defaults: defaults)
        XCTAssertEqual(safe.0.skin, min(SalonDollDefaults.defaultSkinIndex, max(0, art.skin.count - 1)))
    }

    func testSalonTreasureHooksUnlockRoyalDaenggiAndStarDryer() throws {
        Coins.shared.resetForTests(balance: 60)
        defer { Coins.shared.resetForTests() }

        XCTAssertEqual(ClipPainter.royalDaenggiTreasureID, "salon/royalDaenggi")
        XCTAssertEqual(SalonToolArt.starDryerTreasureID, "salon/starDryer")
        XCTAssertFalse(ClipPainter.hasRoyalDaenggi)
        XCTAssertFalse(SalonToolArt.hasStarDryer)
        XCTAssertEqual(SalonView.availableClipChoices, SalonView.clipChoices)

        XCTAssertTrue(Coins.shared.buy(ClipPainter.royalDaenggiTreasureID, price: 10))
        XCTAssertTrue(ClipPainter.hasRoyalDaenggi)
        XCTAssertEqual(SalonView.availableClipChoices.count, SalonView.clipChoices.count + 1)
        XCTAssertEqual(SalonView.availableClipChoices.first, .clip(.royalDaenggi, 5))
        XCTAssertTrue(HairClip(kind: .royalDaenggi, color: 5, strand: 0, node: 0, dx: 0, dy: 0).holds)

        let s = sim(29)
        s.settle(seconds: 1)
        XCTAssertTrue(s.attach(.royalDaenggi, color: 5, at: HairV(390, 220)))
        let encoded = try JSONEncoder().encode(s.save(positions: true))
        let decoded = try JSONDecoder().decode(HairSim.Save.self, from: encoded)
        let restored = HairSim(save: decoded, palette: DressUpArt.shared.hair)
        XCTAssertEqual(restored.clips.first?.kind, .royalDaenggi)

        // Dry hair emits no sparkles without starDryer, and emits rainbow sparkles once owned.
        let baseWorld = SalonWorld(visit: SalonVisit(look: SalonWorld.makeClient(seed: 12).0, hair: s.save(positions: true), cape: 3, hat: nil))
        baseWorld.tool = .dryer
        let t0 = Date(timeIntervalSinceReferenceDate: 1000)
        baseWorld.press(CGPoint(x: 660, y: 360))
        baseWorld.frame(at: t0)
        for k in 1...20 {
            baseWorld.frame(at: t0.addingTimeInterval(Double(k) / 60))
        }
        XCTAssertEqual(baseWorld.bits.filter { $0.kind == .sparkle }.count, 0)

        XCTAssertTrue(Coins.shared.buy(SalonToolArt.starDryerTreasureID, price: 12))
        XCTAssertTrue(SalonToolArt.hasStarDryer)
        for k in 21...45 {
            baseWorld.frame(at: t0.addingTimeInterval(Double(k) / 60))
        }
        XCTAssertGreaterThan(baseWorld.bits.filter { $0.kind == .sparkle }.count, 0)
    }
}
