import SwiftUI

private struct StreamBed: Codable {
    static let columns = 48
    static let rows = 29
    static let roots = [CGPoint(x: 350, y: 350), CGPoint(x: 630, y: 410)]
    var soil: [Bool] = (0..<(StreamBed.columns * StreamBed.rows)).map { index in
        let x = index % StreamBed.columns, y = index / StreamBed.columns
        return y >= 9 && !(x >= 2 && x <= 9 && y <= 13) && !(x == 10 && y == 12)
    }
    var plants: [PlantKind] = [.pumpkin, .carrot]

    func contains(_ x: Int, _ y: Int) -> Bool {
        x > 0 && x < Self.columns - 1 && y >= 9 && y < Self.rows - 1
    }
}

private final class StreamWater {
    var cells = [CGFloat](repeating: 0, count: StreamBed.columns * StreamBed.rows)
    var growth: [CGFloat] = [0, 0]
    var pumpkin: CGPoint?
    var caught = false
    private var tick = 0

    func step(_ bed: StreamBed) {
        let width = StreamBed.columns
        let spring = 11 * width + 4
        cells[spring] = 1
        tick += 1
        for y in stride(from: StreamBed.rows - 2, through: 9, by: -1) {
            for column in 1..<(width - 1) {
                let x = tick.isMultiple(of: 2) ? column : width - 1 - column
                let i = y * width + x
                if bed.soil[i] { cells[i] = 0 }
                guard cells[i] > 0.004 else { continue }
                let offsets = tick.isMultiple(of: 2) ? [width, 1, -1] : [width, -1, 1]
                for offset in offsets where !bed.soil[i + offset] {
                    let difference = cells[i] - cells[i + offset]
                    let flow = offset == width ? min(cells[i], 1 - cells[i + offset]) : max(0, difference * 0.28)
                    cells[i] -= flow
                    cells[i + offset] += flow
                }
                if y == StreamBed.rows - 2 { cells[i] *= 0.92 }
            }
        }
        for (i, root) in StreamBed.roots.enumerated() where growth[i] < 1 {
            let cell = Int(root.y / 20) * width + Int(root.x / 20)
            if cells[cell - 1...cell + 1].contains(where: { $0 > 0.09 }) {
                growth[i] = min(1, growth[i] + 0.028)
                if growth[i] == 1 && bed.plants[i] == .pumpkin && !caught {
                    pumpkin = CGPoint(x: root.x, y: 132)
                }
            }
        }
        if let p = pumpkin {
            pumpkin = p.x > 904 ? nil : CGPoint(x: p.x + 7, y: p.y + (p.x < 820 ? 0.15 : 3))
        }
    }
}

struct StreamGarden: View {
    let exit: () -> Void
    @State private var bed = GameStorage.load(StreamBed.self, game: GardenSim.gameID, file: "stream.json") ?? StreamBed()
    @State private var water = StreamWater()
    @State private var filling = false
    @State private var previous: CGPoint?

    var body: some View {
        Playground(exit: exit, title: "Garden", classicTitle: "Planting bed", tint: Theme.mint) {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                Canvas { context, size in
                    draw(context, size: size, date: timeline.date)
                }
                .onChange(of: timeline.date) { _ in water.step(bed) }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { dig(to: $0.location) }
                .onEnded { _ in previous = nil; save() })
            .accessibilityLabel("Hillside. Drag from the spring toward the roots to dig a stream.")
        } tools: {
            PlaygroundButton(title: "Dig", icon: "hand.draw.fill", selected: !filling) { filling = false }
            PlaygroundButton(title: "Add soil", icon: "square.stack.3d.up.fill", selected: filling) { filling = true }
            PlaygroundButton(title: "Seeds", icon: "leaf.fill") {
                bed.plants = bed.plants == [.pumpkin, .carrot] ? [.sunflower, .pumpkin] : [.pumpkin, .carrot]
                water.growth = [0, 0]
                water.pumpkin = nil
                water.caught = false
                save()
            }
            PlaygroundButton(title: "New hill", icon: "arrow.counterclockwise") {
                bed = StreamBed()
                water = StreamWater()
                save()
            }
        } classic: { back in
            GardenView(exit: back)
        }
    }

    private func save() {
        GameStorage.save(bed, game: GardenSim.gameID, file: "stream.json")
    }

    private func dig(to p: CGPoint) {
        if previous == nil, let pumpkin = water.pumpkin,
           hypot(p.x - pumpkin.x, p.y - pumpkin.y) < 65 || (p.x > 730 && p.y < 180 && pumpkin.x > 690) {
            water.caught = true
            water.pumpkin = nil
            return
        }
        let start = previous ?? p
        previous = p
        let count = max(1, Int(hypot(p.x - start.x, p.y - start.y) / 10))
        for i in 0...count {
            let fraction = CGFloat(i) / CGFloat(count)
            let x = Int((start.x + (p.x - start.x) * fraction) / 20)
            let y = Int((start.y + (p.y - start.y) * fraction) / 20)
            for dx in -1...1 {
                for dy in -1...1 where bed.contains(x + dx, y + dy) {
                    let xx = x + dx, yy = y + dy
                    guard !(xx < 7 && yy < 14) else { continue }
                    bed.soil[yy * StreamBed.columns + xx] = filling
                }
            }
        }
    }

    private func draw(_ g: GraphicsContext, size: CGSize, date: Date) {
        g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFFDBAB)))
        g.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 180)), with: .color(Theme.sky))
        g.playgroundDot(CGPoint(x: 760, y: 72), radius: 38, color: Theme.lemon)
        for (i, soil) in bed.soil.enumerated() {
            let x = CGFloat(i % StreamBed.columns) * 20, y = CGFloat(i / StreamBed.columns) * 20
            let amount = water.cells[i]
            guard soil || amount > 0.025 else { continue }
            let color: Color = soil ? (i / StreamBed.columns == 9 ? Color(hex: 0x729950) :
                                      Color(hex: i.isMultiple(of: 7) ? 0xB47556 : 0xBE8061)) : Color(hex: 0x44BFE9)
            let height = soil ? 20 : max(2, amount * 20)
            g.fill(Path(CGRect(x: x, y: y + 20 - height, width: 20, height: height)), with: .color(color))
        }
        let ripple = CGFloat(sin(date.timeIntervalSinceReferenceDate * 4))
        g.playgroundDot(CGPoint(x: 90, y: 213), radius: 10 + 2 * ripple, color: .white.opacity(0.85))
        for (i, root) in StreamBed.roots.enumerated() {
            var line = Path()
            line.move(to: CGPoint(x: root.x, y: 180))
            line.addQuadCurve(to: root, control: CGPoint(x: root.x - 20, y: (180 + root.y) / 2))
            g.stroke(line, with: .color(Theme.lemon), style: StrokeStyle(lineWidth: 4, dash: [9, 6]))
            g.playgroundDot(root, radius: 13, color: Theme.lemon)
            GardenPlants.drawCrop(g, kind: bed.plants[i], variant: 0,
                                  at: CGPoint(x: root.x, y: 157 - 26 * water.growth[i]),
                                  size: 0.4 + water.growth[i] * 0.65, rot: 0)
        }
        g.draw(Text("🧺").font(.system(size: 68)), at: CGPoint(x: 775, y: 142))
        g.draw(Text("🌊").font(.system(size: 64)), at: CGPoint(x: 896, y: 156))
        if let p = water.pumpkin {
            GardenPlants.drawCrop(g, kind: .pumpkin, variant: 0, at: p, size: 0.9, rot: p.x / 24)
        }
        if water.caught { g.draw(Text("🎃").font(.system(size: 45)), at: CGPoint(x: 773, y: 115)) }
    }
}
