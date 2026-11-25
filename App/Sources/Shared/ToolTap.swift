import SwiftUI

// MARK: - Tap a spot and the tool does it
//
// Every hands-on game works the same way:
// - drag a tool off its tray and use it under her finger, as always;
// - or tap a tool on its tray: it stays picked (it wears a pink ring). While a tool is picked, a quick tap
//   on the scene makes the tool glide there and do that spot by itself (a little rub in circles, or a
//   hold, through the game's own drag code), and a drag anywhere on the scene uses it directly, without
//   going back to the tray. Tapping the picked tool again puts it down.
//
// `AutoTool` plays the little "do it by itself" motion into the game's drag handlers.

/// Was this touch a tap (not a drag)?
enum ToolTap {
    static let slop: CGFloat = 12
    static func isTap(_ translation: CGSize) -> Bool { hypot(translation.width, translation.height) < slop }
}

/// The motion of a tool doing a spot by itself: it glides from `from` to `spot` along a small arc, rubs
/// there in little circles, and ends where it started rubbing.
final class AutoTool {
    static let glide = 0.3
    static let work = 1.3
    /// How wide the rubbing circles are.
    static let rub: CGFloat = 26

    private var timer: Timer?
    private var started = Date.distantPast
    private var from = CGPoint.zero
    private var spot = CGPoint.zero
    private var step: ((CGPoint) -> Void)?
    private var end: ((CGPoint) -> Void)?

    var running: Bool { timer != nil }

    /// Where the tool is `a` seconds in, or nil once it's done.
    static func point(from: CGPoint, to spot: CGPoint, at a: Double) -> CGPoint? {
        if a < 0 { return from }
        if a < glide {
            let k = CGFloat(a / glide)
            let e = k * k * (3 - 2 * k)
            return CGPoint(x: from.x + (spot.x - from.x) * e, y: from.y + (spot.y - from.y) * e - 40 * sin(e * .pi))
        }
        let w = a - glide
        guard w < work else { return nil }
        // circles that grow in and settle out, turning a bit more than twice
        let env = CGFloat(min(1, w / 0.2) * min(1, (work - w) / 0.25))
        let ang = w / work * 2.3 * 2 * .pi
        return CGPoint(x: spot.x + rub * env * CGFloat(sin(ang)), y: spot.y - rub * 0.7 * env * CGFloat(1 - cos(ang)))
    }

    /// Plays the motion: `step` gets every point (about 60 a second), `end` the last one.
    func run(from: CGPoint, to spot: CGPoint, step: @escaping (CGPoint) -> Void, end: @escaping (CGPoint) -> Void) {
        cancel()
        self.from = from
        self.spot = spot
        self.step = step
        self.end = end
        started = Date()
        step(from)
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Stops the motion, finishing the tool's work where it is (when she touches the screen again).
    func cancel() {
        guard let t = timer else { return }
        t.invalidate()
        timer = nil
        let a = Date().timeIntervalSince(started)
        let last = AutoTool.point(from: from, to: spot, at: min(a, AutoTool.glide + AutoTool.work - 0.001)) ?? spot
        let e = end
        step = nil
        end = nil
        e?(last)
    }

    private func tick() {
        let a = Date().timeIntervalSince(started)
        if let p = AutoTool.point(from: from, to: spot, at: a) {
            step?(p)
        } else {
            timer?.invalidate()
            timer = nil
            let e = end
            step = nil
            end = nil
            e?(spot)
        }
    }
}

