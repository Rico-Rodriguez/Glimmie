import SwiftUI

enum UnicornMotion { case lean, shake, nibble, nuzzle, stroll }

enum UnicornPart: String, CaseIterable {
    case ears, tail, horn, mane, braid, torso, head, foreLeft, foreRight, hindLeft, hindRight, saddle
}

/// Joint transforms in the shared Pet Vet and Dress Up coordinates, with a face suited to the action.
struct UnicornPose {
    var lift: CGFloat = 0
    var head = CGAffineTransform.identity
    var mane = CGAffineTransform.identity
    var tail = CGAffineTransform.identity
    var frontLeft = CGAffineTransform.identity
    var frontRight = CGAffineTransform.identity
    var backLeft = CGAffineTransform.identity
    var backRight = CGAffineTransform.identity
    var eyes = "open"
    var mouth = "smile"
    var gaze: CGSize = .zero
    var flap: CGFloat = 0

    static func frame(time: TimeInterval, age: TimeInterval?, motion: UnicornMotion,
                      target: CGPoint? = nil, direction: CGFloat = 1, reduceMotion: Bool = false) -> Self {
        var pose = Self()
        let phase = min(1, max(0, (age ?? 2) / 0.82))
        let active = age != nil && phase < 1
        let beat: CGFloat = active ? sin(phase * .pi) : 0
        let idle: CGFloat = reduceMotion ? 0 : sin(time * 2.8)
        let amplitude: CGFloat = reduceMotion ? 0 : beat
        var nod: CGFloat = 0
        var headTurn: CGFloat = 0
        var tailFlick: CGFloat = idle * 0.055
        var step: CGFloat = 0

        if let target {
            pose.gaze = CGSize(width: max(-8, min(8, (target.x - 300) * 0.045)),
                               height: max(-7, min(7, (target.y - 270) * 0.039)))
        }
        if time.truncatingRemainder(dividingBy: 4.2) < 0.15 { pose.eyes = "blink" }
        if active {
            switch motion {
            case .lean:
                nod = -6 * amplitude
                headTurn = (target.map { $0.x < 300 ? -0.13 : 0.13 } ?? -0.13) * amplitude
                pose.eyes = "happy"
            case .shake:
                headTurn = sin(phase * 6 * .pi) * amplitude * 0.22
                tailFlick += sin(phase * 5 * .pi) * amplitude * 0.29
                pose.eyes = "blink"
            case .nibble:
                nod = 18 * amplitude
                pose.eyes = phase > 0.65 ? "happy" : "open"
                pose.mouth = phase < 0.24 ? "wide" : (sin(phase * 9 * .pi) > 0 ? "yum" : "grin")
            case .nuzzle:
                nod = 10 * amplitude
                headTurn = (target.map { $0.x < 300 ? -0.13 : 0.13 } ?? 0.13) * amplitude
                tailFlick += amplitude * 0.20
                pose.eyes = "happy"
                pose.mouth = "grin"
                pose.frontLeft = joint(x: 228, y: 468, angle: -0.15 * amplitude, dy: -10 * amplitude)
            case .stroll:
                step = sin(phase * 5 * .pi) * amplitude
                pose.lift = -abs(step) * 13
                nod = step * 8
                headTurn = direction * amplitude * 0.105
                tailFlick += step * 0.20
                pose.gaze.width = direction * 8 * beat
                pose.frontLeft = joint(x: 228, y: 468, angle: step * 0.31, dy: -max(0, step) * 20)
                pose.frontRight = joint(x: 372, y: 468, angle: -step * 0.31, dy: -max(0, -step) * 20)
                pose.backLeft = joint(x: 228, y: 570, angle: -step * 0.25, dy: -max(0, -step) * 18)
                pose.backRight = joint(x: 372, y: 570, angle: step * 0.25, dy: -max(0, step) * 18)
            }
        }
        pose.head = joint(x: 300, y: 315, angle: headTurn, dy: nod + idle * 3)
        pose.mane = joint(x: 323, y: 171, angle: -headTurn * 0.55 + idle * 0.027).concatenating(pose.head)
        pose.tail = joint(x: 404, y: 580, angle: tailFlick)
        pose.flap = step
        return pose
    }

    func transform(_ part: UnicornPart) -> CGAffineTransform {
        switch part {
        case .ears, .horn, .head: return head
        case .mane, .braid: return mane
        case .tail: return tail
        case .foreLeft: return frontLeft
        case .foreRight: return frontRight
        case .hindLeft: return backLeft
        case .hindRight: return backRight
        case .torso, .saddle: return .identity
        }
    }

    private static func joint(x: CGFloat, y: CGFloat, angle: CGFloat, dy: CGFloat = 0) -> CGAffineTransform {
        CGAffineTransform(translationX: -x, y: -y)
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(CGAffineTransform(translationX: x, y: y + dy))
    }
}

enum UnicornRig {
    static let box = CGRect(x: 0, y: 0, width: 600, height: 660)

    private static func anchor(_ spot: CareSpot) -> (CGPoint, UnicornPart) {
        switch spot {
        case .shoulder: return (CGPoint(x: 229, y: 413), .torso)
        case .flank: return (CGPoint(x: 368, y: 466), .torso)
        case .knee: return (CGPoint(x: 228, y: 512), .foreLeft)
        case .forelock: return (CGPoint(x: 238, y: 172), .mane)
        case .mane: return (CGPoint(x: 429, y: 246), .mane)
        case .tail: return (CGPoint(x: 477, y: 537), .tail)
        case .muzzle: return (PetArt.shared.animals["unicorn"]?.mouth ?? CGPoint(x: 300, y: 334), .head)
        }
    }

    static func point(_ spot: CareSpot, pose: UnicornPose = UnicornPose()) -> CGPoint {
        let (p, part) = anchor(spot)
        let moved = p.applying(pose.transform(part))
        return CGPoint(x: moved.x, y: moved.y + pose.lift)
    }

    static func scale(in frame: CGRect) -> CGFloat { min(frame.width / box.width, frame.height / box.height) }

    static func project(_ p: CGPoint, into frame: CGRect) -> CGPoint {
        let s = scale(in: frame)
        return CGPoint(x: frame.midX + (p.x - box.midX) * s, y: frame.midY + (p.y - box.midY) * s)
    }

    static func unproject(_ p: CGPoint, from frame: CGRect) -> CGPoint {
        let s = scale(in: frame)
        return CGPoint(x: box.midX + (p.x - frame.midX) / s, y: box.midY + (p.y - frame.midY) / s)
    }

    static func draw(_ look: UnicornLook, pose: UnicornPose, in context: GraphicsContext) {
        let art = PetArt.shared
        guard let animal = art.animals["unicorn"], !art.unicornRig.isEmpty else { return }
        var g = context
        g.translateBy(x: 0, y: pose.lift)
        let colors = PaintSet(main: RGB(hex: String(look.coat, radix: 16)),
                              accent: RGB(hex: String(look.mane, radix: 16)),
                              skin: RGB(hex: String(look.horn, radix: 16)), pattern: nil)
        func draw(_ part: UnicornPart) {
            guard let shapes = art.unicornRig[part.rawValue] else { return }
            var layer = g
            layer.concatenate(pose.transform(part))
            ArtPainter.draw(shapes, colors, in: layer)
        }
        func wear(_ id: String, in local: GraphicsContext) {
            guard let item = art.wear[id] else { return }
            var layer = local
            PetPainter.transform(&layer, slot: item.slot, animal, flap: pose.flap)
            let pet = PetLook(kind: "unicorn")
            ArtPainter.draw(item.shapes, pet.paints(for: item), in: layer)
        }

        draw(.tail)
        if look.gear == .wings { wear("pk_fairy", in: g) }
        draw(.hindLeft); draw(.hindRight)
        draw(.torso)
        if look.gear == .saddle { draw(.saddle) }
        draw(.foreLeft); draw(.foreRight)
        draw(.ears); draw(.head)
        draw(look.braided ? .braid : .mane)
        draw(.horn)

        var face = g
        face.concatenate(pose.head)
        ArtPainter.draw(animal.blush, colors, in: face)
        ArtPainter.draw(animal.brows, colors, in: face)
        var eyes = face
        eyes.translateBy(x: pose.gaze.width, y: pose.gaze.height)
        ArtPainter.draw(animal.eyes[pose.eyes] ?? [], colors, in: eyes)
        ArtPainter.draw(animal.mouths[pose.mouth] ?? [], colors, in: face)
        if look.gear == .bow { wear("ph_bow", in: face) }
        if look.gear == .crown { wear("ph_crown", in: face) }
    }
}

struct UnicornPortrait: View {
    let look: UnicornLook
    var pose = UnicornPose()

    var body: some View {
        Canvas { context, size in
            var g = context
            ArtPainter.fit(&g, box: UnicornRig.box, into: size)
            UnicornRig.draw(look, pose: pose, in: g)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

extension MeadowVisitor {
    var sticker: Sticker {
        Sticker(id: rawValue) { context, _ in
            var g = context
            if let look {
                let s: CGFloat = 0.145
                g.scaleBy(x: s, y: s)
                g.translateBy(x: -300, y: -341)
                UnicornRig.draw(look, pose: UnicornPose(), in: g)
            } else if self == .bunny {
                g.scaleBy(x: 0.15, y: 0.15)
                g.translateBy(x: -300, y: -325)
                PetPainter.draw(PetLook(kind: "bunny"), in: g)
            } else {
                let a: CGFloat = 100 / 420
                g.scaleBy(x: a, y: a)
                g.translateBy(x: -300, y: -425)
                guard let item = PetArt.shared.wear["pk_butterfly"] else { return }
                ArtPainter.draw(item.shapes, PetLook(kind: "unicorn").paints(for: item), in: g)
            }
        }
    }
}
