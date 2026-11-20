import SwiftUI

// MARK: - Keeping her finger out of the way
//
// On a touch screen the finger covers exactly the spot it touches, so every hands-on game lifts what
// she is holding above her finger: a tool works at its tip, a long way above the fingertip, and a
// dragged thing (a sticker, a topping, a sock) floats above it. On its own a big jump would feel
// loose, so four things go together:
//
// - one shared, generous lift (`tool`, `item`), the same in every game, so her hand learns it once;
// - near the top of the screen the lift shrinks and leans toward the middle, so the tip never runs
//   off the edge and she can still reach the top of the hair, the pet's ears or the top shelf; near
//   the bottom it turns sideways, so she can still reach a patient's feet or the bottom of the bed;
// - a held tool turns so its handle points at her finger and its working end at the tip (`turn`),
//   so the tool itself bridges the gap instead of floating somewhere above her hand;
// - while a tool is working it turns see-through (`seeThrough`) and a small bright ring marks the
//   exact spot its tip works on (`drawTip` / `TipMarker`);
// - where the scene is drawn in a Canvas, a round magnifier (`Magnifier`) shows the spot under the tip
//   at 2x, on the side away from it.

enum FingerLift {
    /// How far above her finger a tool's tip works (Pet Vet used 80, most games 44 to 58).
    static let tool: CGFloat = 120
    /// How far above her finger the middle of a dragged thing floats.
    static let item: CGFloat = 100
    /// How opaque a tool is while it's over the thing it works on.
    static let seeThrough: Double = 0.55

    /// Where a lifted tool tip or dragged thing goes for a finger at `finger`.
    ///
    /// - `top`: the highest point it should reach (the top edge of the play area).
    /// - `bottom`: the lowest point her finger can go (the bottom edge of the screen). When given, the
    ///   lift turns sideways as her finger nears it, so the tip can still reach things that sit low
    ///   (a patient's feet, the floor, the bottom of the flower bed) instead of stopping 120 pt short.
    ///   It turns to the left of her finger (her hand comes from the bottom right), or to the right
    ///   near the left edge.
    /// - `width`: the play area's width. When given, the lift leans toward the middle near the top,
    ///   so near the top corners the tool sits beside her finger instead of off the screen.
    ///
    /// The lift is full while there is room around the finger, it changes smoothly near the edges,
    /// and the point always moves up and down the same way as her finger.
    static func point(_ finger: CGPoint, lift: CGFloat = tool, top: CGFloat = 0, bottom: CGFloat? = nil,
                      width: CGFloat? = nil) -> CGPoint {
        let ramp = lift + 60
        var l = lift
        var x = finger.x
        // near the top: less lift, leaning toward the middle
        let room = finger.y - top
        if room < ramp {
            let u = max(0, room) / ramp
            l = lift * (0.35 + 0.65 * u)
            if let w = width {
                let side = max(-1, min(1, (w / 2 - finger.x) / (w / 4)))
                x += side * (lift - l) * 0.6
            }
        }
        // near the bottom: the lift turns sideways
        if let b = bottom {
            let below = b - finger.y
            if below < ramp {
                let u = 1 - max(0, below) / ramp          // 0 ... 1 as her finger reaches the bottom
                let up = lift * (1 - 0.75 * u)
                let sideways = lift * 0.9 * u
                // to the left of her finger, or to the right near the left edge
                // (spread over two lifts of width, so the point still moves the same way as her finger)
                let k = max(0, min(1, (finger.x - lift * 0.5) / (lift * 2)))
                x += sideways * (1 - 2 * k)
                l = min(l, up)
            }
        }
        return CGPoint(x: x, y: finger.y - l)
    }

    /// How far to lift a dragged thing whose drawing reaches `below` points under its anchor point,
    /// so its bottom edge still clears her finger (never less than `item`).
    static func carry(below: CGFloat) -> CGFloat { max(item, below + 40) }

    /// How much to turn a held tool so it points from her finger to its tip: its handle toward her
    /// finger and its working end at the tip, like holding a pencil. `tip` and `center` are in the
    /// tool's own picture. Round tools that work with their middle (sponges, bandages) don't turn.
    static func turn(tip: CGPoint, center: CGPoint, finger: CGPoint, lifted: CGPoint) -> Double {
        let tx = tip.x - center.x, ty = tip.y - center.y
        guard hypot(tx, ty) > 18 else { return 0 }
        let want = atan2(Double(lifted.y - finger.y), Double(lifted.x - finger.x))
        let have = atan2(Double(ty), Double(tx))
        var a = want - have
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }

    /// The other way round: where her finger goes to put the lifted point at `target` (screenshot
    /// hooks and tests use it to "hold" a tool or thing over an exact spot).
    static func finger(for target: CGPoint, lift: CGFloat = tool, top: CGFloat = 0, bottom: CGFloat? = nil,
                       width: CGFloat? = nil) -> CGPoint {
        // the lifted y only depends on the finger's y, and always goes the same way as it
        var lo = target.y, hi = target.y + lift * 2 + 60
        if let b = bottom { hi = min(hi, b) }
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            if point(CGPoint(x: lift * 2, y: mid), lift: lift, top: top, bottom: bottom).y < target.y { lo = mid } else { hi = mid }
        }
        let y = (lo + hi) / 2
        var x = target.x
        for _ in 0..<12 { x += target.x - point(CGPoint(x: x, y: y), lift: lift, top: top, bottom: bottom, width: width).x }
        return CGPoint(x: x, y: y)
    }

    /// The offset `point` adds to `finger`.
    static func offset(_ finger: CGPoint, lift: CGFloat = tool, top: CGFloat = 0, bottom: CGFloat? = nil,
                       width: CGFloat? = nil) -> CGSize {
        let p = point(finger, lift: lift, top: top, bottom: bottom, width: width)
        return CGSize(width: p.x - finger.x, height: p.y - finger.y)
    }

    /// Moves a dragged thing's offset from her finger part of the way to `target` (call it on every
    /// drag change), so a thing she picks up glides up above her finger instead of jumping there.
    static func ease(_ current: CGSize, toward target: CGSize, by k: CGFloat = 0.3) -> CGSize {
        CGSize(width: current.width + (target.width - current.width) * k,
               height: current.height + (target.height - current.height) * k)
    }

    /// A small bright ring right where a tool works (it shows through the see-through tool).
    static func drawTip(_ ctx: GraphicsContext, at c: CGPoint, time t: Double, scale: CGFloat = 1) {
        let r: CGFloat = (11 + 1.5 * CGFloat(sin(t * 8))) * scale
        let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.stroke(ring, with: .color(.white.opacity(0.95)), lineWidth: 5 * scale)
        ctx.stroke(ring, with: .color(Theme.pink), lineWidth: 2.5 * scale)
    }
}

/// `FingerLift.drawTip` as a view, for games built from SwiftUI views instead of a Canvas.
struct TipMarker: View {
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, s in
                FingerLift.drawTip(ctx, at: CGPoint(x: s.width / 2, y: s.height / 2), time: tl.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: 40, height: 40)
        .allowsHitTesting(false)
    }
}

/// A round magnifier that shows the spot under a tool tip at `zoom`x, without the tool or her hand
/// in the way. It sits near the top on the side away from the tip, and drops lower if the tip is up
/// there too, so it never covers the place she's working on.
///
/// `draw` paints the whole scene (without the held tool) in the same space `tip` is in.
struct Magnifier: View {
    let tip: CGPoint
    /// The area the magnifier sits in (same space as `tip`).
    let area: CGSize
    var zoom: CGFloat = 2
    var diameter: CGFloat = 176
    /// How far down from the top of `area` it sits.
    var top: CGFloat = 96
    let draw: (GraphicsContext, Date) -> Void

    var body: some View {
        let tip = self.tip, z = zoom, draw = self.draw
        return TimelineView(.animation) { tl in
            Canvas { ctx, s in
                var g = ctx
                g.translateBy(x: s.width / 2, y: s.height / 2)
                g.scaleBy(x: z, y: z)
                g.translateBy(x: -tip.x, y: -tip.y)
                draw(g, tl.date)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 7))
        .overlay(Circle().stroke(Theme.pink.opacity(0.55), lineWidth: 2).padding(5))
        .shadow(color: Theme.ink.opacity(0.25), radius: 8, y: 5)
        .position(Magnifier.center(tip: tip, area: area, diameter: diameter, top: top))
        .allowsHitTesting(false)
    }

    static func center(tip: CGPoint, area: CGSize, diameter d: CGFloat, top: CGFloat) -> CGPoint {
        let left = tip.x > area.width / 2
        var c = CGPoint(x: area.width / 2 + (left ? -1 : 1) * (d * 0.95), y: top + d / 2)
        // the tip is up here too: go below it instead
        if abs(tip.x - c.x) < d * 0.9 && abs(tip.y - c.y) < d * 0.9 {
            c.y = min(area.height - d / 2 - 12, tip.y + d + 30)
        }
        return c
    }
}
