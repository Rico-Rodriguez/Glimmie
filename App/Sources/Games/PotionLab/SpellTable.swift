import SwiftUI

private enum SpellIngredient: String, Codable, CaseIterable {
    case berry, bean, pebble

    var name: String {
        switch self {
        case .berry: return "Bubble berry"
        case .bean: return "Spring bean"
        case .pebble: return "Heavy pebble"
        }
    }

    var icon: String {
        switch self {
        case .berry: return "arrow.up.circle.fill"
        case .bean: return "arrow.up.and.down.circle.fill"
        case .pebble: return "arrow.down.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .berry: return Theme.sky
        case .bean: return Theme.mint
        case .pebble: return Theme.lilac
        }
    }
}

private struct SpellToy {
    var position: CGPoint
    var symbol: String
    var size: CGFloat
    var velocity = CGVector.zero
    var spell: [SpellIngredient] = []

    var floating: Bool { spell.contains(.berry) && !spell.contains(.pebble) }
    var heavy: Bool { spell.contains(.pebble) && !spell.contains(.berry) }
    var bouncy: Bool { spell.contains(.bean) }
}

private final class SpellPlay {
    static let bell = CGPoint(x: 581, y: 123)
    static let floor: CGFloat = 496
    var toys = [
        SpellToy(position: CGPoint(x: 590, y: SpellPlay.floor), symbol: "🐸", size: 88),
        SpellToy(position: CGPoint(x: 743, y: SpellPlay.floor), symbol: "⭐", size: 48),
        SpellToy(position: CGPoint(x: 803, y: SpellPlay.floor), symbol: "⭐", size: 43),
        SpellToy(position: CGPoint(x: 858, y: SpellPlay.floor), symbol: "⭐", size: 55)
    ]
    var held: Int?
    private(set) var rang = Date.distantPast
    private var previousDate: Date?

    func step(_ date: Date) {
        let dt = CGFloat(min(0.035, max(0, date.timeIntervalSince(previousDate ?? date))))
        previousDate = date
        for i in toys.indices where i != held {
            var toy = toys[i]
            if toy.floating {
                toy.velocity.dy += ((284 - toy.position.y) * 7 - toy.velocity.dy * 1.7) * dt
            } else {
                toy.velocity.dy += (toy.heavy ? 1120 : 710) * dt
            }
            toy.velocity.dx *= pow(0.42, dt)
            toy.position.x += toy.velocity.dx * dt
            toy.position.y += toy.velocity.dy * dt
            if toy.position.x < 366 || toy.position.x > 907 {
                toy.position.x = min(907, max(366, toy.position.x))
                toy.velocity.dx *= -0.65
            }
            if toy.position.y < 90 {
                toy.position.y = 90
                toy.velocity.dy = abs(toy.velocity.dy) * 0.54
            }
            if toy.position.y >= Self.floor {
                toy.position.y = Self.floor
                toy.velocity.dy = toy.bouncy && toy.velocity.dy > 45
                    ? -toy.velocity.dy * (toy.heavy ? 0.38 : 0.74) : 0
            }
            if hypot(toy.position.x - Self.bell.x, toy.position.y - Self.bell.y) < 42,
               date.timeIntervalSince(rang) > 0.7, abs(toy.velocity.dy) > 65 {
                rang = date
                Sound.shared.play(.whoosh, volume: 0.75)
            }
            toys[i] = toy
        }
    }
}

struct SpellTable: View {
    let exit: () -> Void
    @State private var play = SpellPlay()
    @State private var ingredients: [SpellIngredient] = []
    @State private var brewed: [SpellIngredient] = []
    @State private var favorite = GameStorage.load([SpellIngredient].self, game: PotionSim.gameID, file: "spell.json") ?? []
    @State private var tool: Tool = .hand
    @State private var lastBrew = Date.distantPast

    private enum Tool { case hand, potion, water }

    var body: some View {
        Playground(exit: exit, title: "Potion Lab", classicTitle: "Potion bench", tint: Theme.lilac) {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                Canvas { context, size in
                    draw(context, size: size, date: timeline.date)
                }
                .onChange(of: timeline.date) { play.step($0) }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { interact($0) }
                .onEnded { release($0) })
            .accessibilityLabel("Spell table. Stir the cauldron and brush the potion on the wooden toys.")
        } tools: {
            ForEach(SpellIngredient.allCases, id: \.self) { ingredient in
                PlaygroundButton(title: ingredient.name, icon: ingredient.icon, selected: ingredients.contains(ingredient)) {
                    if ingredients.contains(ingredient) {
                        ingredients.removeAll { $0 == ingredient }
                    } else {
                        if ingredients.count == 2 { ingredients.removeFirst() }
                        ingredients.append(ingredient)
                    }
                }
            }
            PlaygroundButton(title: "Stir", icon: "arrow.triangle.2.circlepath", selected: tool == .potion) { brew() }
            PlaygroundButton(title: "Hand", icon: "hand.point.up.left.fill", selected: tool == .hand) { tool = .hand }
            PlaygroundButton(title: "Water", icon: "drop.fill", selected: tool == .water) { tool = .water }
        } classic: { back in
            PotionLabView(exit: back)
        }
    }

    private func brew() {
        guard !ingredients.isEmpty else { return }
        brewed = ingredients
        favorite = brewed
        GameStorage.save(favorite, game: PotionSim.gameID, file: "spell.json")
        lastBrew = Date()
        tool = .potion
    }

    private func interact(_ drag: DragGesture.Value) {
        let p = drag.location
        if drag.startLocation.x < 338 {
            if drag.startLocation.y > 378 && drag.startLocation.x > 234 {
                if brewed.isEmpty && !favorite.isEmpty { ingredients = favorite; brew() }
                else if !brewed.isEmpty { tool = .potion }
            } else if drag.startLocation.y > 240, Date().timeIntervalSince(lastBrew) > 0.55 {
                brew()
            }
            return
        }
        let range = play.toys.indices.filter {
            let toy = play.toys[$0]
            return hypot(p.x - toy.position.x, p.y - toy.position.y) < toy.size / 2 + 21
        }
        switch tool {
        case .potion, .water:
            for i in range {
                let next = tool == .potion ? brewed : []
                guard play.toys[i].spell != next else { continue }
                play.toys[i].spell = next
                if play.toys[i].floating { play.toys[i].velocity.dy = -115 }
            }
        case .hand:
            if play.held == nil { play.held = range.last }
            guard let i = play.held else { return }
            play.toys[i].position = CGPoint(x: min(907, max(366, p.x)), y: min(SpellPlay.floor, max(90, p.y)))
            play.toys[i].velocity = .zero
        }
    }

    private func release(_ drag: DragGesture.Value) {
        if let i = play.held {
            let toy = play.toys[i]
            let speedX = (drag.predictedEndLocation.x - drag.location.x) * 4
            let speedY = (drag.predictedEndLocation.y - drag.location.y) * 4
            let spring = toy.bouncy && toy.floating ? max(0, toy.position.y - 284) * 3.9 : 0
            play.toys[i].velocity = CGVector(dx: min(850, max(-850, speedX)),
                                             dy: min(900, max(-1000, speedY - spring)))
            play.held = nil
        } else if tool == .potion && drag.startLocation.x >= 338 {
            tool = .hand
        }
    }

    private func draw(_ g: GraphicsContext, size: CGSize, date: Date) {
        let background = Path(CGRect(origin: .zero, size: size))
        g.fill(background, with: .linearGradient(Gradient(colors: [Color(hex: 0x34234D), Color(hex: 0x755892)]),
                                                 startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let desk = Path(roundedRect: CGRect(x: -10, y: 511, width: 970, height: 85), cornerRadius: 21)
        g.fill(desk, with: .color(Color(hex: 0xBE835E)))
        let potBox = CGRect(x: 48, y: 275, width: 210, height: 224)
        g.fill(Path(roundedRect: potBox, cornerRadius: 74), with: .color(Color(hex: 0x2A203F)))
        g.stroke(Path(roundedRect: potBox, cornerRadius: 74), with: .color(Theme.lilac), lineWidth: 6)
        let surface = Path(ellipseIn: CGRect(x: 48, y: 262, width: 210, height: 64))
        g.fill(surface, with: .color(ingredients.last?.tint ?? Theme.lilac.opacity(0.45)))
        let time = CGFloat(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600))
        let stirred = date.timeIntervalSince(lastBrew) < 1
        for i in 0..<12 {
            let a = time * (stirred ? 8 : 2) + CGFloat(i) * 1.6
            let p = CGPoint(x: 153 + cos(a) * CGFloat(20 + i * 6), y: 289 + sin(a) * 20)
            g.playgroundDot(p, radius: CGFloat(3 + i % 6), color: .white.opacity(0.55))
        }
        for (i, ingredient) in ingredients.enumerated() {
            g.draw(Image(systemName: ingredient.icon), at: CGPoint(x: 125 + 53 * CGFloat(i), y: 391))
        }
        let bottle = Path(roundedRect: CGRect(x: 263, y: 419, width: 61, height: 78), cornerRadius: 23)
        g.fill(bottle, with: .color(brewed.last?.tint ?? favorite.last?.tint ?? .white.opacity(0.22)))
        g.stroke(bottle, with: .color(.white.opacity(0.85)), lineWidth: 4)
        g.fill(Path(roundedRect: CGRect(x: 282, y: 403, width: 23, height: 21), cornerRadius: 4), with: .color(Theme.peach))
        let badge = brewed.isEmpty ? favorite : brewed
        for (i, ingredient) in badge.enumerated() {
            g.draw(Image(systemName: ingredient.icon), at: CGPoint(x: 293, y: 445 + CGFloat(i) * 22))
        }
        let age = date.timeIntervalSince(play.rang)
        let tilt = age < 0.8 ? CGFloat(sin(age * 35) * 12 * (1 - age)) : 0
        var bell = g
        bell.translateBy(x: SpellPlay.bell.x + tilt, y: SpellPlay.bell.y)
        bell.draw(Text("🔔").font(.system(size: 66)), at: .zero)
        g.fill(Path(CGRect(x: SpellPlay.bell.x - 2, y: 0, width: 4, height: 87)), with: .color(Theme.peach))
        for toy in play.toys {
            if let ingredient = toy.spell.last {
                g.playgroundDot(toy.position, radius: toy.size * 0.58, color: ingredient.tint.opacity(0.42))
            }
            g.draw(Text(toy.symbol).font(.system(size: toy.size)), at: toy.position)
        }
        if age < 0.54 {
            for i in 0..<6 {
                let a = Double(i) * .pi / 3
                let distance = 38 + CGFloat(age) * 92
                g.playgroundDot(CGPoint(x: SpellPlay.bell.x + CGFloat(cos(a)) * distance,
                                        y: SpellPlay.bell.y + CGFloat(sin(a)) * distance),
                                radius: 5, color: Theme.lemon.opacity(1 - age))
            }
        }
    }
}
