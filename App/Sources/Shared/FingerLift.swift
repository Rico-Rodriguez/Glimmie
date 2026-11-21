import SwiftUI

// MARK: - Tools held by their handle
//
// History: tools first floated 120 pt straight above her finger (a gap to aim across, "I always want to peek
// around my finger"), then worked right at her fingertip (and her finger covered the net, "what's the point,
// I can't see"). Now a tool is held the way a real one is:
//
// - her finger holds the handle, and the working end (the net's hoop, the brush, the scoop) sits ahead of it
//   along the handle (`tool`, about a handle's length), up and to the left, away from her hand, which comes
//   from the bottom right (`lean`). The tool is drawn turned so its handle runs from the working end back to
//   her finger (`turn`, `handle`), so it reads as a tool in her hand, not a thing floating off it;
// - things held by an edge (sponges, towels) sit up and to the left of her finger, her finger at a corner (`grip`);
// - what the tool does reaches well past her fingertip (`spread`): foam, water, polish, scrubbing and the
//   spot it works on are all bigger than a finger, so she sees it working around her finger;
// - a dragged thing (a sticker, a topping, a sock) still floats a little above her finger (`item`), so she
//   can see where it will land;
// - a container that pours or rains (a watering can, a shaker, a sauce bottle, a shower) is held above her
//   finger (`pour`): what falls out lands below it, between the container and her finger, so her hand never
//   covers where it lands. She aims the container itself, not a gap.
//
// Every game passes its points through `point`, so the near-edge rules still apply to dragged things.

enum FingerLift {
    /// How far ahead of her finger, along the handle, a tool's working end is.
    static let tool: CGFloat = 96
    /// How far from her finger the middle of a thing held by its edge (a sponge, a towel) is.
    static let grip: CGFloat = 64
    /// How far to the side a lifted point leans for each point of lift: to the left (her hand comes from
    /// the bottom right), or to the right near the left edge of the screen.
    static let leanSide: CGFloat = 0.42
    /// How far above her finger a container that pours, shakes or rains is held.
    static let pour: CGFloat = 110
    /// How much further than a finger a tool's effect reaches: games multiply their effect radii,
    /// emitter spreads and "close enough" distances by it, so the work shows around her fingertip.
    static let spread: CGFloat = 1.8
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
        guard lift > 0 else { return finger }
        let ramp = lift + 60
        var l = lift
        var x = finger.x
        // how much of the usual lean is left (the bottom edge takes over below)
        var leanK: CGFloat = 1
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
                leanK = 1 - u
            }
        }
        // up and to the left, away from her hand; to the right near the left edge
        // (spread over three lifts of width, so it still moves the same way as her finger)
        let side = max(0, min(1, finger.x / (lift * 3)))
        x -= leanSide * lift * leanK * (2 * side - 1)
        return CGPoint(x: x, y: finger.y - l)
    }

    /// How far to lift a dragged thing whose drawing reaches `below` points under its anchor point,
    /// so its bottom edge still clears her finger (never less than `item`).
    static func carry(below: CGFloat) -> CGFloat { max(item, below + 40) }

    /// Which way a tool held at her fingertip points (from its middle to its working end): up and a
    /// little to the left, with the handle toward her hand (which comes from the bottom right).
    static let lean = CGVector(dx: -leanSide, dy: -1)

    /// How much to turn a held tool so its working end points from the tool toward `lifted` (where it
    /// works) and its handle away. When the tool works right at her finger (no lift), it points along `lean`. `tip` and `center` are in the tool's own picture. Round tools that
    /// work with their middle (sponges, bandages) don't turn.
    static func turn(tip: CGPoint, center: CGPoint, finger: CGPoint, lifted: CGPoint) -> Double {
        let tx = tip.x - center.x, ty = tip.y - center.y
        guard hypot(tx, ty) > 18 else { return 0 }
        let gx = lifted.x - finger.x, gy = lifted.y - finger.y
        let want = hypot(gx, gy) < 4 ? atan2(Double(lean.dy), Double(lean.dx)) : atan2(Double(gy), Double(gx))
        let have = atan2(Double(ty), Double(tx))
        var a = want - have
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }

    /// The way from a tool's working end toward its handle (a unit vector), and how long the handle can
    /// be: toward her finger when the tool works away from it, otherwise back along `lean`, toward her hand.
    static func handle(tip: CGPoint, finger: CGPoint, length: CGFloat) -> (dir: CGVector, length: CGFloat) {
        let dx = finger.x - tip.x, dy = finger.y - tip.y
        let len = hypot(dx, dy)
        if len >= 4 { return (CGVector(dx: dx / len, dy: dy / len), min(len, length)) }
        let l = hypot(lean.dx, lean.dy)
        return (CGVector(dx: -lean.dx / l, dy: -lean.dy / l), length)
    }

    /// The other way round: where her finger goes to put the lifted point at `target` (screenshot
    /// hooks and tests use it to "hold" a tool or thing over an exact spot).
    static func finger(for target: CGPoint, lift: CGFloat = tool, top: CGFloat = 0, bottom: CGFloat? = nil,
                       width: CGFloat? = nil) -> CGPoint {
        guard lift > 0 else { return target }
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
}
