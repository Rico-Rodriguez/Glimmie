import SwiftUI

/// Water occupies connected pockets in the soil. Gravity drains a pocket downward first,
/// then its free surface levels against its neighbors. Roots draw from nearby wet pockets.
final class GardenSpring {
    static let width = 112, height = 20
    static let cell: CGFloat = 8
    static let top: CGFloat = 550
    static let inlet = 3 * width + 21
    static var area: CGRect { CGRect(x: 64, y: top, width: 896, height: 160) }
    var dug = Set<Int>()
    private(set) var water = [Float](repeating: 0, count: width * height)
    private var fraction: CGFloat = 0
    private var reversed = false
    private var hollow = Path()
    var enabled = false
    var filling = false
    var previous: CGPoint?
    var pumpkin: (position: CGPoint, velocity: CGVector, angle: CGFloat, variant: Int)?

    func prepare(_ saved: [Int]?) {
        enabled = true
        if let saved { dug = Set(saved.filter { (0..<water.count).contains($0) }) }
        for y in 2...5 { for x in 16...22 { dug.insert(y * Self.width + x) } }
        for x in 22...24 { dug.insert(4 * Self.width + x) }
        rebuild()
        for i in dug where i % Self.width <= 22 && i / Self.width >= 3 { water[i] = 0.9 }
    }

    func center(_ i: Int) -> CGPoint {
        CGPoint(x: 68 + CGFloat(i % Self.width) * 8, y: Self.top + 4 + CGFloat(i / Self.width) * 8)
    }

    func stroke(_ p: CGPoint) -> Bool {
        let start = previous ?? p
        previous = p
        let steps = max(1, Int(hypot(p.x - start.x, p.y - start.y) / 4))
        var changed = false
        for k in 0...steps {
            let t = CGFloat(k) / CGFloat(steps)
            let x = Int((start.x + t * (p.x - start.x) - 64) / 8)
            let y = Int((start.y + t * (p.y - start.y) - Self.top) / 8)
            for j in -1...1 where (1..<Self.height-1).contains(y+j) {
                for d in -1...1 where (1..<Self.width-1).contains(x+d) {
                    let i = (y+j) * Self.width + x+d
                    if filling {
                        guard i != Self.inlet else { continue }
                        if dug.remove(i) != nil { water[i] = 0; changed = true }
                    } else if dug.insert(i).inserted { changed = true }
                }
            }
        }
        if changed { rebuild() }
        return changed
    }

    private func rebuild() {
        hollow = Path()
        for i in dug {
            let p = center(i)
            hollow.addEllipse(in: CGRect(x: p.x-6, y: p.y-6, width: 12, height: 12))
        }
    }

    func advance(_ dt: CGFloat) {
        fraction += dt
        while fraction >= 1.0 / 45 {
            fraction -= 1.0 / 45
            water[Self.inlet] = 1
            reversed.toggle()
            for y in stride(from: Self.height-2, through: 1, by: -1) {
                for k in 1..<Self.width-1 {
                    let i = y * Self.width + (reversed ? Self.width-1-k : k)
                    guard water[i] > 0.015 else { continue }
                    for d in [Self.width, reversed ? 1 : -1, reversed ? -1 : 1] where dug.contains(i+d) {
                        let flow = d == Self.width ? min(water[i], 1-water[i+d]) : max(0, (water[i]-water[i+d])*0.45)
                        water[i] -= flow
                        water[i+d] += flow
                    }
                }
            }
        }
    }

    func irrigates(x: CGFloat, y: CGFloat) -> Bool {
        guard enabled else { return false }
        let col = Int((x-64)/8), row = Int((y-Self.top)/8)
        for j in -2...2 { for k in -2...2 {
            let i = (row+j)*Self.width + col+k
            if water.indices.contains(i), water[i] > 0.1 { return true }
        } }
        return false
    }

    func draw(_ g: GraphicsContext, time: CGFloat) {
        guard enabled else { return }
        g.fill(hollow, with: .color(Color(hex: 0x48362D)))
        var film = Path(), glints = Path()
        for i in dug where water[i] > 0.04 {
            let p = center(i), depth = CGFloat(water[i])*8
            film.addRoundedRect(in: CGRect(x: p.x-5, y: p.y+4-depth, width: 10, height: depth+1),
                                cornerSize: CGSize(width: 2, height: 2))
            if i >= Self.width, water[i-Self.width] < 0.08, sin(time*4+p.x*0.08) > 0 {
                glints.move(to: CGPoint(x: p.x-3, y: p.y+4-depth))
                glints.addLine(to: CGPoint(x: p.x+3, y: p.y+4-depth))
            }
        }
        g.fill(film, with: .linearGradient(Gradient(colors: [Color(hex: 0x90ECDB), Color(hex: 0x3387A6)]),
                                          startPoint: CGPoint(x: 0,y: 560), endPoint: CGPoint(x: 0,y: 700)))
        g.stroke(glints, with: .color(.white.opacity(0.79)), lineWidth: 1.6)
        let source = center(Self.inlet)
        for i in 0..<5 {
            let phase = (time*1.8+CGFloat(i)/5).truncatingRemainder(dividingBy: 1)
            let x = source.x-22 + 21*phase
            let y = source.y-25 + 30*phase*phase
            g.fill(Path(ellipseIn: CGRect(x:x,y:y,width:4,height:6)),with:.color(.cyan.opacity(0.85)))
        }
    }
}
