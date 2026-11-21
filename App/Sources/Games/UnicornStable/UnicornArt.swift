import SwiftUI
import UIKit

enum UnicornIllustration {
    private static let images = NSCache<NSString, UIImage>()
    private static let palettes: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 52 * 1024 * 1024
        return cache
    }()
    static let aspect = CGFloat(1199) / 1312

    static func source(_ name: String) -> UIImage? {
        if let cached = images.object(forKey: name as NSString) { return cached }
        guard let url = GameFiles.url(name, "png", game: "UnicornStable"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        images.setObject(image, forKey: name as NSString)
        return image
    }

    static func fitted(in frame: CGRect) -> CGRect {
        let width = min(frame.width, frame.height * aspect)
        let height = width / aspect
        return CGRect(x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height)
    }

    static func anchor(_ spot: CareSpot) -> CGPoint {
        switch spot {
        case .shoulder: return CGPoint(x: 0.70, y: 0.54)
        case .flank: return CGPoint(x: 0.41, y: 0.53)
        case .knee: return CGPoint(x: 0.65, y: 0.74)
        case .forelock: return CGPoint(x: 0.75, y: 0.15)
        case .mane: return CGPoint(x: 0.59, y: 0.42)
        case .tail: return CGPoint(x: 0.18, y: 0.58)
        case .muzzle: return CGPoint(x: 0.87, y: 0.32)
        }
    }

    static func sprite(_ name: String, look: UnicornLook) -> UIImage? {
        guard let original = source(name) else { return nil }
        let initial = UnicornLook()
        let changed = [look.coat != initial.coat, look.mane != initial.mane, look.horn != initial.horn]
        guard changed.contains(true), let pixels = original.cgImage else { return original }
        let key = "\(name)/\(look.coat)/\(look.mane)/\(look.horn)" as NSString
        if let cached = palettes.object(forKey: key) { return cached }
        guard let recolored = tint(pixels, look: look, changed: changed) else { return original }
        let image = UIImage(cgImage: recolored)
        palettes.setObject(image, forKey: key, cost: pixels.width * pixels.height * 4)
        return image
    }

    /// Map the painted pigment to the selected coat, mane and horn colors while keeping its original shading.
    private static func tint(_ image: CGImage, look: UnicornLook, changed: [Bool]) -> CGImage? {
        let width = image.width, height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let shades = [look.coat, look.mane, look.horn].map { hex in
            [Float((hex >> 16) & 255), Float((hex >> 8) & 255), Float(hex & 255)]
        }
        let format = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return buffer.withUnsafeMutableBytes { data -> CGImage? in
            guard let bytes = data.bindMemory(to: UInt8.self).baseAddress,
                  let context = CGContext(data: bytes, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space, bitmapInfo: format) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            for y in 0..<height {
                let ny = Float(y) / Float(height)
                for x in 0..<width {
                    let i = 4 * (y * width + x)
                    let alpha = Float(bytes[i + 3])
                    guard alpha > 8 else { continue }
                    let unpremultiply = 255 / alpha
                    let red = Float(bytes[i]) * unpremultiply
                    let green = Float(bytes[i + 1]) * unpremultiply
                    let blue = Float(bytes[i + 2]) * unpremultiply
                    let nx = Float(x) / Float(width)
                    let inMane = nx < 0.63 || ny < 0.21 || nx < 0.68 && ny < 0.48 || nx > 0.80 && ny < 0.20
                    let inHorn = nx > 0.775 && nx < 0.86 && ny < 0.15
                    let kind: Int
                    let amount: Float
                    if inHorn && red - blue > 49 && green - blue > 27 {
                        kind = 2; amount = min(1, (green - blue - 20) / 33)
                    } else if inMane && red > 97 && red - green > 24 && blue >= green - 17 {
                        kind = 1; amount = min(1, (red - green - 17) / 26)
                    } else if red > 155 && green > 138 && red - green < 48 && red - blue < 85 && green >= blue {
                        kind = 0; amount = min(1, (green - 137) / 41)
                    } else { continue }
                    guard changed[kind] else { continue }
                    let value = (red * 0.24 + green * 0.64 + blue * 0.12) / 255
                    let shade = shades[kind]
                    let average = max(1, shade[0] * 0.24 + shade[1] * 0.64 + shade[2] * 0.12)
                    let brightness = value * 255 / average
                    let fraction = alpha / 255
                    bytes[i] = channel(red, to: shade[0] * brightness, amount: amount, fraction: fraction)
                    bytes[i + 1] = channel(green, to: shade[1] * brightness, amount: amount, fraction: fraction)
                    bytes[i + 2] = channel(blue, to: shade[2] * brightness, amount: amount, fraction: fraction)
                }
            }
            return context.makeImage()
        }
    }

    private static func channel(_ start: Float, to end: Float, amount: Float, fraction: Float) -> UInt8 {
        UInt8(max(0, min(255, start + (min(255, end) - start) * amount)) * fraction)
    }
}

struct UnicornPortrait: View {
    let look: UnicornLook
    var expression: UnicornExpression?
    var intensity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let fit = UnicornIllustration.fitted(in: bounds)
            ZStack {
                if look.gear == .wings {
                    Image(systemName: "feather.fill")
                        .font(.system(size: fit.width * 0.35, weight: .medium))
                        .foregroundStyle(Theme.mint.gradient)
                        .rotationEffect(.degrees(-75))
                        .shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 3)
                        .position(x: fit.minX + fit.width * 0.46, y: fit.minY + fit.height * 0.42)
                }
                if let portrait = UnicornIllustration.sprite("unicorn", look: look) {
                    Image(uiImage: portrait).resizable().frame(width: fit.width, height: fit.height)
                        .position(x: fit.midX, y: fit.midY)
                }
                if let expression, intensity > 0, let frame = UnicornIllustration.sprite(expression.rawValue, look: look) {
                    Image(uiImage: frame).resizable().frame(width: fit.width, height: fit.height)
                        .position(x: fit.midX, y: fit.midY)
                        .mask {
                            let patch = expression.patch
                            Ellipse().fill(.white).blur(radius: fit.width * 0.014)
                                .frame(width: fit.width * patch.width, height: fit.height * patch.height)
                                .position(x: fit.minX + fit.width * patch.midX, y: fit.minY + fit.height * patch.midY)
                        }
                        .opacity(intensity)
                }
                if look.braided { accessory("ribbon.fill", in: fit, at: CGPoint(x: 0.60, y: 0.44), color: Theme.lilac) }
                if look.gear == .bow { accessory("ribbon.fill", in: fit, at: CGPoint(x: 0.70, y: 0.15), color: Theme.pink) }
                if look.gear == .crown { accessory("crown.fill", in: fit, at: CGPoint(x: 0.77, y: 0.13), color: Theme.lemon) }
                if look.gear == .saddle {
                    Capsule().fill(Color(hex: 0xA777AD).gradient)
                        .overlay(Capsule().strokeBorder(Theme.blush, lineWidth: 2))
                        .frame(width: fit.width * 0.20, height: fit.height * 0.11)
                        .rotationEffect(.degrees(-12))
                        .position(x: fit.minX + fit.width * 0.47, y: fit.minY + fit.height * 0.48)
                    accessory("heart.fill", in: fit, at: CGPoint(x: 0.47, y: 0.48), color: Theme.blush)
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func accessory(_ icon: String, in frame: CGRect, at p: CGPoint, color: Color) -> some View {
        Image(systemName: icon).font(.system(size: frame.width * 0.092, weight: .bold))
            .foregroundStyle(color.gradient)
            .shadow(color: Theme.ink.opacity(0.29), radius: 2, y: 3)
            .position(x: frame.minX + frame.width * p.x, y: frame.minY + frame.height * p.y)
    }
}

enum UnicornExpression: String {
    case contented, nibble

    var patch: CGRect {
        switch self {
        case .contented: return CGRect(x: 0.694, y: 0.163, width: 0.207, height: 0.128)
        case .nibble: return CGRect(x: 0.819, y: 0.283, width: 0.108, height: 0.070)
        }
    }
}

enum UnicornMotion {
    case lean, shake, nibble, nuzzle, stroll
}

struct AnimatedUnicorn: View {
    let look: UnicornLook
    let reaction: Date?
    let motion: UnicornMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion && reaction == nil)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let age = reaction.map { timeline.date.timeIntervalSince($0) } ?? 2
            let phase = min(1, max(0, age / 0.85))
            let pulse = sin(phase * .pi)
            let blink = t.truncatingRemainder(dividingBy: 5.3)
            let expression: UnicornExpression? = phase < 1 && motion != .stroll && motion != .shake
                ? (motion == .nibble ? .nibble : .contented) : (blink < 0.16 ? .contented : nil)
            let strength = reduceMotion ? 0 : pulse
            let chew = motion == .nibble ? abs(sin(phase * 4 * .pi)) : 1
            let bounce = motion == .stroll ? abs(sin(phase * 4 * .pi)) : 0
            let tilt = motion == .shake ? sin(phase * 6 * .pi) * 2.7 : motion == .nuzzle ? 3.3 : 0.9
            UnicornPortrait(look: look, expression: expression, intensity: phase < 1 ? min(1, 2.2 * pulse * chew) : 1)
                .scaleEffect(x: 1 + 0.009 * strength, y: 1 + (reduceMotion ? 0 : 0.004 * sin(t * 2)) - 0.024 * strength,
                             anchor: .bottom)
                .rotationEffect(.degrees(tilt * strength), anchor: .bottom)
                .offset(x: motion == .lean ? 11 * strength : 0,
                        y: motion == .stroll ? -16 * bounce * strength : motion == .nibble ? 9 * strength : 0)
        }
    }
}

extension MeadowVisitor {
    var sticker: Sticker {
        Sticker(id: rawValue) { g, _ in
            if let look, let picture = UnicornIllustration.sprite("unicorn", look: look) {
                g.draw(Image(uiImage: picture), in: CGRect(x: -46, y: -50, width: 92, height: 100))
            } else if self == .bunny {
                let fur = Color(hex: 0xEDCCB8)
                for x in [-22.0, 4.0] {
                    g.fill(Path(ellipseIn: CGRect(x: x, y: -44, width: 18, height: 44)), with: .color(fur))
                    g.fill(Path(ellipseIn: CGRect(x: x + 5, y: -39, width: 8, height: 31)), with: .color(Theme.pink))
                }
                g.fill(Path(ellipseIn: CGRect(x: -30, y: -16, width: 60, height: 51)), with: .color(fur))
                for x in [-15.0, 8.0] {
                    g.fill(Path(ellipseIn: CGRect(x: x, y: 3, width: 7, height: 10)), with: .color(Theme.ink))
                }
                g.fill(Path(ellipseIn: CGRect(x: -4, y: 13, width: 8, height: 7)), with: .color(Theme.pink))
            } else {
                for x in [-35.0, 2.0] {
                    g.fill(Path(ellipseIn: CGRect(x: x, y: -25, width: 33, height: 39)), with: .color(Theme.lilac))
                    g.fill(Path(ellipseIn: CGRect(x: x + 4, y: 1, width: 25, height: 27)), with: .color(Theme.pink))
                    g.fill(Path(ellipseIn: CGRect(x: x + 11, y: -16, width: 11, height: 13)), with: .color(.white))
                }
                g.fill(Path(roundedRect: CGRect(x: -4, y: -18, width: 8, height: 44), cornerRadius: 4), with: .color(Theme.ink))
            }
        }
    }
}
