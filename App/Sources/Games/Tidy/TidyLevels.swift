import SwiftUI

// MARK: - Tidy Up levels
//
// A level is one piece of furniture (a scene, 760 x 500 points) and a list of slots. Each slot takes one
// item of a kind; a `strict` slot only takes that color (books, crayons, socks sorted by color), and its
// ghost is tinted so she can see which color goes there. Slots that share a `stack` number fill in order
// (plates, towels, blocks), so things pile up from the bottom: a slot in a stack only opens once every slot
// of its stack that sits lower on screen is filled. There is one item per slot.

struct TidySlot {
    let kind: TidyKind
    /// Center of the item in scene coordinates.
    let pos: CGPoint
    var rot: CGFloat = 0
    var color: Int
    var strict = false
    var stack: Int?
}

enum TidyScene: String, CaseIterable {
    case fridge, bookshelf, cupboard, drawer, bathroom, pencilCase, toys, closet, socks, backpack, pantry, crate

    static let size = CGSize(width: 760, height: 500)

    /// The room's wall behind the furniture.
    var wall: (TRGB, TRGB) {
        switch self {
        case .fridge, .cupboard, .drawer, .pantry, .crate: return (TRGB(0xFFF1E4), TRGB(0xFFE0CC))
        case .bathroom: return (TRGB(0xE6FAF6), TRGB(0xC9EEE8))
        default: return (TRGB(0xF5EEFF), TRGB(0xE6DAFF))
        }
    }
    /// Top-down scenes (looking into a drawer or box) get a softer shadow under their items.
    var topDown: Bool {
        switch self {
        case .drawer, .pencilCase, .socks, .crate: return true
        default: return false
        }
    }
}

struct TidyLevel: Identifiable {
    let id: String
    let scene: TidyScene
    let slots: [TidySlot]
}

enum TidyLevels {
    /// Easy levels first (one of each furniture), then the bigger ones.
    static let all: [TidyLevel] = [
        fridge1, bookshelf1, drawer1, toys1, bathroom1, pencil1, closet1, socks1, backpack1, cupboard1, pantry1, crate1,
        fridge2, bookshelf2, drawer2, toys2, bathroom2, pencil2, closet2, socks2, backpack2, cupboard2, pantry2, crate2,
    ]

    // MARK: Slot helpers

    /// A slot standing on a surface: `bottom` is where the item's lowest edge sits.
    static func on(_ k: TidyKind, _ x: CGFloat, _ bottom: CGFloat, rot: CGFloat = 0, color: Int? = nil,
                   strict: Bool = false, stack: Int? = nil) -> TidySlot {
        let s = k.size
        let h = abs(sin(rot)) * s.width + abs(cos(rot)) * s.height
        return TidySlot(kind: k, pos: CGPoint(x: x, y: bottom - h / 2), rot: rot, color: color ?? k.defaultColor, strict: strict, stack: stack)
    }

    /// A slot centered at a point (for drawers and boxes seen from above).
    static func at(_ k: TidyKind, _ x: CGFloat, _ y: CGFloat, rot: CGFloat = 0, color: Int? = nil,
                   strict: Bool = false, stack: Int? = nil) -> TidySlot {
        TidySlot(kind: k, pos: CGPoint(x: x, y: y), rot: rot, color: color ?? k.defaultColor, strict: strict, stack: stack)
    }

    /// Items stacked straight up from `bottom`, `step` apart.
    static func pile(_ k: TidyKind, _ x: CGFloat, _ bottom: CGFloat, count: Int, step: CGFloat, group: Int,
                     colors: [Int]? = nil, strict: Bool = false) -> [TidySlot] {
        (0..<count).map { i in
            on(k, x, bottom - CGFloat(i) * step, color: colors.map { $0[i % $0.count] }, strict: strict, stack: group)
        }
    }

    // MARK: Fridge (cabinet 120...560, shelves at 170 and 310, crisper bottom 470, door bins at 160, 300, 440)

    static let fridge1 = TidyLevel(id: "fridge1", scene: .fridge, slots: [
        on(.milk, 200, 170), on(.juice, 270, 170),
        on(.cheese, 420, 310),
        on(.apple, 230, 470), on(.apple, 300, 470, color: 3),
    ])

    static let fridge2 = TidyLevel(id: "fridge2", scene: .fridge, slots: [
        on(.milk, 180, 170), on(.jam, 260, 170), on(.yogurt, 330, 170), on(.yogurt, 386, 170, color: 2), on(.cheese, 470, 170),
        on(.broccoli, 200, 310), on(.jam, 290, 310, color: 6),
        on(.apple, 190, 470), on(.orange, 260, 470), on(.carrot, 400, 470, rot: .pi / 2, stack: 1), on(.carrot, 400, 444, rot: .pi / 2, stack: 1),
        on(.juice, 625, 160), on(.egg, 612, 300), on(.egg, 645, 300), on(.egg, 678, 300),
    ])

    // MARK: Bookshelf (frame 120...640, shelves at 160, 320, 480)

    static let bookshelf1 = TidyLevel(id: "bookshelf1", scene: .bookshelf, slots: [
        on(.book, 170, 160, color: 0, strict: true), on(.book, 206, 160, color: 2, strict: true),
        on(.book, 242, 160, color: 5, strict: true), on(.book, 278, 160, color: 7, strict: true),
        on(.plant, 540, 160),
        on(.teddy, 380, 320),
    ])

    static let bookshelf2 = TidyLevel(id: "bookshelf2", scene: .bookshelf, slots: [
        on(.book, 166, 160, color: 0, strict: true), on(.book, 202, 160, color: 1, strict: true), on(.book, 238, 160, color: 2, strict: true),
        on(.book, 274, 160, color: 3, strict: true), on(.book, 310, 160, color: 5, strict: true), on(.book, 346, 160, color: 6, strict: true),
        on(.frame, 540, 160),
        on(.teddy, 200, 320, color: 6), on(.book, 470, 320, color: 7), on(.book, 506, 320, color: 4), on(.book, 552, 320, rot: 0.24, color: 2),
        on(.plant, 200, 480), on(.star, 380, 480), on(.ball, 550, 480, color: 5),
    ])

    // MARK: Cupboard (inside 160...600, shelf at 240, floor at 480)

    static let cupboard1 = TidyLevel(id: "cupboard1", scene: .cupboard, slots:
        pile(.plate, 270, 240, count: 4, step: 17, group: 1)
        + [on(.mug, 430, 240), on(.mug, 510, 240, color: 4)]
        + pile(.bowl, 380, 480, count: 2, step: 20, group: 2, colors: [7, 2])
    )

    static let cupboard2 = TidyLevel(id: "cupboard2", scene: .cupboard, slots:
        pile(.plate, 260, 240, count: 5, step: 17, group: 1)
        + [on(.mug, 410, 240, color: 0), on(.mug, 480, 240, color: 2), on(.mug, 550, 240, color: 4)]
        + pile(.bowl, 260, 480, count: 3, step: 20, group: 2, colors: [7, 10, 6])
        + [on(.glass, 420, 480), on(.glass, 480, 480, color: 7), on(.glass, 540, 480, color: 2)]
    )

    // MARK: Cutlery drawer, seen from above (compartments centered at 235, 380, 525; y center 235)

    static let drawer1 = TidyLevel(id: "drawer1", scene: .drawer, slots: [
        at(.fork, 222, 235), at(.fork, 250, 235),
        at(.spoon, 366, 235), at(.spoon, 396, 235),
        at(.knife, 512, 235), at(.knife, 538, 235),
    ])

    static let drawer2 = TidyLevel(id: "drawer2", scene: .drawer, slots: [
        at(.fork, 192, 235), at(.fork, 220, 235), at(.fork, 248, 235), at(.fork, 276, 235),
        at(.spoon, 336, 235), at(.spoon, 366, 235), at(.spoon, 396, 235), at(.spoon, 426, 235),
        at(.knife, 486, 235, color: 7), at(.knife, 512, 235, color: 6), at(.knife, 538, 235, color: 5), at(.knife, 564, 235, color: 4),
    ])

    // MARK: Bathroom (shelf at 190, counter at 480, cup at x 200, sink 300...440, towels at 590)

    static let bathroom1 = TidyLevel(id: "bathroom1", scene: .bathroom, slots: [
        on(.toothbrush, 190, 468, rot: -0.16, color: 4), on(.toothbrush, 212, 468, rot: 0.16, color: 7),
        on(.duck, 260, 190),
        on(.soap, 480, 480),
    ] + pile(.towel, 590, 480, count: 2, step: 30, group: 1, colors: [10, 7]))

    static let bathroom2 = TidyLevel(id: "bathroom2", scene: .bathroom, slots: [
        on(.toothbrush, 186, 468, rot: -0.2, color: 4), on(.toothbrush, 201, 468, color: 2), on(.toothbrush, 216, 468, rot: 0.2, color: 7),
        on(.toothpaste, 250, 190), on(.shampoo, 330, 190), on(.shampoo, 390, 190, color: 4), on(.duck, 500, 190),
        on(.soap, 480, 480, color: 10),
    ] + pile(.towel, 590, 480, count: 3, step: 30, group: 1, colors: [5, 10, 7]))

    // MARK: Pencil case, seen from above (crayons row y 160, pencils row y 330)

    static let pencil1 = TidyLevel(id: "pencil1", scene: .pencilCase, slots: [
        at(.crayon, 200, 160, color: 0, strict: true), at(.crayon, 240, 160, color: 1, strict: true), at(.crayon, 280, 160, color: 2, strict: true),
        at(.crayon, 320, 160, color: 3, strict: true), at(.crayon, 360, 160, color: 5, strict: true),
        at(.eraser, 540, 160),
    ])

    static let pencil2 = TidyLevel(id: "pencil2", scene: .pencilCase, slots:
        [0, 1, 2, 3, 4, 5, 6, 7].enumerated().map { i, c in at(.crayon, 180 + CGFloat(i) * 36, 160, color: c, strict: true) }
        + [at(.eraser, 540, 130), at(.eraser, 540, 190, color: 5),
           at(.pencil, 200, 330, color: 2), at(.pencil, 230, 330, color: 4), at(.pencil, 260, 330, color: 7),
           at(.ruler, 450, 330, rot: .pi / 2)]
    )

    // MARK: Toy cubbies (cells centered x 213, 380, 547; cell floors at 240 and 480)

    static let toys1 = TidyLevel(id: "toys1", scene: .toys, slots: [
        on(.ball, 213, 240), on(.teddy, 380, 240), on(.car, 547, 480),
    ] + pile(.block, 213, 480, count: 3, step: 56, group: 1, colors: [0, 2, 5]))

    static let toys2 = TidyLevel(id: "toys2", scene: .toys, slots: [
        on(.ball, 188, 240, color: 5), on(.ball, 240, 240, color: 7),
        on(.teddy, 380, 240), on(.star, 547, 240),
        on(.car, 380, 480, color: 5), on(.duck, 547, 480),
    ] + pile(.block, 213, 480, count: 4, step: 56, group: 1, colors: [0, 2, 3, 5], strict: true))

    // MARK: Closet (top shelf at 110, rail at 140, floor at 480)

    static func hang(_ x: CGFloat, color: Int) -> TidySlot {
        at(.shirt, x, 136 + TidyKind.shirt.size.height / 2, color: color)
    }

    static let closet1 = TidyLevel(id: "closet1", scene: .closet, slots: [
        hang(240, color: 7), hang(380, color: 5), hang(520, color: 2),
        on(.hat, 300, 110),
        on(.shoe, 330, 480), on(.shoe, 420, 480),
    ])

    static let closet2 = TidyLevel(id: "closet2", scene: .closet, slots: [
        hang(205, color: 0), hang(310, color: 2), hang(415, color: 4), hang(520, color: 6),
        on(.hat, 250, 110, color: 7), on(.hat, 450, 110, color: 4),
        on(.shoe, 220, 480, color: 7), on(.shoe, 306, 480, color: 7), on(.shoe, 450, 480, color: 3), on(.shoe, 536, 480, color: 3),
    ])

    // MARK: Sock drawer, seen from above (cells centered x 200, 320, 440, 560; y 100, 240, 380)

    static let socks1 = TidyLevel(id: "socks1", scene: .socks, slots:
        [7, 5, 3].enumerated().flatMap { i, c in
            [at(.sock, 260 + CGFloat(i) * 120, 170, color: c, strict: true), at(.sock, 260 + CGFloat(i) * 120, 310, color: c, strict: true)]
        }
    )

    static let socks2 = TidyLevel(id: "socks2", scene: .socks, slots:
        [0, 2, 5, 6].enumerated().flatMap { i, c in
            [100, 240, 380].map { y in at(.sock, 200 + CGFloat(i) * 120, CGFloat(y), color: c, strict: true) }
        }
    )

    // MARK: Backpack (inside 210...550, bottom at 440, side pocket at x 615)

    static let backpack1 = TidyLevel(id: "backpack1", scene: .backpack, slots: [
        on(.book, 260, 440, color: 5), on(.book, 296, 440, color: 0),
        on(.lunchbox, 430, 440, stack: 1), on(.apple, 430, 358, stack: 1),
        on(.bottle, 615, 440),
    ])

    static let backpack2 = TidyLevel(id: "backpack2", scene: .backpack, slots: [
        on(.book, 250, 440, color: 5), on(.book, 286, 440, color: 0), on(.book, 322, 440, color: 3),
        on(.lunchbox, 430, 440, color: 7, stack: 1), on(.apple, 410, 358, color: 3, stack: 1), on(.strawberry, 456, 358, stack: 1),
        on(.pencil, 512, 440, color: 2), on(.pencil, 530, 440, color: 6),
        on(.bottle, 615, 440, color: 4),
    ])

    // MARK: Pantry (shelves at 150, 320, 480)

    static let pantry1 = TidyLevel(id: "pantry1", scene: .pantry, slots: [
        on(.jar, 200, 150, color: 7, strict: true), on(.jar, 266, 150, color: 2, strict: true),
        on(.can, 220, 320), on(.can, 280, 320, color: 3),
        on(.cereal, 220, 480), on(.cereal, 320, 480, color: 5),
    ])

    static let pantry2 = TidyLevel(id: "pantry2", scene: .pantry, slots:
        [0, 1, 2, 3, 6].enumerated().map { i, c in on(.jar, 190 + CGFloat(i) * 64, 150, color: c, strict: true) }
        + [on(.can, 200, 320, stack: 1), on(.can, 256, 320, color: 3, stack: 1), on(.can, 312, 320, color: 1, stack: 1),
           on(.can, 228, 254, color: 5, stack: 1), on(.can, 284, 254, color: 7, stack: 1),
           on(.cereal, 200, 480), on(.cereal, 292, 480, color: 0), on(.cereal, 384, 480, color: 6)]
    )

    // MARK: Fruit crate, seen from above (cells: apples top-left, oranges top-right, berries bottom-left, other bottom-right)

    static let crate1 = TidyLevel(id: "crate1", scene: .crate, slots: [
        at(.apple, 235, 145), at(.apple, 300, 145),
        at(.orange, 465, 145), at(.orange, 530, 145),
        at(.strawberry, 240, 355), at(.strawberry, 295, 355),
    ])

    static let crate2 = TidyLevel(id: "crate2", scene: .crate, slots: [
        at(.apple, 215, 115), at(.apple, 275, 115), at(.apple, 245, 180, color: 3),
        at(.orange, 445, 115), at(.orange, 505, 115), at(.orange, 475, 180),
        at(.strawberry, 220, 320), at(.strawberry, 270, 320), at(.strawberry, 220, 380), at(.strawberry, 270, 380),
        at(.banana, 495, 320, rot: -0.15), at(.banana, 495, 385, rot: 0.1),
    ])
}
