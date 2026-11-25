import SwiftUI

struct WingPoint: Codable, Equatable, Hashable {
    var u: Float
    var v: Float

    private enum CodingKeys: String, CodingKey {
        case u
        case v
    }

    init(u: Float, v: Float) {
        self.u = min(1, max(0, u))
        self.v = min(1, max(-1, v))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawU = try c.decode(Float.self, forKey: .u)
        let rawV = try c.decode(Float.self, forKey: .v)
        self.init(u: rawU, v: rawV)
    }
}

enum WingBrushColor: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case rosePearl
    case peachGlow
    case butterStar
    case mintDew
    case skyOpal
    case lilacMist
    case orchidShimmer
    case snowCrystal

    var id: String { rawValue }

    var baseHex: UInt32 {
        switch self {
        case .rosePearl: return 0xFF88C4
        case .peachGlow: return 0xFFA886
        case .butterStar: return 0xFFE066
        case .mintDew: return 0x7AE4C4
        case .skyOpal: return 0x7AC8FF
        case .lilacMist: return 0xC49CFF
        case .orchidShimmer: return 0xEC82E0
        case .snowCrystal: return 0xFFF4FC
        }
    }

    var shimmerHex: UInt32 {
        switch self {
        case .rosePearl: return 0xFFE0F2
        case .peachGlow: return 0xFFF0D4
        case .butterStar: return 0xFFFFD8
        case .mintDew: return 0xD8FFF4
        case .skyOpal: return 0xE0F6FF
        case .lilacMist: return 0xF0E4FF
        case .orchidShimmer: return 0xFFE2FA
        case .snowCrystal: return 0xD2EEFF
        }
    }
}

struct WingBrushStroke: Codable, Equatable, Hashable {
    var color: WingBrushColor
    var width: Float
    var points: [WingPoint]

    init(color: WingBrushColor, width: Float = 0.088, points: [WingPoint]) {
        self.color = color
        self.width = max(0.02, min(0.24, width))
        self.points = points
    }
}

struct WingGlitterFleck: Codable, Equatable, Hashable {
    var point: WingPoint
    var colorHex: UInt32
    var size: Float
    var twinklePhase: Float

    init(point: WingPoint, colorHex: UInt32, size: Float = 0.048, twinklePhase: Float = 0) {
        self.point = point
        self.colorHex = colorHex
        self.size = max(0.015, min(0.12, size))
        self.twinklePhase = twinklePhase
    }
}

enum WingStampKind: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case dewdrop
    case star
    case heart
    case blossom
    case crescent

    var id: String { rawValue }

    var accentHex: UInt32 {
        switch self {
        case .dewdrop: return 0x86E0FF
        case .star: return 0xFFE066
        case .heart: return 0xFF7CB6
        case .blossom: return 0xFFAAD2
        case .crescent: return 0xD4B8FF
        }
    }
}

struct WingStamp: Codable, Equatable, Hashable {
    var kind: WingStampKind
    var point: WingPoint
    var scale: Float
    var tintHex: UInt32

    init(kind: WingStampKind, point: WingPoint, scale: Float = 1.0, tintHex: UInt32? = nil) {
        self.kind = kind
        self.point = point
        self.scale = max(0.5, min(1.8, scale))
        self.tintHex = tintHex ?? kind.accentHex
    }
}

struct FairyWingDesign: Codable, Equatable, Hashable {
    static let maxStrokePoints = 180
    static let maxGlitterFlecks = 90
    static let maxStamps = 12

    var strokes: [WingBrushStroke]
    var glitter: [WingGlitterFleck]
    var stamps: [WingStamp]

    private enum CodingKeys: String, CodingKey {
        case strokes
        case glitter
        case stamps
    }

    init(
        strokes: [WingBrushStroke] = [],
        glitter: [WingGlitterFleck] = [],
        stamps: [WingStamp] = []
    ) {
        self.strokes = strokes
        self.glitter = glitter
        self.stamps = stamps
        trimToBudget()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.strokes = (try? c.decodeIfPresent([WingBrushStroke].self, forKey: .strokes)) ?? []
        self.glitter = (try? c.decodeIfPresent([WingGlitterFleck].self, forKey: .glitter)) ?? []
        self.stamps = (try? c.decodeIfPresent([WingStamp].self, forKey: .stamps)) ?? []
        trimToBudget()
    }

    var isEmpty: Bool {
        strokes.isEmpty && glitter.isEmpty && stamps.isEmpty
    }

    var totalStrokePoints: Int {
        strokes.reduce(0) { $0 + $1.points.count }
    }

    var distinctBrushColors: Set<WingBrushColor> {
        Set(strokes.map(\.color))
    }

    mutating func trimToBudget() {
        if stamps.count > Self.maxStamps {
            stamps.removeFirst(stamps.count - Self.maxStamps)
        }
        if glitter.count > Self.maxGlitterFlecks {
            glitter.removeFirst(glitter.count - Self.maxGlitterFlecks)
        }
        strokes.removeAll { $0.points.isEmpty }
        var overflow = totalStrokePoints - Self.maxStrokePoints
        while overflow > 0 && !strokes.isEmpty {
            if strokes[0].points.count <= overflow {
                overflow -= strokes[0].points.count
                strokes.removeFirst()
            } else {
                strokes[0].points.removeFirst(overflow)
                overflow = 0
            }
        }
    }
}

enum WandTopper: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case heartGem
    case starBurst
    case crescentMoon
    case blossomCrown
    case butterflyCrystal

    var id: String { rawValue }

    var gemHex: UInt32 {
        switch self {
        case .heartGem: return 0xFF6BA8
        case .starBurst: return 0xFFD447
        case .crescentMoon: return 0xB89EFF
        case .blossomCrown: return 0xFF9AC8
        case .butterflyCrystal: return 0x7CE6D8
        }
    }
}

enum WandShaft: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case pearlPink
    case goldTwist
    case skyCrystal
    case mintVine
    case lilacStar

    var id: String { rawValue }

    var primaryHex: UInt32 {
        switch self {
        case .pearlPink: return 0xFFD2E6
        case .goldTwist: return 0xFFE082
        case .skyCrystal: return 0xBEE8FF
        case .mintVine: return 0xB8F0DC
        case .lilacStar: return 0xDEC8FF
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .pearlPink: return 0xFF8EBC
        case .goldTwist: return 0xE6A432
        case .skyCrystal: return 0x6EC4FA
        case .mintVine: return 0x5CC79E
        case .lilacStar: return 0xA478F0
        }
    }
}

enum WandRibbon: String, CaseIterable, Codable, Equatable, Hashable, Identifiable {
    case roseSilk
    case rainbowStream
    case starlightGold
    case celadonJade
    case lavenderMist

    var id: String { rawValue }

    var colors: [UInt32] {
        switch self {
        case .roseSilk: return [0xFF8EC2, 0xFFD2E8]
        case .rainbowStream: return [0xFF8EC2, 0xFFE07D, 0x8CE6CC, 0x9CCBFF]
        case .starlightGold: return [0xFFE07D, 0xFFF6C4]
        case .celadonJade: return [0x8AE0C4, 0xFF9AB8]
        case .lavenderMist: return [0xC6A4FF, 0xFFD4EE]
        }
    }
}

struct FairyWandDesign: Codable, Equatable, Hashable {
    var topper: WandTopper
    var shaft: WandShaft
    var ribbon: WandRibbon

    static func starter(for fairyID: String) -> FairyWandDesign {
        switch fairyID {
        case "heart": return FairyWandDesign(topper: .heartGem, shaft: .pearlPink, ribbon: .roseSilk)
        case "star": return FairyWandDesign(topper: .starBurst, shaft: .goldTwist, ribbon: .starlightGold)
        case "berry": return FairyWandDesign(topper: .heartGem, shaft: .mintVine, ribbon: .roseSilk)
        case "cloud": return FairyWandDesign(topper: .starBurst, shaft: .skyCrystal, ribbon: .rainbowStream)
        case "ribbon": return FairyWandDesign(topper: .butterflyCrystal, shaft: .lilacStar, ribbon: .lavenderMist)
        case "moon": return FairyWandDesign(topper: .crescentMoon, shaft: .lilacStar, ribbon: .starlightGold)
        case "melody": return FairyWandDesign(topper: .butterflyCrystal, shaft: .mintVine, ribbon: .rainbowStream)
        case "peach": return FairyWandDesign(topper: .blossomCrown, shaft: .pearlPink, ribbon: .roseSilk)
        case "dewdrop": return FairyWandDesign(topper: .butterflyCrystal, shaft: .skyCrystal, ribbon: .celadonJade)
        case "honey": return FairyWandDesign(topper: .starBurst, shaft: .goldTwist, ribbon: .starlightGold)
        case "blossom": return FairyWandDesign(topper: .blossomCrown, shaft: .pearlPink, ribbon: .rainbowStream)
        case "silk": return FairyWandDesign(topper: .blossomCrown, shaft: .mintVine, ribbon: .celadonJade)
        default: return FairyWandDesign(topper: .heartGem, shaft: .pearlPink, ribbon: .roseSilk)
        }
    }
}

struct PinnedFairyLook: Codable, Equatable {
    static let defaultsKey = "glimmie.pinnedFairyLook"

    var fairyID: String
    var accessoryID: String?
    var wingDesign: FairyWingDesign
    var wand: FairyWandDesign

    private enum CodingKeys: String, CodingKey {
        case fairyID
        case accessoryID
        case wingDesign
        case wand
    }

    init(
        fairyID: String,
        accessoryID: String? = nil,
        wingDesign: FairyWingDesign = FairyWingDesign(),
        wand: FairyWandDesign? = nil
    ) {
        self.fairyID = fairyID
        self.accessoryID = accessoryID
        var trimmed = wingDesign
        trimmed.trimToBudget()
        self.wingDesign = trimmed
        self.wand = wand ?? FairyWandDesign.starter(for: fairyID)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .fairyID)
        let acc = try? c.decodeIfPresent(String.self, forKey: .accessoryID)
        var wings = (try? c.decodeIfPresent(FairyWingDesign.self, forKey: .wingDesign)) ?? FairyWingDesign()
        wings.trimToBudget()
        let wand = (try? c.decodeIfPresent(FairyWandDesign.self, forKey: .wand)) ?? FairyWandDesign.starter(for: id)
        self.fairyID = id
        self.accessoryID = acc
        self.wingDesign = wings
        self.wand = wand
    }
}

enum PinnedFairyCodec {
    static let legacyFairyKey = "glimmie.pinnedFairy"

    static func write(fairyID: String?, look: PinnedFairyLook?, to defaults: UserDefaults = .standard) {
        guard let rawID = fairyID?.trimmingCharacters(in: .whitespacesAndNewlines), !rawID.isEmpty else {
            defaults.removeObject(forKey: legacyFairyKey)
            defaults.removeObject(forKey: PinnedFairyLook.defaultsKey)
            return
        }
        defaults.set(rawID, forKey: legacyFairyKey)
        if var resolvedLook = look, resolvedLook.fairyID == rawID {
            resolvedLook.wingDesign.trimToBudget()
            if let data = try? JSONEncoder().encode(resolvedLook) {
                defaults.set(data, forKey: PinnedFairyLook.defaultsKey)
            }
        } else {
            defaults.removeObject(forKey: PinnedFairyLook.defaultsKey)
        }
    }

    static func read(from defaults: UserDefaults = .standard) -> (fairyID: String, look: PinnedFairyLook?)? {
        guard let rawID = defaults.string(forKey: legacyFairyKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawID.isEmpty else {
            return nil
        }
        let data = defaults.data(forKey: PinnedFairyLook.defaultsKey)
        return (rawID, decodeLook(from: data, expectedFairyID: rawID))
    }

    static func decodeLook(from data: Data?, expectedFairyID: String) -> PinnedFairyLook? {
        guard let data, !data.isEmpty else { return nil }
        guard var decoded = try? JSONDecoder().decode(PinnedFairyLook.self, from: data),
              decoded.fairyID == expectedFairyID else {
            return nil
        }
        decoded.wingDesign.trimToBudget()
        return decoded
    }
}

enum FairyWingPainter {
    private static let hitTestSpan = CGSize(width: 100, height: 100)
    private static let unitUpperPath = upperWingPath(halfSpan: hitTestSpan)
    private static let unitLowerPath = lowerWingPath(halfSpan: hitTestSpan)

    static func upperWingPath(halfSpan: CGSize) -> Path {
        let w = halfSpan.width
        let h = halfSpan.height
        var p = Path()
        p.move(to: CGPoint(x: 0.06 * w, y: -0.04 * h))
        p.addCurve(
            to: CGPoint(x: 0.96 * w, y: -0.60 * h),
            control1: CGPoint(x: 0.24 * w, y: -0.94 * h),
            control2: CGPoint(x: 0.86 * w, y: -1.02 * h)
        )
        p.addCurve(
            to: CGPoint(x: 0.84 * w, y: 0.00 * h),
            control1: CGPoint(x: 1.03 * w, y: -0.34 * h),
            control2: CGPoint(x: 0.99 * w, y: -0.09 * h)
        )
        p.addCurve(
            to: CGPoint(x: 0.08 * w, y: 0.14 * h),
            control1: CGPoint(x: 0.60 * w, y: 0.16 * h),
            control2: CGPoint(x: 0.26 * w, y: 0.20 * h)
        )
        p.closeSubpath()
        return p
    }

    static func lowerWingPath(halfSpan: CGSize) -> Path {
        let w = halfSpan.width
        let h = halfSpan.height
        var p = Path()
        p.move(to: CGPoint(x: 0.08 * w, y: 0.12 * h))
        p.addCurve(
            to: CGPoint(x: 0.74 * w, y: 0.56 * h),
            control1: CGPoint(x: 0.44 * w, y: 0.10 * h),
            control2: CGPoint(x: 0.82 * w, y: 0.28 * h)
        )
        p.addCurve(
            to: CGPoint(x: 0.36 * w, y: 0.88 * h),
            control1: CGPoint(x: 0.68 * w, y: 0.84 * h),
            control2: CGPoint(x: 0.52 * w, y: 0.94 * h)
        )
        p.addCurve(
            to: CGPoint(x: 0.06 * w, y: 0.34 * h),
            control1: CGPoint(x: 0.18 * w, y: 0.80 * h),
            control2: CGPoint(x: 0.08 * w, y: 0.56 * h)
        )
        p.closeSubpath()
        return p
    }

    static func contains(_ p: WingPoint) -> Bool {
        let pt = CGPoint(x: CGFloat(p.u) * hitTestSpan.width, y: CGFloat(p.v) * hitTestSpan.height)
        return unitUpperPath.contains(pt) || unitLowerPath.contains(pt)
    }

    static func toCanonical(stagePoint: CGPoint, wingCenter: CGPoint, wingHalfSpan: CGSize) -> WingPoint? {
        guard wingHalfSpan.width > 1, wingHalfSpan.height > 1 else { return nil }
        let rawU = Float(abs(stagePoint.x - wingCenter.x) / wingHalfSpan.width)
        let rawV = Float((stagePoint.y - wingCenter.y) / wingHalfSpan.height)
        guard rawU >= 0, rawU <= 1, rawV >= -1, rawV <= 1 else { return nil }
        let candidate = WingPoint(u: rawU, v: rawV)
        return contains(candidate) ? candidate : nil
    }

    static func toStagePoint(
        _ p: WingPoint,
        side: CGFloat = 1,
        wingCenter: CGPoint,
        wingHalfSpan: CGSize
    ) -> CGPoint {
        CGPoint(
            x: wingCenter.x + side * CGFloat(p.u) * wingHalfSpan.width,
            y: wingCenter.y + CGFloat(p.v) * wingHalfSpan.height
        )
    }

    static func drawWings(
        _ g: GraphicsContext,
        wingCenter: CGPoint,
        wingHalfSpan: CGSize,
        baseHex: UInt32,
        innerHex: UInt32,
        outlineHex: UInt32,
        design: FairyWingDesign?,
        flap: CGFloat = 0,
        time t: Double = 0,
        showVeins: Bool = true
    ) {
        let upper = upperWingPath(halfSpan: wingHalfSpan)
        let lower = lowerWingPath(halfSpan: wingHalfSpan)
        var combined = upper
        combined.addPath(lower)

        let minSpan = min(wingHalfSpan.width, wingHalfSpan.height)
        let strokeW = max(1.8, min(4.2, minSpan * 0.022))
        let outlineColor = StorybookArt.outline(for: outlineHex, factor: 0.72)

        for side in [-1.0, 1.0] as [CGFloat] {
            var wg = g
            wg.translateBy(x: wingCenter.x, y: wingCenter.y)
            wg.rotate(by: .radians(Double(side) * Double(flap) * 0.22))
            wg.scaleBy(x: side * (1 + 0.06 * flap), y: 1 - 0.03 * flap)

            wg.fill(
                upper,
                with: .linearGradient(
                    Gradient(colors: [
                        StorybookArt.color(innerHex, alpha: 0.94),
                        StorybookArt.color(baseHex, alpha: 0.88),
                        StorybookArt.tint(for: baseHex, amount: 0.25).opacity(0.84),
                    ]),
                    startPoint: CGPoint(x: 0.08 * wingHalfSpan.width, y: 0),
                    endPoint: CGPoint(x: 0.94 * wingHalfSpan.width, y: -0.68 * wingHalfSpan.height)
                )
            )
            wg.fill(
                lower,
                with: .linearGradient(
                    Gradient(colors: [
                        StorybookArt.color(innerHex, alpha: 0.9),
                        StorybookArt.color(baseHex, alpha: 0.82),
                    ]),
                    startPoint: CGPoint(x: 0.1 * wingHalfSpan.width, y: 0.18 * wingHalfSpan.height),
                    endPoint: CGPoint(x: 0.7 * wingHalfSpan.width, y: 0.76 * wingHalfSpan.height)
                )
            )

            if showVeins {
                var vein1 = Path()
                vein1.move(to: CGPoint(x: 0.10 * wingHalfSpan.width, y: 0.02 * wingHalfSpan.height))
                vein1.addQuadCurve(
                    to: CGPoint(x: 0.80 * wingHalfSpan.width, y: -0.54 * wingHalfSpan.height),
                    control: CGPoint(x: 0.42 * wingHalfSpan.width, y: -0.44 * wingHalfSpan.height)
                )
                var vein2 = Path()
                vein2.move(to: CGPoint(x: 0.12 * wingHalfSpan.width, y: 0.06 * wingHalfSpan.height))
                vein2.addQuadCurve(
                    to: CGPoint(x: 0.74 * wingHalfSpan.width, y: -0.14 * wingHalfSpan.height),
                    control: CGPoint(x: 0.46 * wingHalfSpan.width, y: -0.08 * wingHalfSpan.height)
                )
                var vein3 = Path()
                vein3.move(to: CGPoint(x: 0.10 * wingHalfSpan.width, y: 0.22 * wingHalfSpan.height))
                vein3.addQuadCurve(
                    to: CGPoint(x: 0.56 * wingHalfSpan.width, y: 0.62 * wingHalfSpan.height),
                    control: CGPoint(x: 0.36 * wingHalfSpan.width, y: 0.34 * wingHalfSpan.height)
                )
                let veinStyle = StrokeStyle(lineWidth: max(1.1, strokeW * 0.55), lineCap: .round)
                wg.stroke(vein1, with: .color(.white.opacity(0.55)), style: veinStyle)
                wg.stroke(vein2, with: .color(.white.opacity(0.45)), style: veinStyle)
                wg.stroke(vein3, with: .color(.white.opacity(0.48)), style: veinStyle)
            }

            if let design, !design.isEmpty {
                var clipped = wg
                clipped.clip(to: combined)

                for stroke in design.strokes where !stroke.points.isEmpty {
                    let w = max(2.2, CGFloat(stroke.width) * minSpan)
                    let pts = stroke.points.map {
                        CGPoint(x: CGFloat($0.u) * wingHalfSpan.width, y: CGFloat($0.v) * wingHalfSpan.height)
                    }
                    if pts.count == 1 {
                        let p = pts[0]
                        let r = w * 0.55
                        clipped.fill(
                            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                            with: .color(StorybookArt.color(stroke.color.baseHex, alpha: 0.82))
                        )
                        let ir = r * 0.48
                        clipped.fill(
                            Path(ellipseIn: CGRect(x: p.x - ir, y: p.y - ir, width: ir * 2, height: ir * 2)),
                            with: .color(StorybookArt.color(stroke.color.shimmerHex, alpha: 0.72))
                        )
                    } else {
                        var path = Path()
                        path.move(to: pts[0])
                        for idx in 1..<pts.count {
                            let prev = pts[idx - 1]
                            let cur = pts[idx]
                            let mid = CGPoint(x: (prev.x + cur.x) * 0.5, y: (prev.y + cur.y) * 0.5)
                            path.addQuadCurve(to: mid, control: prev)
                        }
                        if let last = pts.last {
                            path.addLine(to: last)
                        }
                        clipped.stroke(
                            path,
                            with: .color(StorybookArt.color(stroke.color.baseHex, alpha: 0.82)),
                            style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
                        )
                        clipped.stroke(
                            path,
                            with: .color(StorybookArt.color(stroke.color.shimmerHex, alpha: 0.62)),
                            style: StrokeStyle(lineWidth: w * 0.42, lineCap: .round, lineJoin: .round)
                        )
                    }
                }

                for fleck in design.glitter {
                    let fx = CGFloat(fleck.point.u) * wingHalfSpan.width
                    let fy = CGFloat(fleck.point.v) * wingHalfSpan.height
                    let twinkle = 0.58 + 0.42 * sin(t * 5.2 + Double(fleck.twinklePhase))
                    let radius = max(2.2, CGFloat(fleck.size) * minSpan * CGFloat(0.85 + 0.3 * twinkle))
                    StorybookArt.sparkle(
                        clipped,
                        at: CGPoint(x: fx, y: fy),
                        radius: radius,
                        color: StorybookArt.color(fleck.colorHex),
                        opacity: 0.92 * twinkle
                    )
                    StorybookArt.sparkle(
                        clipped,
                        at: CGPoint(x: fx, y: fy),
                        radius: radius * 0.45,
                        color: .white,
                        opacity: 0.95 * twinkle
                    )
                }

                for stamp in design.stamps {
                    let sx = CGFloat(stamp.point.u) * wingHalfSpan.width
                    let sy = CGFloat(stamp.point.v) * wingHalfSpan.height
                    let stampRadius = max(4.2, minSpan * 0.115 * CGFloat(stamp.scale))
                    var sc = clipped
                    sc.translateBy(x: sx, y: sy)
                    drawStamp(sc, kind: stamp.kind, radius: stampRadius, tintHex: stamp.tintHex)
                }
            }

            StorybookArt.highlight(
                wg,
                in: CGRect(
                    x: 0.28 * wingHalfSpan.width,
                    y: -0.68 * wingHalfSpan.height,
                    width: 0.36 * wingHalfSpan.width,
                    height: 0.16 * wingHalfSpan.height
                ),
                opacity: 0.38
            )
            wg.stroke(
                upper,
                with: .color(outlineColor.opacity(0.78)),
                style: StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round)
            )
            wg.stroke(
                lower,
                with: .color(outlineColor.opacity(0.72)),
                style: StrokeStyle(lineWidth: strokeW * 0.92, lineCap: .round, lineJoin: .round)
            )
        }
    }

    static func drawStamp(_ g: GraphicsContext, kind: WingStampKind, radius r: CGFloat, tintHex: UInt32? = nil) {
        let hex = tintHex ?? kind.accentHex
        let fill = StorybookArt.color(hex)
        let outline = StorybookArt.outline(for: hex)
        let lineW = max(1.2, r * 0.18)

        switch kind {
        case .dewdrop:
            var drop = Path()
            drop.move(to: CGPoint(x: 0, y: -r))
            drop.addCurve(to: CGPoint(x: 0, y: r * 0.85), control1: CGPoint(x: r * 0.95, y: -r * 0.12), control2: CGPoint(x: r * 0.95, y: r * 0.85))
            drop.addCurve(to: CGPoint(x: 0, y: -r), control1: CGPoint(x: -r * 0.95, y: r * 0.85), control2: CGPoint(x: -r * 0.95, y: -r * 0.12))
            drop.closeSubpath()
            g.fill(
                drop,
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.95), StorybookArt.tint(for: hex, amount: 0.35), fill]),
                    center: CGPoint(x: -r * 0.25, y: -r * 0.15),
                    startRadius: 1,
                    endRadius: r
                )
            )
            g.stroke(drop, with: .color(outline.opacity(0.8)), lineWidth: lineW)
            StorybookArt.highlight(g, in: CGRect(x: -r * 0.34, y: -r * 0.22, width: r * 0.34, height: r * 0.44), opacity: 0.85)

        case .star:
            let star = fiveStarPath(center: .zero, outer: r, inner: r * 0.46)
            StorybookArt.fillAndStroke(g, star, fill: fill, stroke: outline, width: lineW)
            StorybookArt.sparkle(g, at: .zero, radius: r * 0.38, color: .white, opacity: 0.9)

        case .heart:
            let heart = heartPath(center: .zero, size: r * 1.9)
            StorybookArt.fillAndStroke(g, heart, fill: fill, stroke: outline, width: lineW)
            StorybookArt.highlight(g, in: CGRect(x: -r * 0.45, y: -r * 0.44, width: r * 0.42, height: r * 0.28), opacity: 0.72)

        case .blossom:
            for k in 0..<5 {
                let a = CGFloat(k) * (2 * .pi / 5) - .pi / 2
                let pr = r * 0.46
                let cx = cos(a) * r * 0.54
                let cy = sin(a) * r * 0.54
                let petal = Path(ellipseIn: CGRect(x: cx - pr, y: cy - pr, width: pr * 2, height: pr * 2))
                StorybookArt.fillAndStroke(g, petal, fill: fill, stroke: outline, width: lineW * 0.85)
            }
            let cr = r * 0.34
            StorybookArt.fillAndStroke(
                g,
                Path(ellipseIn: CGRect(x: -cr, y: -cr, width: cr * 2, height: cr * 2)),
                fill: Theme.lemon,
                stroke: StorybookArt.outline(for: 0xE6A93B),
                width: lineW * 0.8
            )

        case .crescent:
            var moon = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
            moon.addEllipse(in: CGRect(x: -r * 0.32, y: -r * 1.15, width: r * 1.72, height: r * 1.72))
            g.fill(moon, with: .color(fill), style: FillStyle(eoFill: true))
            StorybookArt.sparkle(g, at: CGPoint(x: r * 0.52, y: -r * 0.36), radius: r * 0.42, color: Theme.lemon)
        }
    }

    static func drawWand(
        _ g: GraphicsContext,
        design: FairyWandDesign,
        tip: CGPoint,
        tail: CGPoint,
        time t: Double,
        scale: CGFloat = 1.0,
        waveEnergy: CGFloat = 0
    ) {
        let dx = tip.x - tail.x
        let dy = tip.y - tail.y
        let angle = atan2(Double(dy), Double(dx))
        let collar = CGPoint(x: tip.x - dx * 0.18, y: tip.y - dy * 0.18)

        let ribbonColors = design.ribbon.colors
        for (idx, hex) in ribbonColors.enumerated() {
            let side: CGFloat = idx.isMultiple(of: 2) ? -1 : 1
            let spread = CGFloat(idx + 1) * 9 * scale
            let sway = CGFloat(sin(t * (4.2 + Double(waveEnergy) * 5.0) + Double(idx) * 1.3)) * (10 + waveEnergy * 16) * scale
            var ribbon = Path()
            ribbon.move(to: collar)
            ribbon.addCurve(
                to: CGPoint(x: collar.x + side * (22 * scale + spread) + sway, y: collar.y + (54 + CGFloat(idx) * 10) * scale),
                control1: CGPoint(x: collar.x + side * 18 * scale - sway * 0.4, y: collar.y + 18 * scale),
                control2: CGPoint(x: collar.x + side * (12 * scale + spread) + sway * 0.8, y: collar.y + 38 * scale)
            )
            g.stroke(
                ribbon,
                with: .color(StorybookArt.outline(for: hex).opacity(0.65)),
                style: StrokeStyle(lineWidth: 7.5 * scale, lineCap: .round)
            )
            g.stroke(
                ribbon,
                with: .color(StorybookArt.color(hex)),
                style: StrokeStyle(lineWidth: 4.6 * scale, lineCap: .round)
            )
        }

        var stick = Path()
        stick.move(to: tail)
        stick.addLine(to: tip)
        let shaftOutline = StorybookArt.outline(for: design.shaft.accentHex)
        g.stroke(stick, with: .color(shaftOutline), style: StrokeStyle(lineWidth: 13 * scale, lineCap: .round))
        g.stroke(stick, with: .color(StorybookArt.color(design.shaft.primaryHex)), style: StrokeStyle(lineWidth: 8.5 * scale, lineCap: .round))

        switch design.shaft {
        case .goldTwist, .lilacStar:
            g.stroke(
                stick,
                with: .color(StorybookArt.color(design.shaft.accentHex, alpha: 0.7)),
                style: StrokeStyle(lineWidth: 3.4 * scale, lineCap: .round, dash: [6 * scale, 9 * scale])
            )
        case .skyCrystal:
            g.stroke(stick, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 2.6 * scale, lineCap: .round))
        case .mintVine:
            for k in 1...3 {
                let u = CGFloat(k) * 0.22
                let lx = tail.x + dx * u
                let ly = tail.y + dy * u
                let leafSide: CGFloat = k.isMultiple(of: 2) ? -1 : 1
                let leaf = Path(ellipseIn: CGRect(x: lx + leafSide * 5 * scale - 4 * scale, y: ly - 3 * scale, width: 8 * scale, height: 6 * scale))
                StorybookArt.fillAndStroke(g, leaf, fill: StorybookArt.color(0x7CE6A8), stroke: StorybookArt.outline(for: 0x56B882), width: 1.4 * scale)
            }
        case .pearlPink:
            g.stroke(stick, with: .color(.white.opacity(0.62)), style: StrokeStyle(lineWidth: 2.4 * scale, lineCap: .round))
        }

        let pomR = 7.5 * scale
        StorybookArt.fillAndStroke(
            g,
            Path(ellipseIn: CGRect(x: tail.x - pomR, y: tail.y - pomR, width: pomR * 2, height: pomR * 2)),
            fill: Theme.lemon,
            stroke: StorybookArt.outline(for: 0xE6A93B),
            width: 2.2 * scale
        )

        let haloR = (30 + CGFloat(sin(t * 6.5)) * 4 + waveEnergy * 16) * scale
        g.fill(
            Path(ellipseIn: CGRect(x: tip.x - haloR, y: tip.y - haloR, width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFF5B8, alpha: 0.72 + Double(waveEnergy) * 0.22),
                    StorybookArt.color(design.topper.gemHex, alpha: 0),
                ]),
                center: tip,
                startRadius: 3 * scale,
                endRadius: haloR
            )
        )

        var head = g
        head.translateBy(x: tip.x, y: tip.y)
        head.rotate(by: .radians(angle + .pi / 2))
        head.scaleBy(x: scale, y: scale)
        drawWandTopper(head, topper: design.topper)
    }

    static func drawWandTopper(_ g: GraphicsContext, topper: WandTopper) {
        let goldOutline = StorybookArt.outline(for: 0xE0A030)
        let gemFill = StorybookArt.color(topper.gemHex)
        let gemOutline = StorybookArt.outline(for: topper.gemHex)

        switch topper {
        case .heartGem:
            for side in [-1.0, 1.0] as [CGFloat] {
                var miniWing = Path()
                miniWing.move(to: CGPoint(x: side * 7, y: 10))
                miniWing.addCurve(to: CGPoint(x: side * 26, y: -4), control1: CGPoint(x: side * 20, y: 14), control2: CGPoint(x: side * 28, y: 4))
                miniWing.addCurve(to: CGPoint(x: side * 7, y: 0), control1: CGPoint(x: side * 20, y: -12), control2: CGPoint(x: side * 12, y: -6))
                miniWing.closeSubpath()
                StorybookArt.fillAndStroke(g, miniWing, fill: .white, stroke: StorybookArt.outline(for: 0xD8B4F2), width: 2)
            }
            StorybookArt.fillAndStroke(g, heartPath(center: CGPoint(x: 0, y: -2), size: 38), fill: Theme.lemon, stroke: goldOutline, width: 2.6)
            StorybookArt.fillAndStroke(g, heartPath(center: CGPoint(x: 0, y: -2), size: 26), fill: gemFill, stroke: gemOutline, width: 2)
            StorybookArt.highlight(g, in: CGRect(x: -7, y: -10, width: 7, height: 4.5), opacity: 0.85)

        case .starBurst:
            StorybookArt.fillAndStroke(g, fiveStarPath(center: CGPoint(x: 0, y: -2), outer: 24, inner: 11), fill: Theme.lemon, stroke: goldOutline, width: 2.6)
            StorybookArt.fillAndStroke(g, fiveStarPath(center: CGPoint(x: 0, y: -2), outer: 15, inner: 7), fill: gemFill, stroke: gemOutline, width: 1.8)
            StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -2), radius: 7, color: .white)

        case .crescentMoon:
            var moon = Path(ellipseIn: CGRect(x: -18, y: -20, width: 36, height: 36))
            moon.addEllipse(in: CGRect(x: -5, y: -24, width: 30, height: 30))
            g.fill(moon, with: .color(Theme.lemon), style: FillStyle(eoFill: true))
            let gem = Path(ellipseIn: CGRect(x: -14, y: -4, width: 12, height: 12))
            StorybookArt.fillAndStroke(g, gem, fill: gemFill, stroke: gemOutline, width: 1.8)
            StorybookArt.sparkle(g, at: CGPoint(x: 8, y: -6), radius: 8, color: .white)

        case .blossomCrown:
            for k in 0..<5 {
                let a = CGFloat(k) * (2 * .pi / 5) - .pi / 2
                let cx = cos(a) * 12
                let cy = -2 + sin(a) * 12
                StorybookArt.fillAndStroke(
                    g,
                    Path(ellipseIn: CGRect(x: cx - 9, y: cy - 9, width: 18, height: 18)),
                    fill: gemFill,
                    stroke: gemOutline,
                    width: 2.2
                )
            }
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -8, y: -10, width: 16, height: 16)), fill: Theme.lemon, stroke: goldOutline, width: 2)
            StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -2), radius: 5.5, color: .white)

        case .butterflyCrystal:
            for side in [-1.0, 1.0] as [CGFloat] {
                var bw = Path()
                bw.move(to: CGPoint(x: 0, y: -2))
                bw.addCurve(to: CGPoint(x: side * 24, y: -16), control1: CGPoint(x: side * 8, y: -22), control2: CGPoint(x: side * 24, y: -24))
                bw.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: side * 24, y: 0), control2: CGPoint(x: side * 12, y: 6))
                bw.closeSubpath()
                StorybookArt.fillAndStroke(g, bw, fill: gemFill, stroke: gemOutline, width: 2.2)

                var lw = Path()
                lw.move(to: CGPoint(x: 0, y: 2))
                lw.addCurve(to: CGPoint(x: side * 16, y: 12), control1: CGPoint(x: side * 12, y: 4), control2: CGPoint(x: side * 18, y: 10))
                lw.addCurve(to: CGPoint(x: 0, y: 10), control1: CGPoint(x: side * 10, y: 18), control2: CGPoint(x: side * 4, y: 14))
                lw.closeSubpath()
                StorybookArt.fillAndStroke(g, lw, fill: StorybookArt.tint(for: topper.gemHex, amount: 0.35), stroke: gemOutline, width: 1.8)
            }
            StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -3.5, y: -10, width: 7, height: 22), cornerRadius: 3.5), fill: Theme.lemon, stroke: goldOutline, width: 1.8)
        }
    }

    static func drawAccessoryOnHead(_ g: GraphicsContext, accessoryID: String, headScale: CGFloat = 1.0) {
        var c = g
        c.scaleBy(x: headScale, y: headScale)
        switch accessoryID {
        case "bow":
            c.translateBy(x: 18, y: -32)
            c.rotate(by: .radians(0.28))
            drawAccessory(c, accessoryID: accessoryID, scale: 0.72)
        case "crown":
            c.translateBy(x: 0, y: -44)
            drawAccessory(c, accessoryID: accessoryID, scale: 0.75)
        case "flower":
            c.translateBy(x: -19, y: -30)
            drawAccessory(c, accessoryID: accessoryID, scale: 0.75)
        case "starClip":
            c.translateBy(x: 17, y: -27)
            drawAccessory(c, accessoryID: accessoryID, scale: 0.7)
        case "daenggiRibbon":
            c.translateBy(x: 20, y: -26)
            drawAccessory(c, accessoryID: accessoryID, scale: 0.75)
        default:
            break
        }
    }

    static func drawAccessory(_ g: GraphicsContext, accessoryID: String, scale: CGFloat = 1.0) {
        var c = g
        c.scaleBy(x: scale, y: scale)
        switch accessoryID {
        case "bow":
            let outline = StorybookArt.outline(for: 0xFF6FA8)
            for side in [-1.0, 1.0] as [CGFloat] {
                let loop = Path(ellipseIn: CGRect(x: side < 0 ? -18 : 2, y: -9, width: 16, height: 16))
                StorybookArt.fillAndStroke(c, loop, fill: StorybookArt.color(0xFF8EC2), stroke: outline, width: 2.4)
            }
            let knot = Path(ellipseIn: CGRect(x: -5.5, y: -5.5, width: 11, height: 11))
            StorybookArt.fillAndStroke(c, knot, fill: StorybookArt.color(0xFFD2E8), stroke: outline, width: 2.2)

        case "crown":
            var crown = Path()
            crown.move(to: CGPoint(x: -16, y: 10))
            crown.addLine(to: CGPoint(x: -19, y: -7))
            crown.addLine(to: CGPoint(x: -7, y: 1))
            crown.addLine(to: CGPoint(x: 0, y: -13))
            crown.addLine(to: CGPoint(x: 7, y: 1))
            crown.addLine(to: CGPoint(x: 19, y: -7))
            crown.addLine(to: CGPoint(x: 16, y: 10))
            crown.closeSubpath()
            StorybookArt.fillAndStroke(c, crown, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 2.4)
            StorybookArt.heart(c, at: CGPoint(x: 0, y: 4), size: 9, color: Theme.pink)

        case "flower":
            let outline = StorybookArt.outline(for: 0xFF8AB8)
            for k in 0..<5 {
                let a = CGFloat(k) * (2 * .pi / 5) - .pi / 2
                let pt = CGPoint(x: cos(a) * 9, y: sin(a) * 9)
                let p = Path(ellipseIn: CGRect(x: pt.x - 7.5, y: pt.y - 7.5, width: 15, height: 15))
                StorybookArt.fillAndStroke(c, p, fill: StorybookArt.color(0xFFB5D6), stroke: outline, width: 2)
            }
            let center = Path(ellipseIn: CGRect(x: -5.5, y: -5.5, width: 11, height: 11))
            StorybookArt.fillAndStroke(c, center, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 1.8)

        case "starClip":
            let s1 = fiveStarPath(center: CGPoint(x: -6, y: -4), outer: 11, inner: 5)
            let s2 = fiveStarPath(center: CGPoint(x: 9, y: 6), outer: 9, inner: 4.2)
            StorybookArt.fillAndStroke(c, s1, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 2.2)
            StorybookArt.fillAndStroke(c, s2, fill: StorybookArt.color(0xFFB5D6), stroke: StorybookArt.outline(for: 0xE67AA8), width: 2)

        case "daenggiRibbon":
            let outline = StorybookArt.outline(for: 0xE0567E)
            var tail = Path()
            tail.move(to: CGPoint(x: -6, y: -12))
            tail.addLine(to: CGPoint(x: 6, y: -12))
            tail.addLine(to: CGPoint(x: 9, y: 15))
            tail.addLine(to: CGPoint(x: 0, y: 10))
            tail.addLine(to: CGPoint(x: -9, y: 15))
            tail.closeSubpath()
            StorybookArt.fillAndStroke(c, tail, fill: StorybookArt.color(0xFF7B9E), stroke: outline, width: 2.2)
            let topPin = Path(ellipseIn: CGRect(x: -7, y: -17, width: 14, height: 11))
            StorybookArt.fillAndStroke(c, topPin, fill: StorybookArt.color(0x9EE3CB), stroke: StorybookArt.outline(for: 0x62B89B), width: 2)
            StorybookArt.sparkle(c, at: .zero, radius: 5, color: Theme.lemon)

        default:
            break
        }
    }

    static func heartPath(center: CGPoint, size: CGFloat) -> Path {
        let r = size * 0.5
        let cx = center.x, cy = center.y
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - r * 0.25))
        p.addCurve(
            to: CGPoint(x: cx + r, y: cy - r * 0.15),
            control1: CGPoint(x: cx + r * 0.35, y: cy - r * 1.05),
            control2: CGPoint(x: cx + r * 1.08, y: cy - r * 0.82)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy + r * 0.88),
            control1: CGPoint(x: cx + r * 0.96, y: cy + r * 0.35),
            control2: CGPoint(x: cx + r * 0.35, y: cy + r * 0.65)
        )
        p.addCurve(
            to: CGPoint(x: cx - r, y: cy - r * 0.15),
            control1: CGPoint(x: cx - r * 0.35, y: cy + r * 0.65),
            control2: CGPoint(x: cx - r * 0.96, y: cy + r * 0.35)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy - r * 0.25),
            control1: CGPoint(x: cx - r * 1.08, y: cy - r * 0.82),
            control2: CGPoint(x: cx - r * 0.35, y: cy - r * 1.05)
        )
        p.closeSubpath()
        return p
    }

    static func fiveStarPath(center: CGPoint, outer: CGFloat, inner: CGFloat) -> Path {
        var star = Path()
        for k in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let rr = k.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: center.x + cos(a) * rr, y: center.y + sin(a) * rr)
            if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        return star
    }
}
