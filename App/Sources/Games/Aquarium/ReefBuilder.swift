import SwiftUI

private enum ReefKind: String, Codable {
    case stone, boulder, slab, anemone

    var width: CGFloat {
        switch self {
        case .stone: return 72
        case .boulder: return 105
        case .slab: return 185
        case .anemone: return 100
        }
    }

    var height: CGFloat {
        switch self {
        case .stone: return 62
        case .boulder: return 87
        case .slab: return 29
        case .anemone: return 78
        }
    }

    var isSupport: Bool { self == .stone || self == .boulder }
}

private struct ReefPiece: Identifiable, Codable {
    var id = UUID()
    var kind: ReefKind
    var x: CGFloat
    var y: CGFloat = 510

    static let starter = [
        ReefPiece(kind: .stone, x: 295), ReefPiece(kind: .stone, x: 421),
        ReefPiece(kind: .slab, x: 565), ReefPiece(kind: .anemone, x: 720)
    ]
}

struct ReefBuilder: View {
    let exit: () -> Void
    @State private var pieces = GameStorage.load([ReefPiece].self, game: AquariumSim.gameID, file: "reef.json")
        ?? ReefPiece.starter
    @State private var grabbed: UUID?
    @State private var fishHome: CGFloat = 720
    @State private var fishFrom: CGFloat = 720
    @State private var fishMoved = Date.distantPast
    @State private var food: CGPoint?
    @State private var fed = Date.distantPast
    @State private var feeding = false
    @State private var slide = CGPoint.zero

    var body: some View {
        Playground(exit: exit, title: "Aquarium", classicTitle: "Fish tank", tint: Theme.sky) {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                Canvas { context, size in
                    draw(context, size: size, date: timeline.date)
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { move($0) }
                .onEnded { _ in settle() })
            .onAppear { fishHome = anemoneX }
            .accessibilityLabel("Reef. Drag two rocks together and place a slab across them.")
        } tools: {
            PlaygroundButton(title: "Stone", icon: "triangle.fill") { add(.stone) }
            PlaygroundButton(title: "Boulder", icon: "circle.fill") { add(.boulder) }
            PlaygroundButton(title: "Slab", icon: "rectangle.fill") { add(.slab) }
            PlaygroundButton(title: "Anemone", icon: "leaf.fill") { add(.anemone) }
            PlaygroundButton(title: "Feed", icon: "fish.fill", selected: feeding) { feeding.toggle() }
            PlaygroundButton(title: "Reset", icon: "arrow.counterclockwise") {
                pieces = ReefPiece.starter
                fishHome = anemoneX
                food = nil
                grabbed = nil
                save()
            }
        } classic: { back in
            AquariumView(exit: back)
        }
    }

    private var anemoneX: CGFloat { pieces.last(where: { $0.kind == .anemone })?.x ?? 720 }

    private func add(_ kind: ReefKind) {
        feeding = false
        if kind == .anemone, pieces.contains(where: { $0.kind == .anemone }) { return }
        guard pieces.count < 24 else { return }
        pieces.append(ReefPiece(kind: kind, x: 105 + CGFloat(pieces.count % 4) * 81))
        save()
    }

    private func move(_ drag: DragGesture.Value) {
        let p = drag.location
        if feeding {
            food = CGPoint(x: max(45, min(905, p.x)), y: max(95, min(455, p.y)))
            fed = Date()
            return
        }
        if grabbed == nil {
            guard let piece = pieces.reversed().first(where: {
                abs(drag.startLocation.x - $0.x) < $0.kind.width / 2 + 14
                    && drag.startLocation.y > $0.y - $0.kind.height - 14 && drag.startLocation.y < $0.y + 14
            }) else { return }
            grabbed = piece.id
            slide = CGPoint(x: piece.x - drag.startLocation.x, y: piece.y - drag.startLocation.y)
        }
        guard let i = pieces.firstIndex(where: { $0.id == grabbed }) else { return }
        pieces[i].x = min(862, max(88, p.x + slide.x))
        pieces[i].y = min(510, max(135, p.y + slide.y))
    }

    private func supports(near x: CGFloat) -> (left: ReefPiece, right: ReefPiece)? {
        let rocks = pieces.filter { $0.kind.isSupport && $0.y >= 490 }
        guard let left = rocks.filter({ $0.x < x - 25 && $0.x > x - 112 }).max(by: { $0.x < $1.x }),
              let right = rocks.filter({ $0.x > x + 25 && $0.x < x + 112 }).min(by: { $0.x < $1.x }),
              right.x - left.x > 92, right.x - left.x < 169 else { return nil }
        return (left, right)
    }

    private func settle() {
        defer { grabbed = nil }
        if feeding { feeding = false; return }
        guard let i = pieces.firstIndex(where: { $0.id == grabbed }) else { return }
        let piece = pieces[i]
        pieces[i].y = 510
        if piece.kind == .slab, let pair = supports(near: piece.x) {
            pieces[i].x = (pair.left.x + pair.right.x) / 2
            pieces[i].y = 510 - min(pair.left.kind.height, pair.right.kind.height) + 8
        }
        for j in pieces.indices where pieces[j].kind == .slab && pieces[j].y < 505 {
            if supports(near: pieces[j].x) == nil { pieces[j].y = 510 }
        }
        let date = Date()
        fishFrom = home(at: date)
        fishHome = anemoneX
        fishMoved = date
        save()
    }

    private func home(at date: Date) -> CGFloat {
        let fraction = CGFloat(min(1, max(0, date.timeIntervalSince(fishMoved) / 1.3)))
        let eased = fraction * fraction * (3 - 2 * fraction)
        return fishFrom + (fishHome - fishFrom) * eased
    }

    private func save() { GameStorage.save(pieces, game: AquariumSim.gameID, file: "reef.json") }

    private func draw(_ g: GraphicsContext, size: CGSize, date: Date) {
        let t = CGFloat(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600))
        g.fill(Path(CGRect(origin: .zero, size: size)),
               with: .linearGradient(Gradient(colors: [Color(hex: 0x9DEAF1), Color(hex: 0x246395)]),
                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: 534)))
        g.fill(Path(roundedRect: CGRect(x: -10, y: 505, width: 970, height: 100), cornerRadius: 34),
               with: .color(Color(hex: 0xEED3A9)))
        for i in 0..<22 {
            let x = CGFloat(i * 47) + 8 * sin(t * 1.8 + CGFloat(i))
            let y = 480 - (t * (20 + CGFloat(i % 3) * 7) + CGFloat(i * 79))
                .truncatingRemainder(dividingBy: 440)
            g.playgroundDot(CGPoint(x: x, y: y), radius: CGFloat(3 + i % 5), color: .white.opacity(0.25))
        }
        let caves = pieces.filter { $0.kind == .slab && $0.y < 505 && $0.id != grabbed && supports(near: $0.x) != nil }
        for cave in caves {
            let mouth = Path(roundedRect: CGRect(x: cave.x - 59, y: cave.y - 2, width: 118,
                                                height: 510 - cave.y), cornerRadius: 17)
            g.fill(mouth, with: .color(Color(hex: 0x183A58)))
        }
        for piece in pieces {
            if piece.kind == .anemone {
                var plant = g
                plant.translateBy(x: piece.x, y: piece.y)
                AquaDecorPainter.drawKind(plant, .anemone, time: t, sway: sin(t * 2), open: 0, seed: 4)
            } else {
                if piece.id == grabbed, piece.kind == .slab, let pair = supports(near: piece.x) {
                    let x = (pair.left.x + pair.right.x) / 2
                    let y = 510 - min(pair.left.kind.height, pair.right.kind.height) + 8
                    g.stroke(rock(piece.kind, x: x, y: y), with: .color(.white.opacity(0.8)),
                             style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
                }
                let stone = rock(piece.kind, x: piece.x, y: piece.y)
                g.fill(stone, with: .linearGradient(Gradient(colors: [Theme.lilac, Color(hex: 0x506187)]),
                                                   startPoint: CGPoint(x: piece.x, y: piece.y - piece.kind.height),
                                                   endPoint: CGPoint(x: piece.x, y: piece.y)))
                g.stroke(stone, with: .color(.white.opacity(0.42)), lineWidth: 3)
            }
        }
        drawEel(g, caves: caves, time: t)
        let age = date.timeIntervalSince(fed)
        let moving = date.timeIntervalSince(fishMoved) < 1.3
        var clown = CGPoint(x: home(at: date) + 25 * sin(t * 1.7),
                            y: 450 + (moving ? -35 : 12 * cos(t * 2)))
        if let food, age < 3.6 {
            let approach = min(1, max(0, min(age, 3.6 - age) / 0.85))
            clown = CGPoint(x: clown.x + (food.x - clown.x) * approach, y: clown.y + (food.y - clown.y) * approach)
            for i in 0..<7 where age < 1.5 {
                g.playgroundDot(CGPoint(x: food.x + CGFloat(i - 3) * 8, y: food.y + CGFloat(age) * 18),
                                radius: 3, color: Theme.lemon)
            }
        }
        let facing = moving ? fishHome - fishFrom : cos(t * 1.7)
        drawFish(g, kind: .clownfish, p: clown, direction: facing, scale: 0.66, time: t)
        for i in 0..<6 {
            let phase = t * 0.77 - CGFloat(i) * 0.095
            let x = 475 + 330 * sin(phase)
            let reef = pieces.contains { abs($0.x - x) < $0.kind.width / 2 + 28 }
            let y = 305 + 151 * cos(phase) + CGFloat(i % 2) * 21 - (reef && cos(phase) > 0.6 ? 37 : 0)
            drawFish(g, kind: .tetra, p: CGPoint(x: x, y: y), direction: cos(phase), scale: 0.52, time: t)
        }
    }

    private func rock(_ kind: ReefKind, x: CGFloat, y: CGFloat) -> Path {
        let frame = CGRect(x: x - kind.width / 2, y: y - kind.height, width: kind.width, height: kind.height)
        return Path(roundedRect: frame, cornerRadius: kind == .slab ? 12 : 24)
    }

    private func drawFish(_ g: GraphicsContext, kind: FishKind, p: CGPoint, direction: CGFloat, scale: CGFloat, time: CGFloat) {
        var fish = g
        fish.translateBy(x: p.x, y: p.y)
        fish.scaleBy(x: direction < 0 ? -scale : scale, y: scale)
        AquaFishPainter.drawLocal(fish, kind: kind, variant: 0, phase: time * 8, amp: 0.5, gulp: 0, puff: 0, time: time)
    }

    private func drawEel(_ g: GraphicsContext, caves: [ReefPiece], time: CGFloat) {
        guard let first = caves.first else { return }
        let second = caves.dropFirst().first
        let travel = second == nil ? 0 : (1 - cos(time * 0.8)) / 2
        let x = first.x + ((second?.x ?? first.x) - first.x) * travel
        let peek = second == nil ? (1 + sin(time * 1.7)) / 2 : sin(travel * .pi)
        let y = 486 - peek * 35
        var body = Path()
        body.move(to: CGPoint(x: x - 36 * peek, y: y + 17))
        body.addQuadCurve(to: CGPoint(x: x + 21 * peek, y: y),
                          control: CGPoint(x: x - 4, y: y - 18))
        if peek > 0.3 {
            g.stroke(body, with: .color(Color(hex: 0x9CC278)), style: StrokeStyle(lineWidth: 22, lineCap: .round))
        }
        if sin(time * 3) > -0.92 {
            for eye in [-5.0, 6.0] {
                g.playgroundDot(CGPoint(x: x + 20 * peek + eye, y: y - 4), radius: 3.2, color: Theme.lemon)
            }
        }
    }
}
