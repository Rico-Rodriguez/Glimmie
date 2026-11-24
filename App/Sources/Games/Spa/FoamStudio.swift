import SwiftUI

struct FoamStudio: View {
    let exit: () -> Void

    private struct Puff {
        var point: CGPoint
        var radius: CGFloat = 29
        var tint: Color
    }

    @State private var doll = SpaSim()
    @State private var foam: [Puff] = []
    @State private var color: Color = .white
    @State private var rinsing = false
    @State private var last: CGPoint?
    @State private var grabbed: Int?
    @State private var sneeze = Date.distantPast

    var body: some View {
        Playground(exit: exit, title: "Bubble Spa", classicTitle: "Bath toys", tint: Theme.blush) {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                Canvas { context, size in
                    draw(context, size: size, date: timeline.date)
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { sculpt($0.location) }
                .onEnded { _ in last = nil; grabbed = nil })
            .accessibilityLabel("Foam mirror. Drag to shape the bubbles.")
        } tools: {
            PlaygroundButton(title: "Suds", icon: "bubbles.and.sparkles", selected: !rinsing && color == .white) {
                color = .white; rinsing = false
            }
            PlaygroundButton(title: "Pink suds", icon: "paintbrush.pointed.fill", selected: !rinsing && color != .white) {
                color = Theme.blush; rinsing = false
            }
            PlaygroundButton(title: "Shower", icon: "shower.fill", selected: rinsing) { rinsing.toggle() }
            PlaygroundButton(title: "Rinse all", icon: "drop.fill") { foam.removeAll(); grabbed = nil; last = nil }
            PlaygroundButton(title: "Achoo!", icon: "wind") { shake() }
        } classic: { back in
            SpaView(exit: back)
        }
    }

    private func sculpt(_ point: CGPoint) {
        let p = CGPoint(x: min(685, max(265, point.x)), y: min(465, max(40, point.y)))
        if rinsing {
            let from = last ?? point
            let count = max(1, Int(hypot(point.x - from.x, point.y - from.y) / 24))
            for i in 0...count {
                let t = CGFloat(i) / CGFloat(count)
                let center = CGPoint(x: from.x + t * (point.x - from.x), y: from.y + t * (point.y - from.y))
                foam.removeAll { hypot($0.point.x - center.x, $0.point.y - center.y) < 68 }
            }
            last = point
            return
        }
        if last == nil && hypot(point.x - 475, point.y - 343) < 28 {
            shake()
            last = p
            return
        }
        if let last {
            let distance = hypot(p.x - last.x, p.y - last.y)
            guard distance >= 17 else { return }
            let count = min(18, max(1, Int(distance / 17)))
            let tint = grabbed.map { foam[$0].tint } ?? color
            for i in 1...count where foam.count < 240 {
                let t = CGFloat(i) / CGFloat(count)
                foam.append(Puff(point: CGPoint(x: last.x + (p.x - last.x) * t, y: last.y + (p.y - last.y) * t),
                                 radius: 24 + CGFloat(foam.count % 4) * 3, tint: tint))
            }
        } else {
            grabbed = foam.lastIndex { hypot($0.point.x - p.x, $0.point.y - p.y) < 30 }
            if grabbed == nil && foam.count < 240 {
                foam.append(Puff(point: p, radius: 35, tint: color))
            }
        }
        last = p
    }

    private func shake() {
        sneeze = Date()
        guard let highest = foam.min(by: { $0.point.y < $1.point.y }), highest.point.y < 220 else { return }
        for i in foam.indices where hypot(foam[i].point.x - highest.point.x, foam[i].point.y - highest.point.y) < 65 {
            foam[i].point.y += 78
            foam[i].point.x += highest.point.x < 475 ? 38 : -38
        }
    }

    private func draw(_ g: GraphicsContext, size: CGSize, date: Date) {
        let box = CGRect(origin: .zero, size: size)
        g.fill(Path(box), with: .linearGradient(Gradient(colors: [Theme.lilac, Theme.blush]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let mirror = Path(roundedRect: CGRect(x: 203, y: 22, width: 544, height: 531), cornerRadius: 110)
        g.fill(mirror, with: .linearGradient(Gradient(colors: [.white, Theme.sky]),
                                              startPoint: .zero, endPoint: CGPoint(x: 720, y: 550)))
        g.stroke(mirror, with: .color(.white), lineWidth: 10)
        let age = date.timeIntervalSince(sneeze)
        let wiggle = age < 0.8 ? CGFloat(sin(age * 38) * exp(-age * 5) * 22) : 0
        var face = g
        face.translateBy(x: 145 + wiggle, y: -38)
        face.scaleBy(x: 1.1, y: 1.1)
        let expression: Expression = age < 0.2 ? .blink : (age < 0.85 ? .happy : .normal)
        if let layers = doll.layers[expression] {
            for (layer, paints, _) in layers {
                ArtPainter.draw(layer.shapes, paints, in: face)
            }
        }
        let counter = Path(roundedRect: CGRect(x: -20, y: 520, width: 990, height: 90), cornerRadius: 35)
        g.fill(counter, with: .color(Theme.mint))
        for (i, puff) in foam.enumerated() {
            let wobble = wiggle * CGFloat(i % 4 + 1) / 4
            let p = CGPoint(x: puff.point.x + wobble, y: puff.point.y)
            g.playgroundDot(p, radius: puff.radius + 2, color: Theme.sky.opacity(0.72))
            g.playgroundDot(p, radius: puff.radius, color: puff.tint)
            g.playgroundDot(CGPoint(x: p.x - puff.radius * 0.28, y: p.y - puff.radius * 0.3),
                            radius: puff.radius * 0.28, color: .white.opacity(0.87))
        }
    }
}
