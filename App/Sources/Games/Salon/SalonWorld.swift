import AVFoundation
import SwiftUI

// MARK: - The salon chair: client, hair, tools and effects, stepped and drawn every frame
//
// `SalonWorld` is a plain class kept in the view's @State; the stage's TimelineView calls `frame(at:)`
// every display refresh, which steps the hair and the effects and applies whatever tool her finger
// is holding. Gestures only record where the finger is (`press`, `move`, `release`).

// MARK: Sounds

enum SalonSFX: String, CaseIterable {
    case snip, water, squish, dryer, sizzle, comb, spray, magic, clip, shutter, rub, drip, giggle, bloop, chime
}

final class SalonSound {
    static let shared = SalonSound()
    private let queue = DispatchQueue(label: "glimmie.salon.sound", qos: .userInitiated)
    private var players: [SalonSFX: [AVAudioPlayer]] = [:]
    private var last: [String: Date] = [:]

    private init() {
        _ = Sound.shared
    }

    static func url(for s: SalonSFX) -> URL? {
        GameFiles.url(s.rawValue, "caf", game: "Salon") ?? GameFiles.url(s.rawValue, "wav", game: "Salon")
    }

    func play(_ s: SalonSFX, volume: Float = 0.8, gap: Double = 0) {
        queue.async {
            if gap > 0 {
                let now = Date()
                if let t = self.last[s.rawValue], now.timeIntervalSince(t) < gap { return }
                self.last[s.rawValue] = now
            }
            let pool: [AVAudioPlayer]
            if let existing = self.players[s] {
                pool = existing
            } else if let url = Self.url(for: s) {
                let created: [AVAudioPlayer] = (0..<3).compactMap { _ in
                    let p = try? AVAudioPlayer(contentsOf: url)
                    p?.prepareToPlay()
                    return p
                }
                self.players[s] = created
                pool = created
            } else {
                self.players[s] = []
                return
            }
            guard !pool.isEmpty else { return }
            let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            p.volume = volume
            p.currentTime = 0
            p.play()
        }
    }

    func play(_ s: SFX, volume: Float = 0.8, gap: Double) {
        queue.async {
            let now = Date()
            if let t = self.last["shared." + s.rawValue], now.timeIntervalSince(t) < gap { return }
            self.last["shared." + s.rawValue] = now
            Sound.shared.play(s, volume: volume)
        }
    }
}

/// Lightweight shared appearance snapshot written by Dress Up in `UserDefaults.standard`
/// so Salon can bring her own doll into the chair without touching Dress Up's `GameStorage` folder.
enum SalonDollDefaults {
    static let skinHexKey = "glimmie.doll.skinHex"
    static let hairHexKey = "glimmie.doll.hairHex"
    static let eyeHexKey = "glimmie.doll.eyeHex"

    static let defaultSkinIndex = 1
    static let defaultHairIndex = 3
    static let defaultEyeIndex = 6

    static func nearestIndex(hex: String?, in palette: [RGB], fallback: Int) -> Int {
        guard !palette.isEmpty else { return 0 }
        let safeFallback = min(max(0, fallback), palette.count - 1)
        guard let raw = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return safeFallback
        }
        let clean = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        guard clean.count >= 6, UInt32(clean.prefix(6), radix: 16) != nil else {
            return safeFallback
        }
        let target = RGB(hex: clean)
        var bestIdx = safeFallback
        var bestDist = Double.greatestFiniteMagnitude
        for (i, c) in palette.enumerated() {
            let dr = c.r - target.r
            let dg = c.g - target.g
            let db = c.b - target.b
            let d = dr * dr + dg * dg + db * db
            if d < bestDist {
                bestDist = d
                bestIdx = i
            }
        }
        return bestIdx
    }

    static func colors(from defaults: UserDefaults = .standard) -> (skin: RGB, hair: RGB, eye: RGB) {
        let art = DressUpArt.shared
        let skinIdx = nearestIndex(hex: defaults.string(forKey: skinHexKey), in: art.skin, fallback: defaultSkinIndex)
        let hairIdx = nearestIndex(hex: defaults.string(forKey: hairHexKey), in: art.hair, fallback: defaultHairIndex)
        let eyeIdx = nearestIndex(hex: defaults.string(forKey: eyeHexKey), in: art.eye, fallback: defaultEyeIndex)
        let skin = art.skin.indices.contains(skinIdx) ? art.skin[skinIdx] : RGB(hex: "#FFDCCB")
        let hair = art.hair.indices.contains(hairIdx) ? art.hair[hairIdx] : RGB(hex: "#C98A55")
        let eye = art.eye.indices.contains(eyeIdx) ? art.eye[eyeIdx] : RGB(hex: "#5C9BEB")
        return (skin, hair, eye)
    }
}

// MARK: Effects

struct SalonBit {
    enum Kind { case drop, splash, suds, bubble, steam, air, sparkle, glitter, dye, dust, prop }
    var kind: Kind
    var p: HairV
    var v: HairV
    var life: Double
    var size: CGFloat
    var color: RGB = RGB(1, 1, 1)
    var age: Double = 0
    var spin: CGFloat = 0
    var angle: CGFloat = 0
    var clip: HairClip?
    var hits = 0
    var resting = false
}

/// Something she is carrying from the tray to the hair.
enum SalonCarry: Equatable {
    case clip(HairClip.Kind, Int)
    case scrunchie(Int)
}

/// A finished client (what the photo wall and the save keep).
struct SalonVisit: Codable, Identifiable {
    var id = UUID()
    var look: Look
    var hair: HairSim.Save
    var cape: Int
    var hat: String?
    var saved = Date()
}

final class SalonWorld {
    // layout (design space is DesignCanvas's, 834 tall)
    static let k: CGFloat = 1.02
    static let headY: CGFloat = 298
    static let defaultCenterX: CGFloat = 487
    static let floorDesignDefault: CGFloat = headY + (SalonBody.floorY - 287) * k
    /// Clips ride well above her finger so she can see where they go (see `FingerLift`).
    static func carried(_ finger: CGPoint) -> CGPoint {
        FingerLift.point(finger, lift: FingerLift.item, bottom: DesignCanvas<EmptyView>.designHeight)
    }
    /// The finger point that carries a clip to design point p (away from the top edge).
    static func carrying(to p: CGPoint) -> CGPoint {
        FingerLift.finger(for: p, lift: FingerLift.item, bottom: DesignCanvas<EmptyView>.designHeight)
    }
    var centerX: CGFloat = SalonWorld.defaultCenterX

    func toDesign(_ a: HairV) -> CGPoint {
        CGPoint(x: centerX + (a.x - 300) * SalonWorld.k, y: SalonWorld.headY + (a.y - 287) * SalonWorld.k)
    }

    func toArt(_ d: CGPoint) -> HairV {
        HairV((d.x - centerX) / SalonWorld.k + 300, (d.y - SalonWorld.headY) / SalonWorld.k + 287)
    }

    var floorDesign: CGFloat { toDesign(HairV(0, SalonBody.floorY)).y }

    // the client
    private(set) var look: Look
    private(set) var sim: HairSim
    var cape: Int
    var hat: String?
    private(set) var visitID = UUID()

    // tools
    var tool: SalonTool?
    var dyeColor: Int = 0
    var glitterColor: Int = 0
    var carry: SalonCarry?
    /// Where the carried clip is (design space), while she drags it from the tray or hair.
    var carryPoint: CGPoint?
    var carryOffset: CGSize = .zero
    private(set) var carryFromHair = false
    /// A clip she picked off the hair to move, lifted smoothly from its hair position.
    var moving: HairClip?
    var movingOffset: CGSize = .zero
    var movingTie: Int?
    /// A scrunchie she touched: a tap switches its style, a drag picks it up.
    private var tappedTie: Int?
    /// Brief scissors snip animation shown when she taps to cut.
    private(set) var scissorsFlash: (at: CGPoint, started: Date)?
    /// Where the chair is turning to (0 facing us, steps of a sixth of a turn).
    private(set) var turnTarget: CGFloat = 0

    var isDraggingFromHair: Bool { moving != nil || (carry != nil && carryFromHair) }

    var draggedItemDesignPoint: CGPoint? {
        if moving != nil, let f = finger {
            return CGPoint(x: f.x + movingOffset.width, y: f.y + movingOffset.height)
        }
        if carry != nil, let p = carryPoint {
            return CGPoint(x: p.x + carryOffset.width, y: p.y + carryOffset.height)
        }
        return nil
    }

    // finger (design space)
    private(set) var finger: CGPoint?
    private var path: [CGPoint] = []
    private var lastTip: HairV?
    private var downAt = Date.distantPast
    private var movedSinceDown: CGFloat = 0

    // effects
    private(set) var bits: [SalonBit] = []
    private var lastFrame: Date?
    private var time: Double = 0
    private var rng = SystemRandomNumberGenerator()
    private(set) var scissorsOpen: CGFloat = 0.6

    // her face
    private var nextBlink = Date().addingTimeInterval(2.5)
    private var blinkUntil = Date.distantPast
    private var shutUntil = Date.distantPast
    private var happyUntil = Date.distantPast
    private var hopAt = Date.distantPast
    var changed = false

    // styling progress (for coin reward gating and safe photo-wall auto-backup)
    private(set) var hasBeenStyled = false
    private(set) var hasUnrewardedStyling = false
    private(set) var savedSinceStyle = false

    static let dyeColors: [RGB] = [
        RGB(hex: "#FF5C9A"), RGB(hex: "#FF9EC0"), RGB(hex: "#E8475A"), RGB(hex: "#FFA24C"), RGB(hex: "#FFE27A"),
        RGB(hex: "#6CCB8B"), RGB(hex: "#46B7B0"), RGB(hex: "#5C9BEB"), RGB(hex: "#A9D8FF"), RGB(hex: "#9B79E0"),
        RGB(hex: "#D2C0FF"), RGB(hex: "#3A3340"), RGB(hex: "#F7E9C4"), RGB(hex: "#B9B7C6"),
    ]
    /// Swatches after the plain colors: rainbow, then her natural color.
    static var rainbowIndex: Int { dyeColors.count }
    static var naturalIndex: Int { dyeColors.count + 1 }

    static let glitterColors: [RGB] = [
        RGB(hex: "#FFD66E"), RGB(hex: "#E9EEF8"), RGB(hex: "#FF8FC4"), RGB(hex: "#9CCBFF"), RGB(hex: "#C9B6FF"), RGB(hex: "#9FE3CF"),
    ]

    static let capeColors: [Int] = [3, 15, 18, 11, 9, 2, 7]

    static var hairPalette: [RGB] { DressUpArt.shared.hair }

    init(visit: SalonVisit?) {
        if let v = visit {
            look = v.look
            sim = HairSim(save: v.hair, palette: SalonWorld.hairPalette)
            cape = v.cape
            hat = v.hat
            visitID = v.id
        } else {
            let c = SalonWorld.makeClient()
            look = c.0
            sim = c.1
            cape = SalonWorld.capeColors.randomElement() ?? 3
        }
        look.picks["hat"] = hat
        turnTarget = sim.yaw
    }

    /// Turns the chair a sixth of the way around (negative: the other way).
    func turn(_ step: Int) {
        turnTarget += CGFloat(step) * .pi / 3
        SalonSound.shared.play(.boing, volume: 0.25, gap: 0.15)
        changed = true
    }

    // MARK: Clients

    static func makeClient(seed: UInt64? = nil) -> (Look, HairSim) {
        var g = SeededGenerator(seed: seed ?? UInt64.random(in: 1...UInt64.max))
        let art = DressUpArt.shared
        var look = Look()
        func pick(_ cat: String) -> String? { art.category(cat)?.items.randomElement(using: &g) }
        look.skin = Int.random(in: 0..<max(1, art.skin.count), using: &g)
        look.eye = Int.random(in: 0..<max(1, art.eye.count), using: &g)
        look.picks = [:]
        for c in ["face", "eyes", "brows", "mouth", "nose", "cheeks"] { look.picks[c] = pick(c) }
        // happy faces for the salon chair
        let mouths = ["m_smile", "m_open", "m_cat", "m_grin", "m_tiny", "m_big"]
        look.picks["mouth"] = mouths.randomElement(using: &g)
        let brows = ["br_soft", "br_happy", "br_short"]
        look.picks["brows"] = brows.randomElement(using: &g)
        look = look.sanitized(art)
        for cat in ["hairBack", "hairFront", "hat", "dress", "top", "bottom", "shoes", "socks"] { look.picks[cat] = nil }
        let recipe = HairRecipe.random(using: &g)
        look.hair = recipe.color
        let sim = HairSim(recipe: recipe, palette: hairPalette)
        // a messy day: some leaves and twigs to comb out
        let mess = Int.random(in: 0...3, using: &g)
        for _ in 0..<mess {
            let candidates = sim.strands.indices.filter { sim.strands[$0].kind != .nape && sim.strands[$0].free >= 3 }
            guard let si = candidates.randomElement(using: &g) else { break }
            let s = sim.strands[si]
            let node = s.pinned + Int.random(in: 1..<s.free, using: &g)
            let kind: HairClip.Kind = Bool.random(using: &g) ? .leaf : .twig
            sim.clips.append(HairClip(kind: kind, color: 0, strand: si, node: node, dx: CGFloat.random(in: -6...6, using: &g),
                                      dy: CGFloat.random(in: -6...6, using: &g), tilt: CGFloat.random(in: -1...1, using: &g)))
        }
        sim.settle(seconds: 2)
        return (look, sim)
    }

    static func makeMyDollClient(defaults: UserDefaults = .standard) -> (Look, HairSim) {
        let art = DressUpArt.shared
        var look = Look.starter
        look.skin = SalonDollDefaults.nearestIndex(
            hex: defaults.string(forKey: SalonDollDefaults.skinHexKey),
            in: art.skin,
            fallback: SalonDollDefaults.defaultSkinIndex
        )
        look.hair = SalonDollDefaults.nearestIndex(
            hex: defaults.string(forKey: SalonDollDefaults.hairHexKey),
            in: art.hair,
            fallback: SalonDollDefaults.defaultHairIndex
        )
        look.eye = SalonDollDefaults.nearestIndex(
            hex: defaults.string(forKey: SalonDollDefaults.eyeHexKey),
            in: art.eye,
            fallback: SalonDollDefaults.defaultEyeIndex
        )
        look = look.sanitized(art)
        for cat in ["hairBack", "hairFront", "hat", "dress", "top", "bottom", "shoes", "socks"] { look.picks[cat] = nil }
        let recipe = HairRecipe(seed: 108, color: look.hair, length: 2, fringe: 4, curl: 0.15, tangle: 0.05)
        let sim = HairSim(recipe: recipe, palette: hairPalette)
        sim.settle(seconds: 2)
        return (look, sim)
    }

    func loadMyDoll(defaults: UserDefaults = .standard) {
        let c = SalonWorld.makeMyDollClient(defaults: defaults)
        look = c.0
        sim = c.1
        cape = 3
        hat = nil
        visitID = UUID()
        bits.removeAll()
        moving = nil
        movingOffset = .zero
        cancelCarry()
        tappedTie = nil
        scissorsFlash = nil
        turnTarget = 0
        hasBeenStyled = false
        hasUnrewardedStyling = false
        savedSinceStyle = false
        changed = true
    }

    func newClient() {
        let c = SalonWorld.makeClient()
        look = c.0
        sim = c.1
        cape = SalonWorld.capeColors.randomElement() ?? 3
        hat = nil
        visitID = UUID()
        bits.removeAll()
        moving = nil
        movingOffset = .zero
        cancelCarry()
        tappedTie = nil
        scissorsFlash = nil
        turnTarget = 0
        hasBeenStyled = false
        hasUnrewardedStyling = false
        savedSinceStyle = false
        changed = true
    }

    func load(_ v: SalonVisit) {
        look = v.look
        sim = HairSim(save: v.hair, palette: SalonWorld.hairPalette)
        cape = v.cape
        hat = v.hat
        look.picks["hat"] = hat
        visitID = UUID()
        bits.removeAll()
        moving = nil
        movingOffset = .zero
        cancelCarry()
        tappedTie = nil
        scissorsFlash = nil
        turnTarget = sim.yaw
        hasBeenStyled = false
        hasUnrewardedStyling = false
        savedSinceStyle = false
        changed = true
    }

    func markStyled() {
        hasBeenStyled = true
        hasUnrewardedStyling = true
        savedSinceStyle = false
        changed = true
    }

    func consumeCoinReward() -> Bool {
        guard hasUnrewardedStyling else { return false }
        hasUnrewardedStyling = false
        return true
    }

    func markSavedToWall() {
        savedSinceStyle = true
    }

    func visit(positions: Bool) -> SalonVisit {
        var l = look
        l.picks["hat"] = nil
        return SalonVisit(id: visitID, look: l, hair: sim.save(positions: positions), cape: cape, hat: hat)
    }

    func wearHat(_ id: String?) {
        hat = (hat == id) ? nil : id
        look.picks["hat"] = hat
        markStyled()
        if let h = hat, ["h_crown", "h_tiara", "h_starcrown", "h_halo", "h_unicorn"].contains(h) {
            SalonFind.sparkleCrown.unlock()
        }
    }

    func cheer() {
        happyUntil = Date().addingTimeInterval(1.6)
        hopAt = Date()
    }

    // MARK: Fingers

    /// Where a tool works for her finger at f (design space): just ahead of her finger, held by its handle (see `FingerLift`).
    /// The shower rains down from above her finger (`FingerLift.pour`).
    func tipDesign(_ f: CGPoint) -> CGPoint {
        tool == nil ? f : FingerLift.point(f, lift: toolLift, bottom: DesignCanvas<EmptyView>.designHeight, width: centerX * 2 + 50)
    }

    private var toolLift: CGFloat { tool == .shower ? FingerLift.pour : FingerLift.tool }

    /// The finger point that puts the tool tip at design point d (away from the top edge).
    func fingerFor(tip d: CGPoint) -> CGPoint {
        tool == nil ? d : FingerLift.finger(for: d, lift: toolLift, bottom: DesignCanvas<EmptyView>.designHeight, width: centerX * 2 + 50)
    }

    func tip(_ finger: CGPoint) -> HairV { toArt(tipDesign(finger)) }

    func press(_ p: CGPoint) {
        finger = p
        path = [p]
        lastTip = tip(p)
        downAt = Date()
        movedSinceDown = 0
        if tool == .clips && carry == nil {
            grabClip(near: toArt(p), fingerDesign: p)
        } else if tool == nil && carry == nil {
            grabTie(near: toArt(p))
        }
    }

    func move(_ p: CGPoint) {
        if let f = finger { movedSinceDown += hypot(p.x - f.x, p.y - f.y) }
        finger = p
        if moving != nil && movedSinceDown > 4 {
            let target = FingerLift.offset(p, lift: FingerLift.item, bottom: DesignCanvas<EmptyView>.designHeight)
            movingOffset = FingerLift.ease(movingOffset, toward: target, by: 0.25)
        }
        if let i = tappedTie, movedSinceDown > 18 {
            tappedTie = nil
            if i < sim.ties.count {
                let tie = sim.ties.remove(at: i)
                let tieDesign = toDesign(tie.at)
                let initOff = CGSize(width: tieDesign.x - p.x, height: tieDesign.y - p.y)
                startCarry(.scrunchie(tie.color), at: p, fromHair: true, initialOffset: initOff)
                SalonSound.shared.play(.boing, volume: 0.35, gap: 0.2)
                changed = true
            }
        }
        path.append(p)
        if carry != nil { moveCarry(to: p) }
    }

    func startCarry(_ c: SalonCarry, at designPoint: CGPoint, fromHair: Bool = false, initialOffset: CGSize = .zero) {
        carry = c
        carryPoint = designPoint
        carryFromHair = fromHair
        carryOffset = initialOffset
    }

    func moveCarry(to designPoint: CGPoint) {
        carryPoint = designPoint
        let target = FingerLift.offset(designPoint, lift: FingerLift.item, bottom: DesignCanvas<EmptyView>.designHeight)
        carryOffset = FingerLift.ease(carryOffset, toward: target, by: 0.28)
    }

    func cancelCarry() {
        carry = nil
        carryPoint = nil
        carryFromHair = false
        carryOffset = .zero
    }

    func discardCarried() {
        moving = nil
        movingOffset = .zero
        cancelCarry()
        Sound.shared.play(.whoosh, volume: 0.55)
        Sound.shared.tap()
        changed = true
    }

    func release(discarding: Bool = false) {
        guard finger != nil else { return }
        let f = finger ?? CGPoint(x: centerX, y: SalonWorld.headY)
        let q = toArt(f)
        let quick = movedSinceDown < 12 && Date().timeIntervalSince(downAt) < 0.35
        if let i = tappedTie {
            tappedTie = nil
            _ = restyle(tieIndex: i)
        } else if tool == nil && quick && moving == nil && carry == nil {
            if !restyle(at: q) && cos(sim.yaw) > 0.5 && SalonBody.onFace(q) { tickle() }
        }
        if discarding && isDraggingFromHair {
            discardCarried()
        } else {
            if carry != nil {
                dropCarry(at: f)
            }
            if let c = moving {
                let dropDesign = CGPoint(x: f.x + movingOffset.width, y: f.y + movingOffset.height)
                let dropArt = toArt(dropDesign)
                moving = nil
                movingOffset = .zero
                if !sim.attach(c.kind, color: c.color, at: dropArt) {
                    fall(HairClip(kind: c.kind, color: c.color, strand: 0, node: 0, dx: 0, dy: 0), at: dropArt, v: HairV(0, -60))
                } else {
                    SalonSound.shared.play(.clip)
                    markStyled()
                }
                changed = true
            }
        }
        finger = nil
        path.removeAll()
        lastTip = nil
        sim.dryer = nil
    }

    /// A clip or bow from the tray lands at design point p.
    func dropCarry(at p: CGPoint) {
        guard let c = carry else { return }
        let targetDesign: CGPoint
        if carryPoint != nil {
            targetDesign = CGPoint(x: p.x + carryOffset.width, y: p.y + carryOffset.height)
        } else {
            targetDesign = SalonWorld.carried(p)
        }
        cancelCarry()
        let q = toArt(targetDesign)
        switch c {
        case .clip(let kind, let color):
            if sim.attach(kind, color: color, at: q) {
                SalonSound.shared.play(.clip)
                sparkle(at: q, count: 6)
                cheerSmall()
                markStyled()
            } else if q.y > 0 && q.y < 900 && q.x > 0 && q.x < 600 {
                fall(HairClip(kind: kind, color: color, strand: 0, node: 0, dx: 0, dy: 0), at: q, v: HairV(0, -40))
            }
        case .scrunchie(let color):
            if tryTie(at: q, color: color) {
                break
            } else if sim.attach(.ribbon, color: color, at: q) {
                SalonSound.shared.play(.clip)
                markStyled()
            }
        }
        changed = true
    }

    /// Ties a scrunchie at q (art space) if there is enough hair there.
    func tryTie(at q: HairV, color: Int) -> Bool {
        guard sim.tie(at: q, color: color) else { return false }
        SalonSound.shared.play(.clip)
        SalonSound.shared.play(.boing, volume: 0.4, gap: 0.2)
        sparkle(at: q, count: 8)
        cheerSmall()
        markStyled()
        return true
    }

    private func grabClip(near q: HairV, fingerDesign: CGPoint) {
        var best: (Int, CGFloat, HairV)?
        for (i, c) in sim.clips.enumerated() {
            guard let at = sim.clipPosition(c) else { continue }
            let d = at.dist(q)
            if d < 44 && d < (best?.1 ?? .greatestFiniteMagnitude) { best = (i, d, at) }
        }
        if let b = best {
            moving = sim.clips.remove(at: b.0)
            let clipDesign = toDesign(b.2)
            movingOffset = CGSize(width: clipDesign.x - fingerDesign.x, height: clipDesign.y - fingerDesign.y)
            SalonSound.shared.play(.clip, volume: 0.5)
            return
        }
        grabTie(near: q)
    }

    private func grabTie(near q: HairV) {
        var best: (Int, CGFloat)?
        for (i, t) in sim.ties.enumerated() where SalonBody.visible(t.at, t.z, squash: sim.squash) {
            let d = t.at.dist(q)
            if d < 48 && d < (best?.1 ?? .greatestFiniteMagnitude) { best = (i, d) }
        }
        if let b = best {
            tappedTie = b.0
        }
    }

    /// A tap on a scrunchie: ponytail, then braid, then bun, then back to a ponytail.
    private func restyle(at q: HairV) -> Bool {
        guard let style = sim.restyle(near: q) else { return false }
        finishRestyle(style, at: q)
        return true
    }

    private func restyle(tieIndex i: Int) -> Bool {
        guard sim.ties.indices.contains(i) else { return false }
        let at = sim.ties[i].at
        guard let style = sim.restyle(tieIndex: i) else { return false }
        finishRestyle(style, at: at)
        return true
    }

    private func finishRestyle(_ style: HairTie.Style, at q: HairV) {
        SalonSound.shared.play(.clip)
        if style == .bun {
            SalonSound.shared.play(.boing, volume: 0.5, gap: 0.2)
        } else {
            SalonSound.shared.play(SalonSFX.comb, volume: 0.5, gap: 0.2)
        }
        sparkle(at: q, count: 10)
        cheerSmall()
        markStyled()
        if style == .braid || style == .bun {
            SalonFind.updoArtist.unlock()
        }
    }

    /// One crisp horizontal 70pt scissors snip centered on a tap in design space.
    @discardableResult
    func tapSnip(at designPoint: CGPoint) -> [HairV] {
        scissorsFlash = (designPoint, Date())
        scissorsOpen = 0
        return tapSnip(atArt: toArt(designPoint))
    }

    @discardableResult
    func tapSnip(atArt q: HairV) -> [HairV] {
        let cuts = snip(HairV(q.x - 35, q.y), HairV(q.x + 35, q.y))
        if cuts.isEmpty {
            SalonSound.shared.play(.snip, volume: 0.45, gap: 0.07)
        }
        return cuts
    }

    private func tickle() {
        happyUntil = Date().addingTimeInterval(0.9)
        hopAt = Date()
        SalonSound.shared.play(.giggle, volume: 0.6, gap: 0.5)
    }

    private func cheerSmall() {
        if Date() > happyUntil { happyUntil = Date().addingTimeInterval(0.7) }
    }

    // MARK: Each frame

    func frame(at now: Date) {
        let dt = min(1.0 / 20, max(0, now.timeIntervalSince(lastFrame ?? now)))
        lastFrame = now
        time += dt
        guard dt > 0 else { return }
        if let f = finger { useTool(at: f, dt: dt, now: now) }
        // the chair turns smoothly to where she sent it
        let gap = turnTarget - sim.yaw
        if abs(gap) > 0.0005 {
            let step = gap * min(1, CGFloat(dt) * 5)
            let fastest = CGFloat(dt) * 4.5
            sim.yaw += max(-fastest, min(fastest, step))
        }
        sim.advance(dt)
        collectDropped()
        stepBits(dt, now: now)
        // a wet head drips
        for (si, s) in sim.strands.enumerated() where s.wet > 0.25 && s.front {
            if Double.random(in: 0..<1, using: &rng) < Double(s.wet) * dt * 1.6 {
                bits.append(SalonBit(kind: .drop, p: s.tip, v: HairV(0, 60), life: 2.5, size: 3.2, hits: 3))
                if si % 3 == 0 { SalonSound.shared.play(.drip, volume: 0.25, gap: 0.5) }
            }
        }
        // she dries slowly on her own
        for i in sim.strands.indices where sim.strands[i].wet > 0 {
            sim.strands[i].wet = max(0, sim.strands[i].wet - CGFloat(dt) * 0.008)
        }
        if now > nextBlink {
            blinkUntil = now.addingTimeInterval(0.14)
            nextBlink = now.addingTimeInterval(Double.random(in: 2.4...5, using: &rng))
        }
        if let flash = scissorsFlash, now.timeIntervalSince(flash.started) > 0.26 {
            scissorsFlash = nil
        }
        if finger == nil && tool == .scissors { scissorsOpen += (0.6 - scissorsOpen) * 0.2 }
    }

    private func useTool(at f: CGPoint, dt: Double, now: Date) {
        let h = CGFloat(dt)
        let pts = path.isEmpty ? [f] : path
        path = [f]
        let q = tip(f)
        let q0 = lastTip ?? q
        lastTip = q
        let moved = q.dist(q0)
        switch tool {
        case nil:
            guard tappedTie == nil && moving == nil && carry == nil else { return }
            var a = q0
            var caught = 0
            let droppedBefore = sim.dropped.count
            for p in pts.dropFirst() {
                let b = tip(p)
                caught += sim.comb(from: a, to: b, radius: 40, detangle: 0.08, gloss: 0.02)
                a = b
            }
            if sim.dropped.count > droppedBefore {
                for d in sim.dropped[droppedBefore...] where d.clip != nil {
                    sparkle(at: d.at, count: 6)
                }
                Sound.shared.play(.sparkle, volume: 0.4)
                cheerSmall()
                markStyled()
            } else if caught > 0 {
                changed = true
            }
        case .comb?:
            var a = q0
            var caught = 0
            let droppedBefore = sim.dropped.count
            for p in pts.dropFirst() {
                let b = tip(p)
                caught += sim.comb(from: a, to: b, radius: 42 * FingerLift.spread, detangle: 0.25, gloss: 0.12, looseChance: 0.6)
                a = b
            }
            if caught == 0 && moved > 0.3 {
                caught = sim.comb(from: q0, to: q, radius: 42 * FingerLift.spread, detangle: 0.25, gloss: 0.12, looseChance: 0.6)
            }
            if caught > 0 {
                SalonSound.shared.play(.comb, volume: 0.55, gap: 0.22)
                markStyled()
                if Double.random(in: 0..<1, using: &rng) < 0.22 {
                    sparkle(at: q + HairV(rnd(-20, 20), rnd(-14, 14)), count: 1)
                }
            }
            if sim.dropped.count > droppedBefore {
                for d in sim.dropped[droppedBefore...] where d.clip != nil {
                    sparkle(at: d.at, count: 7)
                }
                Sound.shared.play(.sparkle, volume: 0.45)
                cheerSmall()
            }
        case .scissors?:
            var a = q0
            for p in pts.dropFirst() {
                let b = tip(p)
                _ = snip(a, b)
                a = b
            }
            if moved > 0.5 { scissorsOpen = 0.5 + 0.5 * CGFloat(sin(time * 26)) }
        case .shampoo?:
            if sim.lather(q, dt: h) > 0 {
                SalonSound.shared.play(.squish, volume: 0.5, gap: 0.28)
                markStyled()
                if sim.foam.count >= 10 { SalonFind.bubbleWash.unlock() }
            }
            if Double.random(in: 0..<1, using: &rng) < 0.25 {
                bits.append(SalonBit(kind: .bubble, p: q + HairV(rnd(-20, 20), rnd(-10, 10)) * FingerLift.spread, v: HairV(rnd(-20, 20), rnd(-70, -30)),
                                     life: rndD(1.2, 2.2), size: rnd(4, 9)))
            }
            if moved > 3 && Double.random(in: 0..<1, using: &rng) < 0.04 { tickle() }
        case .shower?:
            for _ in 0..<8 {
                bits.append(SalonBit(kind: .drop, p: q + HairV(rnd(-16, 16) * FingerLift.spread, rnd(-4, 4)), v: HairV(rnd(-70, 70), rnd(380, 520)),
                                     life: 2.5, size: rnd(2.6, 4.2)))
            }
            SalonSound.shared.play(.water, volume: 0.45, gap: 0.42)
        case .towel?:
            if moved > 1.5 && sim.towel(q, dt: h) > 0 {
                SalonSound.shared.play(.rub, volume: 0.45, gap: 0.3)
                markStyled()
            }
        case .dryer?:
            let dir = (SalonBody.center - q).unit
            sim.dryer = (q, dir)
            let dried = sim.dry(from: q, dir: dir, dt: h)
            if dried > 0 {
                markStyled()
                if Double.random(in: 0..<1, using: &rng) < 0.35 {
                    let puffAt = q + dir * rnd(50, 175) + dir.perp * rnd(-35, 35)
                    bits.append(SalonBit(kind: .sparkle, p: puffAt, v: dir * rnd(80, 160) + HairV(0, rnd(-40, 10)),
                                         life: rndD(0.45, 0.8), size: rnd(6, 11), color: [RGB(1, 0.92, 0.62), RGB(1, 0.98, 0.9), RGB(1, 0.8, 0.68)].randomElement()!))
                }
            }
            if Double.random(in: 0..<1, using: &rng) < 0.6 {
                let side = dir.perp * rnd(-16, 16)
                bits.append(SalonBit(kind: .air, p: q + side, v: dir * rnd(360, 500) + dir.perp * rnd(-30, 30), life: 0.45, size: rnd(14, 26)))
            }
            if SalonToolArt.hasStarDryer && Double.random(in: 0..<1, using: &rng) < 0.78 {
                let rainbow: [RGB] = [
                    RGB(hex: "#FF7DB8"), RGB(hex: "#FFB870"), RGB(hex: "#FFE670"),
                    RGB(hex: "#7EE0B5"), RGB(hex: "#84C5FF"), RGB(hex: "#CFA6FF"),
                ]
                let pick = rainbow[Int.random(in: 0..<rainbow.count, using: &rng)]
                let side = dir.perp * rnd(-14, 14)
                bits.append(SalonBit(kind: .sparkle, p: q + dir * rnd(10, 28) + side,
                                     v: dir * rnd(260, 420) + dir.perp * rnd(-48, 48),
                                     life: rndD(0.45, 0.78), size: rnd(6.5, 12.5), color: pick))
            }
            SalonSound.shared.play(.dryer, volume: 0.5, gap: 0.5)
        case .curler?:
            if sim.curlUp(q, dt: h) > 0 {
                SalonSound.shared.play(.sizzle, volume: 0.35, gap: 0.45)
                markStyled()
                if Double.random(in: 0..<1, using: &rng) < 0.3 { steam(at: q) }
            }
        case .straightener?:
            // the iron glides the hair along with it (and works out tangles and leaves, like a comb)
            var a = q0
            for p in pts.dropFirst() {
                let b = tip(p)
                sim.comb(from: a, to: b, radius: 30 * FingerLift.spread, detangle: 0.05)
                a = b
            }
            if sim.straighten(q, dt: h) > 0 {
                SalonSound.shared.play(.sizzle, volume: 0.3, gap: 0.5)
                markStyled()
                if Double.random(in: 0..<1, using: &rng) < 0.25 { steam(at: q) }
                if Double.random(in: 0..<1, using: &rng) < 0.15 { sparkle(at: q + HairV(rnd(-20, 20), rnd(0, 40)), count: 1) }
            }
        case .dye?:
            let pick = dyeColor
            let t0 = time
            let n = sim.dye(q, dt: h) { p in self.dyeFor(pick, at: p, strandTime: t0) }
            if n > 0 {
                SalonSound.shared.play(.comb, volume: 0.3, gap: 0.3)
                markStyled()
                if pick == SalonWorld.rainbowIndex {
                    SalonFind.rainbowStylist.unlock()
                }
            }
            if moved > 1 && Double.random(in: 0..<1, using: &rng) < 0.5 {
                bits.append(SalonBit(kind: .dye, p: q, v: HairV(rnd(-60, 60), rnd(-60, 20)), life: 0.5, size: rnd(2, 4),
                                     color: dyeFor(pick, at: q, strandTime: t0)))
            }
        case .glitter?:
            let c = SalonWorld.glitterColors[min(glitterColor, SalonWorld.glitterColors.count - 1)]
            if sim.sprinkleGlitter(q, color: c) > 0 {
                markStyled()
                if hat != nil && sim.flakes.count >= 8 {
                    SalonFind.sparkleCrown.unlock()
                }
            }
            for _ in 0..<2 {
                bits.append(SalonBit(kind: .glitter, p: q + HairV(rnd(-10, 10), rnd(-6, 6)) * FingerLift.spread, v: HairV(rnd(-50, 50), rnd(-20, 60)),
                                     life: rndD(2.5, 5), size: rnd(2.5, 4.5), color: c, spin: rnd(-6, 6)))
            }
            SalonSound.shared.play(.spray, volume: 0.35, gap: 0.35)
            SalonSound.shared.play(.sparkle, volume: 0.25, gap: 1.2)
        case .grow?:
            if sim.grow(near: q, radius: 64 * FingerLift.spread, dt: h) {
                SalonSound.shared.play(.magic, volume: 0.45, gap: 0.7)
                markStyled()
            }
            if Double.random(in: 0..<1, using: &rng) < 0.35 {
                bits.append(SalonBit(kind: .sparkle, p: q + HairV(rnd(-26, 26), rnd(-10, 30)), v: HairV(rnd(-20, 20), rnd(20, 70)),
                                     life: 0.9, size: rnd(6, 11), color: RGB(hex: "#E7B8FF")))
            }
        case .clips?:
            break
        }
        changed = true
    }

    func dyeFor(_ i: Int, at p: HairV, strandTime: Double) -> RGB {
        if i == SalonWorld.rainbowIndex {
            let hue = Double((p.y - 140) / 520).truncatingRemainder(dividingBy: 1)
            return SalonWorld.hsv(max(0, hue) * 0.83, 0.62, 1)
        }
        if i == SalonWorld.naturalIndex {
            return SalonWorld.hairPalette.isEmpty ? RGB(0.4, 0.3, 0.2) : SalonWorld.hairPalette[min(look.hair, SalonWorld.hairPalette.count - 1)]
        }
        return SalonWorld.dyeColors[min(max(0, i), SalonWorld.dyeColors.count - 1)]
    }

    static func hsv(_ h: Double, _ s: Double, _ v: Double) -> RGB {
        let i = Int(h * 6) % 6
        let f = h * 6 - Double(Int(h * 6))
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        switch i {
        case 0: return RGB(v, t, p)
        case 1: return RGB(q, v, p)
        case 2: return RGB(p, v, t)
        case 3: return RGB(p, q, v)
        case 4: return RGB(t, p, v)
        default: return RGB(v, p, q)
        }
    }

    @discardableResult
    private func snip(_ a: HairV, _ b: HairV) -> [HairV] {
        let cuts = sim.cut(from: a, to: b)
        guard !cuts.isEmpty else { return [] }
        SalonSound.shared.play(.snip, volume: 0.7, gap: 0.07)
        scissorsOpen = 0
        for c in cuts.prefix(4) {
            for _ in 0..<3 {
                bits.append(SalonBit(kind: .dust, p: c + HairV(rnd(-6, 6), rnd(-6, 6)), v: HairV(rnd(-60, 60), rnd(-80, 0)),
                                     life: rndD(0.8, 1.4), size: rnd(4, 7), color: sim.strands.first?.natural ?? RGB(0.4, 0.3, 0.2),
                                     spin: rnd(-8, 8), angle: rnd(0, 3)))
            }
        }
        markStyled()
        SalonFind.firstCut.unlock()
        return cuts
    }

    private func steam(at q: HairV) {
        bits.append(SalonBit(kind: .steam, p: q + HairV(rnd(-12, 12), rnd(-6, 6)), v: HairV(rnd(-14, 14), rnd(-90, -50)),
                             life: rndD(0.9, 1.5), size: rnd(10, 16)))
    }

    func sparkle(at q: HairV, count: Int) {
        for _ in 0..<count {
            bits.append(SalonBit(kind: .sparkle, p: q + HairV(rnd(-24, 24), rnd(-24, 24)), v: HairV(rnd(-40, 40), rnd(-60, 10)),
                                 life: rndD(0.6, 1.1), size: rnd(7, 13), color: [RGB(1, 0.89, 0.54), RGB(1, 1, 1), RGB(1, 0.56, 0.72)].randomElement()!))
        }
    }

    private func fall(_ c: HairClip, at q: HairV, v: HairV) {
        bits.append(SalonBit(kind: .prop, p: q, v: v, life: 5, size: 1, spin: rnd(-4, 4), angle: c.tilt, clip: c))
    }

    private func collectDropped() {
        guard !sim.dropped.isEmpty else { return }
        for d in sim.dropped {
            if let c = d.clip {
                fall(c, at: d.at, v: d.vel * 60)
            } else if d.bubble > 0 && d.at != .zero {
                bits.append(SalonBit(kind: .suds, p: d.at, v: HairV(rnd(-20, 20), rnd(0, 40)), life: rndD(1.5, 2.6), size: d.bubble))
            }
        }
        sim.dropped.removeAll()
    }

    // MARK: Effect physics

    private func stepBits(_ dt: Double, now: Date) {
        guard !bits.isEmpty else { return }
        let h = CGFloat(dt)
        var keep: [SalonBit] = []
        keep.reserveCapacity(bits.count)
        for var b in bits {
            b.age += dt
            if b.age > b.life { continue }
            switch b.kind {
            case .drop:
                b.v.y += 1500 * h
                let next = b.p + b.v * h
                if b.hits < 3 {
                    var rinsed = false
                    for (si, box) in sim.boxes.enumerated() where box.contains(next.cg) {
                        let s = sim.strands[si]
                        if s.p.contains(where: { $0.dist(next) < s.width * 0.55 }) {
                            sim.makeWet(si, 0.022)
                            if b.hits == 0 { markStyled() }
                            if sim.rinse(next, radius: 28) > 0 {
                                SalonSound.shared.play(.bloop, volume: 0.25, gap: 0.2)
                                SalonFind.bubbleWash.unlock()
                                markStyled()
                                rinsed = true
                            }
                            b.v = HairV(b.v.x * 0.5, b.v.y * 0.45)
                            b.hits += 1
                            break
                        }
                    }
                    if !rinsed && !sim.foam.isEmpty && sim.rinse(next, radius: 28) > 0 {
                        SalonSound.shared.play(.bloop, volume: 0.25, gap: 0.2)
                        SalonFind.bubbleWash.unlock()
                        markStyled()
                    }
                    if SalonBody.onFace(next) {
                        shutUntil = now.addingTimeInterval(0.6)
                        b.v = HairV(b.v.x * 0.3, min(b.v.y, 120))
                        b.hits = 3
                    }
                }
                b.p = next
                if let top = SalonBody.capeTop(b.p.x), b.p.y > top, b.p.y < SalonBody.capeBottom {
                    let m = SalonBody.capeSlope(b.p.x)
                    b.p.y = top
                    let tan = HairV(m >= 0 ? 1 : -1, abs(m)).unit
                    b.v = tan * max(120, b.v.len * 0.45)
                }
                if b.p.y >= SalonBody.floorY {
                    for _ in 0..<2 {
                        keep.append(SalonBit(kind: .splash, p: HairV(b.p.x, SalonBody.floorY - 1), v: HairV(rnd(-90, 90), rnd(-160, -80)),
                                             life: 0.4, size: b.size * 0.6))
                    }
                    continue
                }
            case .splash:
                b.v.y += 1400 * h
                b.p += b.v * h
                if b.p.y > SalonBody.floorY { continue }
            case .suds, .prop, .dust, .glitter:
                if !b.resting {
                    let g: CGFloat = b.kind == .suds ? 380 : (b.kind == .glitter ? 160 : (b.kind == .dust ? 700 : 1300))
                    b.v.y += g * h
                    if b.kind == .glitter || b.kind == .dust { b.v.x += CGFloat(sin(b.age * 7 + Double(b.size))) * 50 * h }
                    b.p += b.v * h
                    b.angle += b.spin * h
                    if let top = SalonBody.capeTop(b.p.x), b.p.y > top, b.p.y < SalonBody.capeBottom {
                        let m = SalonBody.capeSlope(b.p.x)
                        b.p.y = top
                        let tan = HairV(m >= 0 ? 1 : -1, abs(m)).unit
                        let speed = max(abs(m) > 1 ? 90 : 20, b.v.len * 0.6)
                        b.v = tan * speed
                        b.spin *= 0.8
                    }
                    if b.p.y >= SalonBody.floorY {
                        b.p.y = SalonBody.floorY
                        b.resting = true
                        if b.kind == .prop { SalonSound.shared.play(.tap, volume: 0.3, gap: 0.1) }
                    }
                }
            case .bubble:
                b.v.x += CGFloat(sin(b.age * 5 + Double(b.size))) * 40 * h
                b.v.y -= 20 * h
                b.p += b.v * h
                if b.age + dt > b.life { SalonSound.shared.play(.bloop, volume: 0.15, gap: 0.25) }
            case .steam, .air, .sparkle, .dye:
                b.p += b.v * h
                if b.kind == .steam { b.size += 18 * h }
                if b.kind == .dye { b.v.y += 400 * h }
            }
            keep.append(b)
        }
        if keep.count > 900 { keep.removeFirst(keep.count - 900) }
        bits = keep
    }

    private func rnd(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat(Double.random(in: Double(a)...Double(b), using: &rng)) }
    private func rndD(_ a: Double, _ b: Double) -> Double { Double.random(in: a...b, using: &rng) }

    // MARK: Her face

    func expression(_ now: Date) -> Expression {
        if now < happyUntil { return .happy }
        if now < shutUntil || now < blinkUntil { return .blink }
        if tool == .shower && finger != nil, let f = finger, SalonBody.onFace(tip(f) + HairV(0, 60)) { return .blink }
        return .normal
    }

    /// A little hop when she's happy (in art units).
    func hop(_ now: Date) -> CGFloat {
        let t = now.timeIntervalSince(hopAt)
        guard t < 0.5 else { return 0 }
        return CGFloat(-sin(t / 0.5 * .pi) * 10)
    }
}
