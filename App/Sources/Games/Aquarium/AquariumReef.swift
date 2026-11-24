import SwiftUI

extension AquariumSim {
    func openReef() {
        guard !demo, !reefStarted else { return }
        reefStarted = true
        addDecor(.pillar, x: 412)
        addDecor(.pillar, x: 518)
        addDecor(.slate, x: 630)
        if !decor.contains(where: { $0.kind == .anemone }) { addDecor(.anemone, x: 765) }
        save()
    }

    /// A stone bridge needs a resting support beneath each end. Dropping the roof
    /// from above lets the normal underwater drag and impact animation seat it.
    func bridge(at x: CGFloat) -> CGPoint? {
        let pillars = decor.filter { $0.kind == .pillar && !$0.held && !$0.falling }
        guard let left = pillars.filter({ $0.x < x-24 && $0.x >= x-95 }).max(by: { $0.x < $1.x }),
              let right = pillars.filter({ $0.x > x+24 && $0.x <= x+95 }).min(by: { $0.x < $1.x }),
              (80...152).contains(right.x-left.x) else { return nil }
        return CGPoint(x:(left.x+right.x)/2,y:max(left.y,right.y)-57)
    }

    func updateReef(_ dt: CGFloat) {
        let roofs = decor.filter { $0.kind == .slate && !$0.held && !$0.falling && $0.y < AGeo.sand($0.x)-35 }
        guard let first = roofs.first else { eelSpine.removeAll(); return }
        let a = CGPoint(x:first.x, y:first.y+32)
        let t = CGFloat(time)
        let destination: CGPoint
        if roofs.count > 1 {
            let other = roofs[1]
            let mix = (1-cos(t*0.62))*0.5
            destination = CGPoint(x:a.x+(other.x-a.x)*mix, y:a.y+(other.y+32-a.y)*mix-38*sin(.pi*mix))
        } else {
            destination = CGPoint(x:a.x+32*sin(t*0.9), y:a.y-8*cos(t*1.7))
        }
        if eelSpine.isEmpty {
            eelSpine = (0..<14).map { CGPoint(x:a.x-CGFloat($0)*3,y:a.y+10) }
        }
        let pull = 1-exp(-dt*4)
        eelSpine[0].x += (destination.x-eelSpine[0].x)*pull
        eelSpine[0].y += (destination.y-eelSpine[0].y)*pull
        for i in 1..<eelSpine.count {
            let lead = eelSpine[i-1]
            let dx = eelSpine[i].x-lead.x
            let dy = eelSpine[i].y-lead.y+sin(t*5-CGFloat(i)*0.45)*dt*15
            let length = max(0.001,hypot(dx,dy))
            eelSpine[i] = CGPoint(x:lead.x+6*dx/length, y:lead.y+6*dy/length)
        }
    }

    func drawReef(_ g: GraphicsContext, time t: CGFloat) {
        for slab in decor where slab.kind == .slate {
            if let seat = bridge(at: slab.x), slab.held {
                g.stroke(Path(roundedRect:CGRect(x:seat.x-79,y:seat.y-18,width:158,height:20),cornerRadius:8),
                         with:.color(.white.opacity(0.65)),style:StrokeStyle(lineWidth:2.5,dash:[7,5]))
            }
            guard !slab.held, !slab.falling, slab.y < AGeo.sand(slab.x)-35 else { continue }
            let opening = CGRect(x:slab.x-53, y:slab.y-2,width:106,height:64)
            g.fill(Path(roundedRect:opening,cornerRadius:18),
                   with:.radialGradient(Gradient(colors:[Color(hex:0x103F52).opacity(0.94),Color(hex:0x267887).opacity(0.24),.clear]),
                                        center:CGPoint(x:opening.midX,y:opening.midY),startRadius:9,endRadius:61))
        }
        guard let head = eelSpine.first else { return }
        for i in eelSpine.indices.reversed() {
            let c = eelSpine[i], k = 1-CGFloat(i)/CGFloat(eelSpine.count)
            let r = 2+9*k
            let shape = Path(ellipseIn:CGRect(x:c.x-r*1.3,y:c.y-r,width:r*2.6,height:r*2))
            g.fill(shape, with:.linearGradient(Gradient(colors:[Color(hex:0xACE3AE),Color(hex:0x438F80),Color(hex:0x245C69)]),
                                               startPoint:CGPoint(x:c.x,y:c.y-r),endPoint:CGPoint(x:c.x,y:c.y+r)))
            if i.isMultiple(of: 2) {
                g.fill(Path(ellipseIn:CGRect(x:c.x-2,y:c.y-r*0.6,width:4,height:2.6)),with:.color(Theme.lemon.opacity(0.65)))
            }
        }
        let direction: CGFloat = head.x >= eelSpine[2].x ? 1 : -1
        if sin(t*1.7)>(-0.985) {
            let eye = CGRect(x:head.x+direction*6-3.4,y:head.y-6,width:7,height:7)
            g.fill(Path(ellipseIn:eye),with:.color(Theme.lemon))
            g.fill(Path(ellipseIn:eye.insetBy(dx:2,dy:1)),with:.color(Theme.ink))
        }
    }
}

extension AquaDecorPainter {
    static func reefStone(_ g: GraphicsContext, slab: Bool, seed: Int) {
        let w: CGFloat = slab ? 84 : 33, h: CGFloat = slab ? 24 : 65
        var outline = Path()
        outline.move(to:CGPoint(x:-w*0.92,y:0))
        outline.addQuadCurve(to:CGPoint(x:-w*0.91,y:-h*0.81),control:CGPoint(x:-w*1.13,y:-h*0.48))
        outline.addQuadCurve(to:CGPoint(x:w*0.79,y:-h*0.89),control:CGPoint(x:-w*0.18,y:-h*1.18))
        outline.addQuadCurve(to:CGPoint(x:w*0.94,y:-h*0.1),control:CGPoint(x:w*1.09,y:-h*0.66))
        outline.addQuadCurve(to:CGPoint(x:-w*0.92,y:0),control:CGPoint(x:0,y:h*0.1))
        g.fill(outline,with:.linearGradient(Gradient(colors:[Color(hex:0xAAC4B8),Color(hex:0x738F93),Color(hex:0x46556C)]),
                                            startPoint:CGPoint(x:0,y:-h),endPoint:.zero))
        g.stroke(outline,with:.color(Color(hex:0x425B64)),lineWidth:2.1)
        var clipped = g
        clipped.clip(to:outline)
        for i in 0..<16 {
            let a = CGFloat(i)*2.39+CGFloat(seed)
            let x = cos(a)*w*0.85, y = -h*(0.2+0.65*abs(sin(a*2)))
            clipped.fill(Path(ellipseIn:CGRect(x:x,y:y,width:3+CGFloat(i%4),height:2)),with:.color(.white.opacity(0.23)))
        }
        var seam = Path()
        seam.move(to:CGPoint(x:-w,y:-h*0.44))
        seam.addQuadCurve(to:CGPoint(x:w,y:-h*0.71),control:CGPoint(x:0,y:-h*0.27))
        clipped.stroke(seam,with:.color(Color(hex:0xCCDFBF).opacity(0.55)),lineWidth:2.4)
    }
}
