import SwiftUI

/// A tuft has a fixed root, a shaped resting tip and a damped, elastic tip.
/// Small bubbles share the same bent centerline so a tuft moves as a single mass.
final class FoamSculpture {
    struct Tuft {
        var root: CGPoint
        var rest: CGPoint
        var tip: CGPoint
        var speed = CGVector.zero
        var radius: CGFloat
        var tint: RGB
        var seed: Int
    }

    private(set) var tufts: [Tuft] = []
    var held: Int?
    var rinsing = false
    var tint = RGB(0.93, 0.97, 1)
    private var touch = CGPoint.zero
    private var origin = CGPoint.zero
    private var dragged = false

    func begin(_ p: CGPoint) {
        touch = p
        origin = p
        dragged = false
        if rinsing { wash(p); return }
        if let i = tufts.indices.reversed().first(where: { hypot(tufts[$0].tip.x-p.x, tufts[$0].tip.y-p.y) < tufts[$0].radius+12 }) {
            held = i
            return
        }
        guard SGeo.inHead(p, pad: 31), tufts.count < 36 else { return }
        let tip = CGPoint(x: p.x, y: p.y-6)
        tufts.append(Tuft(root: p, rest: tip, tip: tip, radius: 16, tint: tint, seed: tufts.count*17+5))
        held = tufts.count-1
    }

    func move(_ p: CGPoint) {
        if rinsing {
            let count = max(1, min(50, Int(hypot(p.x-touch.x, p.y-touch.y)/14)))
            for i in 1...count {
                let k = CGFloat(i)/CGFloat(count)
                wash(CGPoint(x: touch.x+(p.x-touch.x)*k, y: touch.y+(p.y-touch.y)*k))
            }
        }
        dragged = dragged || hypot(origin.x-p.x, origin.y-p.y)>8
        touch = p
    }

    func moveRinse(at p: CGPoint) { wash(p) }

    private func wash(_ p: CGPoint) {
        held = nil
        for i in tufts.indices.reversed() {
            let base = tufts[i].root, end = tufts[i].tip
            let dx = end.x-base.x, dy = end.y-base.y
            let t = max(0, min(1, ((p.x-base.x)*dx+(p.y-base.y)*dy)/max(1,dx*dx+dy*dy)))
            guard hypot(base.x+t*dx-p.x, base.y+t*dy-p.y)<36+tufts[i].radius*0.55 else { continue }
            if t < 0.42 || hypot(dx,dy)<16 { tufts.remove(at: i) }
            else {
                tufts[i].rest = CGPoint(x: base.x+dx*t*0.68, y: base.y+dy*t*0.68)
                tufts[i].tip = tufts[i].rest
            }
        }
    }

    func shake() {
        for i in tufts.indices {
            let side: CGFloat = tufts[i].root.x < 300 ? -1 : 1
            let length = hypot(tufts[i].rest.x-tufts[i].root.x, tufts[i].rest.y-tufts[i].root.y)
            tufts[i].speed = CGVector(dx: side*(130+length*3), dy: -200)
            if length>72 {
                tufts[i].rest.y += length*0.42
                tufts[i].rest.x -= side*length*0.26
            }
        }
    }

    func advance(_ dt: CGFloat) {
        for i in tufts.indices {
            var f = tufts[i]
            if i == held {
                let target = dragged ? touch : CGPoint(x: f.rest.x, y: f.rest.y-40*dt)
                let dx = target.x-f.root.x, dy = target.y-f.root.y
                let limit = min(1, 165/max(1,hypot(dx,dy)))
                f.rest = CGPoint(x: f.root.x+dx*limit, y: f.root.y+dy*limit)
                f.radius = min(41, f.radius+dt*24)
            }
            f.speed.dx += ((f.rest.x-f.tip.x)*105-f.speed.dx*11)*dt
            f.speed.dy += ((f.rest.y-f.tip.y)*105-f.speed.dy*11)*dt
            f.tip.x += f.speed.dx*dt
            f.tip.y += f.speed.dy*dt
            tufts[i] = f
        }
    }

    func draw(_ g: GraphicsContext, time: CGFloat) {
        for f in tufts {
            let dx = f.tip.x-f.root.x, dy = f.tip.y-f.root.y
            let length = hypot(dx,dy)
            let count = max(2, Int(length/9))
            var blobs: [(CGPoint,CGFloat)] = []
            for j in 0...count {
                let k = CGFloat(j)/CGFloat(count)
                let bend = sin(k * .pi)*min(23,length*0.15)*(f.root.x > 300 ? 1 : -1)
                let c = CGPoint(x: f.root.x+dx*k+bend, y: f.root.y+dy*k)
                let r = f.radius*(1-0.60*k)
                blobs.append((c,r))
                let seed = f.seed+j*5
                let a = shash(seed)*6.28
                blobs.append((CGPoint(x:c.x+cos(a)*r*0.92,y:c.y+sin(a)*r*0.73),r*(0.32+0.26*shash(seed+1))))
                if j.isMultiple(of: 3) {
                    let sparkle = 0.4+0.6*abs(sin(time+CGFloat(seed)))
                    let point = CGPoint(x:c.x-r*0.5,y:c.y-r*0.75)
                    g.fill(Path(ellipseIn: CGRect(x:point.x,y:point.y,width:4,height:3)),with:.color(.white.opacity(sparkle)))
                }
            }
            SpaPainter.foamBlobs(g, blobs, color: f.tint)
        }
    }
}
