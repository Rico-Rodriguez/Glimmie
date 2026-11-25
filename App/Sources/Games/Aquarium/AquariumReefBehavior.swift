import SwiftUI

enum AquaDecorAnchorRole: String, Codable, Equatable, Hashable {
    case swimThrough
    case hideout
    case sleepBed
}

struct AquaDecorAnchorSpec: Equatable {
    let role: AquaDecorAnchorRole
    let offset: CGPoint
    let entryOffset: CGPoint
    let exitOffset: CGPoint
    let radius: CGFloat

    init(
        role: AquaDecorAnchorRole,
        offset: CGPoint,
        entryOffset: CGPoint = .zero,
        exitOffset: CGPoint = .zero,
        radius: CGFloat = 24
    ) {
        self.role = role
        self.offset = offset
        self.entryOffset = entryOffset
        self.exitOffset = exitOffset
        self.radius = radius
    }

    func worldPoint(for decor: AquaDecor) -> CGPoint {
        let sign: CGFloat = decor.flip ? -1 : 1
        return CGPoint(x: decor.x + sign * offset.x, y: decor.y + offset.y)
    }

    func worldEntry(for decor: AquaDecor, direction: CGFloat) -> CGPoint {
        let sign: CGFloat = decor.flip ? -1 : 1
        let a = CGPoint(x: decor.x + sign * entryOffset.x, y: decor.y + entryOffset.y)
        let b = CGPoint(x: decor.x + sign * exitOffset.x, y: decor.y + exitOffset.y)
        if direction >= 0 {
            return a.x <= b.x ? a : b
        }
        return a.x >= b.x ? a : b
    }

    func worldExit(for decor: AquaDecor, direction: CGFloat) -> CGPoint {
        let sign: CGFloat = decor.flip ? -1 : 1
        let a = CGPoint(x: decor.x + sign * entryOffset.x, y: decor.y + entryOffset.y)
        let b = CGPoint(x: decor.x + sign * exitOffset.x, y: decor.y + exitOffset.y)
        if direction >= 0 {
            return a.x <= b.x ? b : a
        }
        return a.x >= b.x ? b : a
    }
}

extension AquaDecorKind {
    var anchorSpecs: [AquaDecorAnchorSpec] {
        switch self {
        case .koiBridge:
            return [
                AquaDecorAnchorSpec(
                    role: .swimThrough,
                    offset: CGPoint(x: 0, y: -26),
                    entryOffset: CGPoint(x: -78, y: -26),
                    exitOffset: CGPoint(x: 78, y: -26),
                    radius: 28
                ),
            ]
        case .castle:
            return [
                AquaDecorAnchorSpec(role: .hideout, offset: CGPoint(x: 0, y: -26), radius: 24),
                AquaDecorAnchorSpec(role: .sleepBed, offset: CGPoint(x: -44, y: -32), radius: 26),
            ]
        case .ship:
            return [
                AquaDecorAnchorSpec(role: .hideout, offset: CGPoint(x: -14, y: -36), radius: 22),
                AquaDecorAnchorSpec(
                    role: .swimThrough,
                    offset: CGPoint(x: 10, y: -96),
                    entryOffset: CGPoint(x: -74, y: -96),
                    exitOffset: CGPoint(x: 78, y: -96),
                    radius: 28
                ),
            ]
        case .rock:
            return [
                AquaDecorAnchorSpec(role: .hideout, offset: CGPoint(x: -2, y: -26), radius: 24),
            ]
        case .shell:
            return [
                AquaDecorAnchorSpec(role: .sleepBed, offset: CGPoint(x: 0, y: -24), radius: 24),
            ]
        case .anemone:
            return [
                AquaDecorAnchorSpec(role: .sleepBed, offset: CGPoint(x: 0, y: -46), radius: 26),
            ]
        case .coral:
            return [
                AquaDecorAnchorSpec(role: .sleepBed, offset: CGPoint(x: 0, y: -52), radius: 28),
            ]
        case .rainbowCoral:
            return [
                AquaDecorAnchorSpec(role: .sleepBed, offset: CGPoint(x: 0, y: -58), radius: 28),
            ]
        case .chest, .diver, .bubbler, .seaweed, .grass, .starfish, .crystal, .unicorn:
            return []
        }
    }

    func anchorSpec(for role: AquaDecorAnchorRole) -> AquaDecorAnchorSpec? {
        anchorSpecs.first { $0.role == role }
    }
}

enum AquaFishActivity: Equatable {
    case cruising
    case swimmingThrough(decorID: Int, phase: Int)
    case hiding(decorID: Int, peek: CGFloat, until: Double)
    case sleeping(decorID: Int?, nest: CGPoint, until: Double)
}

enum AquaFloatingGiftKind: String, CaseIterable, Equatable {
    case pearl
    case bubbleGift
    case starShell
}

struct AquaFloatingGift: Identifiable, Equatable {
    var id: Int
    var kind: AquaFloatingGiftKind
    var p: CGPoint
    var vy: CGFloat = -22
    var phase: CGFloat = 0
    var age: CGFloat = 0
    var life: CGFloat = 15
}

enum AquaEggPattern: Equatable {
    case goldfishScales
    case clownStripes
    case angelBands
    case tetraNeon
    case pufferPolka
    case bettaVeil
    case guppyConfetti
    case seahorseRings
    case axolotlFrills
    case seaBunnyDots
    case narwhalSwirl

    static func forSpecies(_ species: FishKind) -> AquaEggPattern {
        switch species {
        case .goldfish: return .goldfishScales
        case .clownfish: return .clownStripes
        case .angelfish: return .angelBands
        case .tetra: return .tetraNeon
        case .puffer: return .pufferPolka
        case .betta: return .bettaVeil
        case .guppy: return .guppyConfetti
        case .seahorse: return .seahorseRings
        case .axolotl: return .axolotlFrills
        case .seaBunny: return .seaBunnyDots
        case .narwhal: return .narwhalSwirl
        }
    }

    var shellHex: UInt32 {
        switch self {
        case .goldfishScales: return 0xFFE3BD
        case .clownStripes: return 0xFFA468
        case .angelBands: return 0xF1F3FA
        case .tetraNeon: return 0xD2EEFF
        case .pufferPolka: return 0xFFF0B4
        case .bettaVeil: return 0xE5D0FF
        case .guppyConfetti: return 0xD4F8EC
        case .seahorseRings: return 0xFFE2BA
        case .axolotlFrills: return 0xFFD4E8
        case .seaBunnyDots: return 0xFFFBF5
        case .narwhalSwirl: return 0xD6E8FF
        }
    }

    var markHex: UInt32 {
        switch self {
        case .goldfishScales: return 0xFF9C4A
        case .clownStripes: return 0xFFFFFF
        case .angelBands: return 0x7A7490
        case .tetraNeon: return 0x35CFFF
        case .pufferPolka: return 0xD89A3E
        case .bettaVeil: return 0xFF7EC8
        case .guppyConfetti: return 0xFF7FA8
        case .seahorseRings: return 0xF5A84A
        case .axolotlFrills: return 0xFF6B9E
        case .seaBunnyDots: return 0x4A3A58
        case .narwhalSwirl: return 0xFFD252
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .goldfishScales: return 0xFFF0A6
        case .clownStripes: return 0x3B2A35
        case .angelBands: return 0xFFE58A
        case .tetraNeon: return 0xFF5274
        case .pufferPolka: return 0xFFF6C2
        case .bettaVeil: return 0x8CE6FF
        case .guppyConfetti: return 0xFFE066
        case .seahorseRings: return 0xFFF4C8
        case .axolotlFrills: return 0xFFF2B2
        case .seaBunnyDots: return 0xFFADC8
        case .narwhalSwirl: return 0xC9B6FF
        }
    }
}

enum AquaPlayWishKind: Equatable {
    case hoopTrick
    case pearlPellet
    case nightGlow
    case glassPolish
    case ribbonDance
    case decorPlay(AquaDecorKind, AquaDecorAnchorRole)
}

enum AquaWishBearer: Equatable {
    case fish(id: Int)
    case visitor(AVisitorKind)
}

struct AquaActiveWish: Identifiable, Equatable {
    var id: Int
    var bearer: AquaWishBearer
    var kind: AquaPlayWishKind
    var createdAt: Double
    var expiresAt: Double
}

struct AquaDrainedEffects: Equatable {
    var coins: Int
    var stickers: [String]
    var saved: Bool
}

enum AquaSandLayout {
    static let sandMinX: CGFloat = AGeo.left + 40
    static let sandMaxX: CGFloat = AGeo.right - 40
    static let defaultClamX: [CGFloat] = [188, 396, 628, 842]
    static let defaultHiddenX: [CGFloat] = [245, 455, 695, 865]
    static let clamHalfWidth: CGFloat = 22
    static let eggHalfWidth: CGFloat = 24

    static func openIntervals(
        for decor: [AquaDecor],
        eggs: [AquaEgg] = [],
        margin: CGFloat
    ) -> [ClosedRange<CGFloat>] {
        let grounded = decor.filter { !$0.held && !$0.falling }
        let groundedEggs = eggs.filter { !$0.falling }
        let blocked = mergedBlockedRanges(for: grounded, eggs: groundedEggs, margin: margin)
        var open: [ClosedRange<CGFloat>] = []
        var cursor = sandMinX
        for range in blocked {
            if range.lowerBound > cursor + 4 {
                open.append(cursor...range.lowerBound)
            }
            cursor = max(cursor, range.upperBound)
        }
        if sandMaxX > cursor + 4 {
            open.append(cursor...sandMaxX)
        }
        return open
    }

    static func resolve(
        decor: [AquaDecor],
        eggs: [AquaEgg] = [],
        clams: [AquaSingingClam],
        hiddenSpots: [AquaHiddenSpot]
    ) -> (clams: [AquaSingingClam], hiddenSpots: [AquaHiddenSpot]) {
        let grounded = decor.filter { !$0.held && !$0.falling }
        let groundedEggs = eggs.filter { !$0.falling }
        let clamIntervals = selectIntervals(for: grounded, eggs: groundedEggs, preferredMargin: clamHalfWidth)
        let spotIntervals = selectIntervals(for: grounded, eggs: groundedEggs, preferredMargin: 12)
        let blockedRaw = mergedBlockedRanges(for: grounded, eggs: groundedEggs, margin: 0)

        var placedClams: [CGFloat] = []
        var resolvedClams = clams
        for idx in resolvedClams.indices {
            let slotIndex = max(0, resolvedClams[idx].id) % defaultClamX.count
            let preferred = defaultClamX[slotIndex]
            let chosen = pickSandX(
                preferred: preferred,
                openIntervals: clamIntervals,
                blocked: blockedRaw,
                avoid: placedClams,
                minSpacing: 46
            )
            placedClams.append(chosen)
            resolvedClams[idx].x = chosen
            resolvedClams[idx].y = AGeo.sand(chosen) - 8
        }

        var placedHidden: [CGFloat] = []
        var resolvedHidden = hiddenSpots
        for idx in resolvedHidden.indices {
            let slotIndex = max(0, resolvedHidden[idx].id) % defaultHiddenX.count
            let preferred = defaultHiddenX[slotIndex]
            let chosen = pickSandX(
                preferred: preferred,
                openIntervals: spotIntervals,
                blocked: blockedRaw,
                avoid: placedHidden + placedClams,
                minSpacing: 34
            )
            placedHidden.append(chosen)
            let yOff: CGFloat = resolvedHidden[idx].kind == .glowSeahorse ? -18 : 0
            resolvedHidden[idx].p = CGPoint(x: chosen, y: AGeo.sand(chosen) + yOff)
        }

        return (resolvedClams, resolvedHidden)
    }

    private static func selectIntervals(
        for grounded: [AquaDecor],
        eggs groundedEggs: [AquaEgg],
        preferredMargin: CGFloat
    ) -> [ClosedRange<CGFloat>] {
        let roomy = openIntervals(for: grounded, eggs: groundedEggs, margin: preferredMargin)
        let roomySpan = roomy.reduce(CGFloat(0)) { $0 + ($1.upperBound - $1.lowerBound) }
        if roomySpan >= 180 { return roomy }
        let medium = openIntervals(for: grounded, eggs: groundedEggs, margin: min(12, preferredMargin))
        let mediumSpan = medium.reduce(CGFloat(0)) { $0 + ($1.upperBound - $1.lowerBound) }
        if mediumSpan >= 140 { return medium }
        let tight = openIntervals(for: grounded, eggs: groundedEggs, margin: 0)
        let tightSpan = tight.reduce(CGFloat(0)) { $0 + ($1.upperBound - $1.lowerBound) }
        return tightSpan >= 48 ? tight : []
    }

    private static func mergedBlockedRanges(
        for grounded: [AquaDecor],
        eggs groundedEggs: [AquaEgg],
        margin: CGFloat
    ) -> [ClosedRange<CGFloat>] {
        var raw: [ClosedRange<CGFloat>] = grounded.compactMap { d in
            let half = d.kind.size.width * 0.5 + margin
            let lo = max(sandMinX, d.x - half)
            let hi = min(sandMaxX, d.x + half)
            guard hi > lo else { return nil }
            return lo...hi
        }
        for e in groundedEggs {
            let half = eggHalfWidth + margin
            let lo = max(sandMinX, e.x - half)
            let hi = min(sandMaxX, e.x + half)
            if hi > lo { raw.append(lo...hi) }
        }
        raw.sort { $0.lowerBound < $1.lowerBound }

        var merged: [ClosedRange<CGFloat>] = []
        for range in raw {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    private static func pickSandX(
        preferred: CGFloat,
        openIntervals: [ClosedRange<CGFloat>],
        blocked: [ClosedRange<CGFloat>],
        avoid: [CGFloat],
        minSpacing: CGFloat
    ) -> CGFloat {
        let clampedPref = max(sandMinX, min(sandMaxX, preferred))
        if openIntervals.contains(where: { $0.contains(clampedPref) }),
           avoid.allSatisfy({ abs($0 - clampedPref) >= minSpacing }) {
            return clampedPref
        }

        if !openIntervals.isEmpty {
            var candidates: [CGFloat] = []
            for interval in openIntervals {
                let lo = interval.lowerBound
                let hi = interval.upperBound
                candidates.append(lo)
                candidates.append(hi)
                candidates.append((lo + hi) * 0.5)
                if interval.contains(clampedPref) {
                    candidates.append(clampedPref)
                }
                var x = lo + 8
                while x < hi {
                    candidates.append(x)
                    x += 8
                }
            }

            let spaced = candidates.filter { c in avoid.allSatisfy { abs($0 - c) >= minSpacing } }
            if let best = spaced.min(by: { abs($0 - clampedPref) < abs($1 - clampedPref) }) {
                return best
            }
            if let widest = candidates.max(by: { a, b in
                let da = avoid.map { abs($0 - a) }.min() ?? 999
                let db = avoid.map { abs($0 - b) }.min() ?? 999
                if abs(da - db) > 1 { return da < db }
                return abs(a - clampedPref) > abs(b - clampedPref)
            }) {
                return widest
            }
        }

        // Fallback when the floor is completely packed wall-to-wall with decor.
        var fallback: [CGFloat] = []
        var x = sandMinX
        while x <= sandMaxX {
            fallback.append(x)
            x += 12
        }
        return fallback.max(by: { a, b in
            let pa = overlapDepth(a, in: blocked)
            let pb = overlapDepth(b, in: blocked)
            if abs(pa - pb) > 2 { return pa > pb }
            let da = avoid.map { abs($0 - a) }.min() ?? 999
            let db = avoid.map { abs($0 - b) }.min() ?? 999
            if abs(da - db) > 2 { return da < db }
            return abs(a - clampedPref) > abs(b - clampedPref)
        }) ?? clampedPref
    }

    private static func overlapDepth(_ x: CGFloat, in blocked: [ClosedRange<CGFloat>]) -> CGFloat {
        for r in blocked where r.contains(x) {
            return min(x - r.lowerBound, r.upperBound - x)
        }
        return 0
    }
}
