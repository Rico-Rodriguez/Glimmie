import SwiftUI

// MARK: - 6 Cozy Unpacking Room Specs

enum UnpackingRooms {
    static let all: [UnpackingRoomSpec] = [
        bedroom,
        artNook,
        koreanKitchen,
        fairyPlayroom,
        livingRoom,
        starlightBalcony,
    ]

    static func spec(for id: UnpackingRoomID) -> UnpackingRoomSpec {
        all.first { $0.id == id } ?? bedroom
    }

    // MARK: 1. Storybook Bedroom (3 boxes, 12 items)

    static let bedroom = UnpackingRoomSpec(
        id: .bedroom,
        floorY: 748,
        surfaces: [
            SurfaceZone(id: "bed-wall-left", kind: .wall, rect: CGRect(x: 46, y: 138, width: 174, height: 215), restY: 353),
            SurfaceZone(id: "bed-wall-right", kind: .wall, rect: CGRect(x: 500, y: 118, width: 460, height: 152), restY: 270),
            SurfaceZone(id: "bed-windowsill", kind: .shelf, rect: CGRect(x: 234, y: 312, width: 232, height: 54), restY: 364),
            SurfaceZone(id: "bed-shelf", kind: .shelf, rect: CGRect(x: 520, y: 260, width: 415, height: 52), restY: 308),
            SurfaceZone(id: "bed-bed", kind: .bed, rect: CGRect(x: 68, y: 452, width: 405, height: 86), restY: 532),
            SurfaceZone(id: "bed-desk", kind: .desk, rect: CGRect(x: 518, y: 418, width: 434, height: 74), restY: 486),
            SurfaceZone(id: "bed-floor", kind: .floor, rect: CGRect(x: 76, y: 622, width: 872, height: 134), restY: 748),
        ],
        boxes: [
            UnpackingBoxSpec(
                id: "bed-box-1",
                rect: CGRect(x: 112, y: 638, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "bed-0", kind: .plushBunny, color: 7),
                    UnpackingItemSpec(id: "bed-1", kind: .diaryBook, color: 6),
                    UnpackingItemSpec(id: "bed-2", kind: .alarmClock, color: 10),
                    UnpackingItemSpec(id: "bed-3", kind: .slippers, color: 7),
                ]
            ),
            UnpackingBoxSpec(
                id: "bed-box-2",
                rect: CGRect(x: 448, y: 642, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "bed-4", kind: .deskLamp, color: 2),
                    UnpackingItemSpec(id: "bed-5", kind: .hanbokDoll, color: 7),
                    UnpackingItemSpec(id: "bed-6", kind: .jewelCompact, color: 7),
                    UnpackingItemSpec(id: "bed-7", kind: .book, color: 5),
                ]
            ),
            UnpackingBoxSpec(
                id: "bed-box-3",
                rect: CGRect(x: 780, y: 638, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "bed-8", kind: .fairyLights, color: 2),
                    UnpackingItemSpec(id: "bed-9", kind: .familyPhoto, color: 1),
                    UnpackingItemSpec(id: "bed-10", kind: .succulentPot, color: 1),
                    UnpackingItemSpec(id: "bed-11", kind: .book, color: 7),
                ]
            ),
        ]
    )

    // MARK: 2. Sunny Art Nook (3 boxes, 12 items)

    static let artNook = UnpackingRoomSpec(
        id: .artNook,
        floorY: 748,
        surfaces: [
            SurfaceZone(id: "art-pinboard", kind: .wall, rect: CGRect(x: 106, y: 142, width: 402, height: 196), restY: 338),
            SurfaceZone(id: "art-wall-right", kind: .wall, rect: CGRect(x: 560, y: 118, width: 392, height: 138), restY: 256),
            SurfaceZone(id: "art-shelf-1", kind: .shelf, rect: CGRect(x: 564, y: 248, width: 382, height: 54), restY: 298),
            SurfaceZone(id: "art-shelf-2", kind: .shelf, rect: CGRect(x: 564, y: 354, width: 382, height: 54), restY: 404),
            SurfaceZone(id: "art-desk", kind: .desk, rect: CGRect(x: 84, y: 416, width: 452, height: 78), restY: 488),
            SurfaceZone(id: "art-bench", kind: .bed, rect: CGRect(x: 582, y: 482, width: 354, height: 68), restY: 544),
            SurfaceZone(id: "art-floor", kind: .floor, rect: CGRect(x: 76, y: 622, width: 872, height: 134), restY: 748),
        ],
        boxes: [
            UnpackingBoxSpec(
                id: "art-box-1",
                rect: CGRect(x: 118, y: 638, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "art-0", kind: .artPoster, color: 0),
                    UnpackingItemSpec(id: "art-1", kind: .crayon, color: 0),
                    UnpackingItemSpec(id: "art-2", kind: .crayon, color: 5),
                    UnpackingItemSpec(id: "art-3", kind: .deskLamp, color: 4),
                ]
            ),
            UnpackingBoxSpec(
                id: "art-box-2",
                rect: CGRect(x: 450, y: 642, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "art-4", kind: .artPoster, color: 2),
                    UnpackingItemSpec(id: "art-5", kind: .flowerVase, color: 10),
                    UnpackingItemSpec(id: "art-6", kind: .mug, color: 2),
                    UnpackingItemSpec(id: "art-7", kind: .book, color: 6),
                ]
            ),
            UnpackingBoxSpec(
                id: "art-box-3",
                rect: CGRect(x: 782, y: 638, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "art-8", kind: .plushCat, color: 7),
                    UnpackingItemSpec(id: "art-9", kind: .piggyBank, color: 7),
                    UnpackingItemSpec(id: "art-10", kind: .musicBox, color: 6),
                    UnpackingItemSpec(id: "art-11", kind: .plant, color: 3),
                ]
            ),
        ]
    )

    // MARK: 3. Warm Korean Kitchen (3 boxes, 13 items)

    static let koreanKitchen = UnpackingRoomSpec(
        id: .koreanKitchen,
        floorY: 748,
        surfaces: [
            SurfaceZone(id: "kit-fridge-door", kind: .wall, rect: CGRect(x: 72, y: 184, width: 166, height: 224), restY: 408),
            SurfaceZone(id: "kit-wall", kind: .wall, rect: CGRect(x: 292, y: 116, width: 656, height: 128), restY: 244),
            SurfaceZone(id: "kit-shelf", kind: .shelf, rect: CGRect(x: 294, y: 236, width: 648, height: 54), restY: 286),
            SurfaceZone(id: "kit-counter", kind: .desk, rect: CGRect(x: 282, y: 382, width: 454, height: 76), restY: 452),
            SurfaceZone(id: "kit-banquette", kind: .bed, rect: CGRect(x: 758, y: 472, width: 210, height: 74), restY: 540),
            SurfaceZone(id: "kit-floor", kind: .floor, rect: CGRect(x: 76, y: 622, width: 872, height: 134), restY: 748),
        ],
        boxes: [
            UnpackingBoxSpec(
                id: "kit-box-1",
                rect: CGRect(x: 116, y: 638, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "kit-0", kind: .riceCooker, color: 7),
                    UnpackingItemSpec(id: "kit-1", kind: .kettle, color: 10),
                    UnpackingItemSpec(id: "kit-2", kind: .teapot, color: 7),
                    UnpackingItemSpec(id: "kit-3", kind: .mug, color: 4),
                    UnpackingItemSpec(id: "kit-4", kind: .familyPhoto, color: 2),
                ]
            ),
            UnpackingBoxSpec(
                id: "kit-box-2",
                rect: CGRect(x: 452, y: 642, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "kit-5", kind: .plate, color: 5),
                    UnpackingItemSpec(id: "kit-6", kind: .plate, color: 7),
                    UnpackingItemSpec(id: "kit-7", kind: .bowl, color: 10),
                    UnpackingItemSpec(id: "kit-8", kind: .mug, color: 7),
                ]
            ),
            UnpackingBoxSpec(
                id: "kit-box-3",
                rect: CGRect(x: 778, y: 638, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "kit-9", kind: .jar, color: 2),
                    UnpackingItemSpec(id: "kit-10", kind: .jam, color: 0),
                    UnpackingItemSpec(id: "kit-11", kind: .lunchbox, color: 4),
                    UnpackingItemSpec(id: "kit-12", kind: .flowerVase, color: 2),
                ]
            ),
        ]
    )

    // MARK: 4. Whimsical Fairy Playroom (3 boxes, 14 items)

    static let fairyPlayroom = UnpackingRoomSpec(
        id: .fairyPlayroom,
        floorY: 748,
        surfaces: [
            SurfaceZone(id: "play-wall-center", kind: .wall, rect: CGRect(x: 334, y: 122, width: 356, height: 186), restY: 308),
            SurfaceZone(id: "play-shelf-l1", kind: .shelf, rect: CGRect(x: 64, y: 214, width: 234, height: 54), restY: 264),
            SurfaceZone(id: "play-shelf-l2", kind: .shelf, rect: CGRect(x: 64, y: 342, width: 234, height: 54), restY: 392),
            SurfaceZone(id: "play-shelf-r1", kind: .shelf, rect: CGRect(x: 726, y: 214, width: 234, height: 54), restY: 264),
            SurfaceZone(id: "play-shelf-r2", kind: .shelf, rect: CGRect(x: 726, y: 342, width: 234, height: 54), restY: 392),
            SurfaceZone(id: "play-windowseat", kind: .bed, rect: CGRect(x: 326, y: 404, width: 372, height: 76), restY: 474),
            SurfaceZone(id: "play-table", kind: .desk, rect: CGRect(x: 348, y: 528, width: 328, height: 64), restY: 588),
            SurfaceZone(id: "play-floor", kind: .floor, rect: CGRect(x: 76, y: 626, width: 872, height: 130), restY: 748),
        ],
        boxes: [
            UnpackingBoxSpec(
                id: "play-box-1",
                rect: CGRect(x: 108, y: 638, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "play-0", kind: .hanbokDoll, color: 6),
                    UnpackingItemSpec(id: "play-1", kind: .plushBunny, color: 6),
                    UnpackingItemSpec(id: "play-2", kind: .teddy, color: 7),
                    UnpackingItemSpec(id: "play-3", kind: .ball, color: 5),
                    UnpackingItemSpec(id: "play-4", kind: .slippers, color: 6),
                ]
            ),
            UnpackingBoxSpec(
                id: "play-box-2",
                rect: CGRect(x: 450, y: 642, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "play-5", kind: .fairyLights, color: 7),
                    UnpackingItemSpec(id: "play-6", kind: .musicBox, color: 7),
                    UnpackingItemSpec(id: "play-7", kind: .star, color: 2),
                    UnpackingItemSpec(id: "play-8", kind: .block, color: 0),
                    UnpackingItemSpec(id: "play-9", kind: .block, color: 4),
                ]
            ),
            UnpackingBoxSpec(
                id: "play-box-3",
                rect: CGRect(x: 790, y: 638, width: 126, height: 108),
                items: [
                    UnpackingItemSpec(id: "play-10", kind: .artPoster, color: 1),
                    UnpackingItemSpec(id: "play-11", kind: .plushCat, color: 4),
                    UnpackingItemSpec(id: "play-12", kind: .car, color: 0),
                    UnpackingItemSpec(id: "play-13", kind: .hat, color: 2),
                ]
            ),
        ]
    )

    // MARK: 5. Cozy Pastel Living Room (2 boxes, 12 items)

    static let livingRoom = UnpackingRoomSpec(
        id: .livingRoom,
        floorY: 748,
        surfaces: [
            SurfaceZone(id: "liv-wall", kind: .wall, rect: CGRect(x: 100, y: 120, width: 472, height: 196), restY: 316),
            SurfaceZone(id: "liv-sofa", kind: .bed, rect: CGRect(x: 104, y: 396, width: 464, height: 82), restY: 472),
            SurfaceZone(id: "liv-coffee", kind: .desk, rect: CGRect(x: 152, y: 522, width: 368, height: 66), restY: 584),
            SurfaceZone(id: "liv-shelf-1", kind: .shelf, rect: CGRect(x: 642, y: 198, width: 310, height: 54), restY: 248),
            SurfaceZone(id: "liv-shelf-2", kind: .shelf, rect: CGRect(x: 642, y: 332, width: 310, height: 54), restY: 382),
            SurfaceZone(id: "liv-shelf-3", kind: .shelf, rect: CGRect(x: 642, y: 466, width: 310, height: 54), restY: 516),
            SurfaceZone(id: "liv-floor", kind: .floor, rect: CGRect(x: 76, y: 626, width: 872, height: 130), restY: 748),
        ],
        boxes: [
            UnpackingBoxSpec(
                id: "liv-box-1",
                rect: CGRect(x: 204, y: 640, width: 130, height: 108),
                items: [
                    UnpackingItemSpec(id: "liv-0", kind: .familyPhoto, color: 7),
                    UnpackingItemSpec(id: "liv-1", kind: .artPoster, color: 0),
                    UnpackingItemSpec(id: "liv-2", kind: .plushCat, color: 2),
                    UnpackingItemSpec(id: "liv-3", kind: .teapot, color: 4),
                    UnpackingItemSpec(id: "liv-4", kind: .mug, color: 7),
                    UnpackingItemSpec(id: "liv-5", kind: .slippers, color: 4),
                ]
            ),
            UnpackingBoxSpec(
                id: "liv-box-2",
                rect: CGRect(x: 696, y: 640, width: 130, height: 108),
                items: [
                    UnpackingItemSpec(id: "liv-6", kind: .deskLamp, color: 7),
                    UnpackingItemSpec(id: "liv-7", kind: .flowerVase, color: 6),
                    UnpackingItemSpec(id: "liv-8", kind: .succulentPot, color: 10),
                    UnpackingItemSpec(id: "liv-9", kind: .book, color: 4),
                    UnpackingItemSpec(id: "liv-10", kind: .book, color: 1),
                    UnpackingItemSpec(id: "liv-11", kind: .piggyBank, color: 7),
                ]
            ),
        ]
    )

    // MARK: 6. Dreamy Starlight Balcony (2 boxes, 11 items)

    static let starlightBalcony = UnpackingRoomSpec(
        id: .starlightBalcony,
        floorY: 748,
        surfaces: [
            SurfaceZone(id: "bal-wall", kind: .wall, rect: CGRect(x: 245, y: 120, width: 534, height: 138), restY: 258),
            SurfaceZone(id: "bal-shelf-l", kind: .shelf, rect: CGRect(x: 56, y: 236, width: 224, height: 54), restY: 286),
            SurfaceZone(id: "bal-shelf-r", kind: .shelf, rect: CGRect(x: 744, y: 236, width: 224, height: 54), restY: 286),
            SurfaceZone(id: "bal-daybed", kind: .bed, rect: CGRect(x: 76, y: 432, width: 432, height: 86), restY: 512),
            SurfaceZone(id: "bal-bistro", kind: .desk, rect: CGRect(x: 590, y: 432, width: 338, height: 74), restY: 502),
            SurfaceZone(id: "bal-floor", kind: .floor, rect: CGRect(x: 76, y: 622, width: 872, height: 134), restY: 748),
        ],
        boxes: [
            UnpackingBoxSpec(
                id: "bal-box-1",
                rect: CGRect(x: 214, y: 640, width: 130, height: 108),
                items: [
                    UnpackingItemSpec(id: "bal-0", kind: .fairyLights, color: 2),
                    UnpackingItemSpec(id: "bal-1", kind: .plant, color: 3),
                    UnpackingItemSpec(id: "bal-2", kind: .succulentPot, color: 7),
                    UnpackingItemSpec(id: "bal-3", kind: .plushBunny, color: 5),
                    UnpackingItemSpec(id: "bal-4", kind: .diaryBook, color: 7),
                    UnpackingItemSpec(id: "bal-5", kind: .slippers, color: 10),
                ]
            ),
            UnpackingBoxSpec(
                id: "bal-box-2",
                rect: CGRect(x: 688, y: 640, width: 130, height: 108),
                items: [
                    UnpackingItemSpec(id: "bal-6", kind: .flowerVase, color: 5),
                    UnpackingItemSpec(id: "bal-7", kind: .teapot, color: 6),
                    UnpackingItemSpec(id: "bal-8", kind: .mug, color: 2),
                    UnpackingItemSpec(id: "bal-9", kind: .musicBox, color: 4),
                    UnpackingItemSpec(id: "bal-10", kind: .star, color: 2),
                ]
            ),
        ]
    )
}

// MARK: - Storybook Full-Room Vector Art

enum UnpackingRoomArt {
    static func wallColors(for room: UnpackingRoomID) -> (Color, Color) {
        switch room {
        case .bedroom: return (Color(hex: 0xFFF3F8), Color(hex: 0xFDE2EC))
        case .artNook: return (Color(hex: 0xFFF9E6), Color(hex: 0xFFEAC7))
        case .koreanKitchen: return (Color(hex: 0xFFF5EB), Color(hex: 0xFFE3D0))
        case .fairyPlayroom: return (Color(hex: 0xF7EEFF), Color(hex: 0xEAD9FF))
        case .livingRoom: return (Color(hex: 0xF2F9F2), Color(hex: 0xDFEFE4))
        case .starlightBalcony: return (Color(hex: 0xE6E9FF), Color(hex: 0xD2C8F8))
        }
    }

    static func floorColors(for room: UnpackingRoomID) -> (TRGB, TRGB) {
        switch room {
        case .koreanKitchen: return (TRGB(0xE8C49E), TRGB(0xF5DFC4))
        case .starlightBalcony: return (TRGB(0xC9986E), TRGB(0xDFB188))
        default: return (TRGB(0xDFB182), TRGB(0xEFCC9F))
        }
    }

    /// Full-bleed wallpaper & floorboards behind `GameStage`.
    static func backdrop(_ room: UnpackingRoomID, _ ctx: GraphicsContext, size: CGSize, floorLineY: CGFloat) {
        let (top, bot) = wallColors(for: room)
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [top, bot]), startPoint: .zero, endPoint: CGPoint(x: 0, y: floorLineY))
        )
        let (fDark, fLight) = floorColors(for: room)
        ctx.fill(
            Path(CGRect(x: 0, y: floorLineY, width: size.width, height: max(0, size.height - floorLineY))),
            with: .linearGradient(
                Gradient(colors: [fDark.color, fLight.color]),
                startPoint: CGPoint(x: 0, y: floorLineY),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        TidySceneArt.plank(ctx, -4, floorLineY - 12, size.width + 8, 15, TRGB(0xFFFBF5))
    }

    /// Draws the complete `1024 x 834` room interior & furniture.
    static func drawRoom(_ room: UnpackingRoomID, in ctx: GraphicsContext, time: Double = 0, warmGlow: Double = 0) {
        let w: CGFloat = GameChromeLayout.width
        let h: CGFloat = GameChromeLayout.height
        let floorLineY: CGFloat = 556

        // 1. Wall + subtle texture + floor
        backdrop(room, ctx, size: CGSize(width: w, height: h), floorLineY: floorLineY)
        drawWallpaperPattern(room, ctx, width: w, floorLineY: floorLineY)

        // Floorboard planks
        let (fDark, _) = floorColors(for: room)
        for i in 0..<5 {
            let y = floorLineY + 26 + CGFloat(i) * 44
            TPaint.stroke(ctx, [CGPoint(x: 0, y: y), CGPoint(x: w, y: y)], fDark.shade.color(0.28), 2)
        }

        // 2. Room-specific furniture & rug
        switch room {
        case .bedroom: drawBedroomFurniture(ctx)
        case .artNook: drawArtNookFurniture(ctx)
        case .koreanKitchen: drawKoreanKitchenFurniture(ctx)
        case .fairyPlayroom: drawFairyPlayroomFurniture(ctx)
        case .livingRoom: drawLivingRoomFurniture(ctx)
        case .starlightBalcony: drawStarlightBalconyFurniture(ctx, time: time)
        }

        // 3. Soft golden sunset / lamp ambiance when room is completed & lit
        if warmGlow > 0.01 {
            ctx.fill(
                Path(CGRect(x: 0, y: 0, width: w, height: h)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(hex: 0xFFF4C4, alpha: 0.22 * warmGlow),
                        Color(hex: 0xFFE39E, alpha: 0.08 * warmGlow),
                        .clear,
                    ]),
                    center: CGPoint(x: w * 0.5, y: h * 0.42),
                    startRadius: 20,
                    endRadius: 560
                )
            )
        }
    }

    private static func drawWallpaperPattern(_ room: UnpackingRoomID, _ ctx: GraphicsContext, width: CGFloat, floorLineY: CGFloat) {
        switch room {
        case .livingRoom:
            // Soft sage vertical pastel stripes
            var x: CGFloat = 24
            while x < width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 28, height: floorLineY - 12)), with: .color(.white.opacity(0.24)))
                x += 72
            }
        case .koreanKitchen:
            // Warm ceramic tile grid
            for i in 0..<18 {
                let x = CGFloat(i) * 60
                TPaint.stroke(ctx, [CGPoint(x: x, y: 95), CGPoint(x: x, y: floorLineY - 12)], Color(hex: 0xE6C6B2, alpha: 0.35), 1.5)
            }
            for j in 0..<11 {
                let y = 100 + CGFloat(j) * 44
                TPaint.stroke(ctx, [CGPoint(x: 0, y: y), CGPoint(x: width, y: y)], Color(hex: 0xE6C6B2, alpha: 0.35), 1.5)
            }
        case .starlightBalcony:
            // Subtle wood trellis vertical slats on the side walls
            for sx: CGFloat in [20, 74, 128, 896, 950, 1004] {
                ctx.fill(Path(CGRect(x: sx, y: 0, width: 12, height: floorLineY - 12)), with: .color(Color(hex: 0xFFF7EE, alpha: 0.35)))
            }
        default:
            // Soft storybook polka dots / tiny stars
            var row = 0
            var y: CGFloat = 112
            while y < floorLineY - 30 {
                var x: CGFloat = row.isMultiple(of: 2) ? 38 : 82
                while x < width {
                    TPaint.dot(ctx, x, y, 4.2, .white.opacity(0.45))
                    x += 88
                }
                y += 74
                row += 1
            }
        }
    }

    // MARK: Room 1: Storybook Bedroom

    private static func drawBedroomFurniture(_ ctx: GraphicsContext) {
        // Woven blush oval rug
        drawOvalRug(ctx, rect: CGRect(x: 132, y: 656, width: 760, height: 102), fill: TRGB(0xFFDCE9), border: .white)

        // Sunlit arched window + pastel curtains + sill shelf (restY = 364)
        let winRect = CGRect(x: 248, y: 132, width: 204, height: 228)
        let winPath = Path(roundedRect: winRect, cornerRadius: 96)
        ctx.fill(
            winPath,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xB9E4FF), Color(hex: 0xEAF8FF), Color(hex: 0xFFF4D9)]),
                startPoint: CGPoint(x: 350, y: 132), endPoint: CGPoint(x: 350, y: 360)
            )
        )
        // Fluffy cloud outside window
        ctx.fill(Path(ellipseIn: CGRect(x: 286, y: 186, width: 64, height: 28)), with: .color(.white.opacity(0.85)))
        ctx.fill(Path(ellipseIn: CGRect(x: 332, y: 194, width: 52, height: 24)), with: .color(.white.opacity(0.8)))
        // Window muntins & frame
        TPaint.stroke(ctx, [CGPoint(x: 350, y: 134), CGPoint(x: 350, y: 360)], Color(hex: 0xFFFBF5), 6)
        TPaint.stroke(ctx, [CGPoint(x: 250, y: 256), CGPoint(x: 450, y: 256)], Color(hex: 0xFFFBF5), 6)
        ctx.stroke(winPath, with: .color(Color(hex: 0xFFFBF5)), lineWidth: 10)
        ctx.stroke(winPath, with: .color(Color(hex: 0xD8BFA8)), lineWidth: 2.5)
        // Window sill plank (restY = 364)
        TidySceneArt.shelfShadow(ctx, 234, 376, 232)
        TidySceneArt.plank(ctx, 230, 364, 240, 16, TRGB(0xFFF6EC))

        // Floating wall shelf on right (restY = 308)
        TidySceneArt.shelfShadow(ctx, 520, 322, 415)
        for bx: CGFloat in [562, 882] {
            ctx.fill(Path(roundedRect: CGRect(x: bx, y: 320, width: 12, height: 26), cornerRadius: 4), with: .color(Color(hex: 0xC9905C)))
        }
        TidySceneArt.plank(ctx, 514, 308, 426, 16, TidySceneArt.wood)

        // Cozy quilted bed on left (restY = 532)
        let headboard = Path(roundedRect: CGRect(x: 62, y: 398, width: 416, height: 152), cornerRadius: 28)
        TPaint.body(ctx, headboard, TRGB(0xE8B98A), headboard.boundingRect, line: 3)
        let hbInner = Path(roundedRect: CGRect(x: 80, y: 416, width: 380, height: 106), cornerRadius: 20)
        ctx.fill(hbInner, with: .color(Color(hex: 0xFFF3F8)))
        ctx.stroke(hbInner, with: .color(Color(hex: 0xDFB5C6)), lineWidth: 2)
        // Two fluffy pillows
        for px: CGFloat in [104, 286] {
            let pil = Path(roundedRect: CGRect(x: px, y: 454, width: 150, height: 68), cornerRadius: 24)
            TPaint.body(ctx, pil, TRGB(0xFFFDFB), pil.boundingRect, line: 2.2)
            ctx.stroke(Path(roundedRect: CGRect(x: px + 10, y: 462, width: 130, height: 52), cornerRadius: 18), with: .color(Theme.blush), lineWidth: 1.8)
        }
        // Quilted mattress & scalloped blush bedspread
        let bedBase = Path(roundedRect: CGRect(x: 56, y: 522, width: 428, height: 92), cornerRadius: 22)
        TPaint.body(ctx, bedBase, TRGB(0xFFB8D4), bedBase.boundingRect, line: 2.8)
        let fold = Path(roundedRect: CGRect(x: 56, y: 518, width: 428, height: 28), cornerRadius: 14)
        TPaint.body(ctx, fold, TRGB(0xFFF8F2), fold.boundingRect, line: 2.2)
        // Bed legs
        for lx: CGFloat in [84, 440] {
            TidySceneArt.plank(ctx, lx, 610, 18, 22, TidySceneArt.darkWood)
        }

        // Study desk on right (restY = 486)
        drawStudyDesk(ctx, x: 516, topY: 486, width: 438, height: 128, wood: TidySceneArt.wood, drawerTint: TRGB(0xFFF4EA))
    }

    // MARK: Room 2: Sunny Art Nook

    private static func drawArtNookFurniture(_ ctx: GraphicsContext) {
        drawOvalRug(ctx, rect: CGRect(x: 118, y: 656, width: 788, height: 102), fill: TRGB(0xFFE7B8), border: Color(hex: 0xFF9EC2))

        // Large wooden-framed cork pinboard (wall zone)
        let boardOuter = CGRect(x: 96, y: 132, width: 422, height: 216)
        TidySceneArt.box(ctx, boardOuter, TidySceneArt.wood, radius: 14)
        let cork = boardOuter.insetBy(dx: 12, dy: 12)
        ctx.fill(Path(roundedRect: cork, cornerRadius: 8), with: .color(Color(hex: 0xE7C091)))
        // Subtle cork speckles
        for i in 0..<24 {
            let cx = cork.minX + 18 + CGFloat((i * 53) % Int(cork.width - 36))
            let cy = cork.minY + 14 + CGFloat((i * 37) % Int(cork.height - 28))
            TPaint.dot(ctx, cx, cy, 2, Color(hex: 0xC6955E, alpha: 0.45))
        }
        // Colorful pennant bunting across top
        let flagHex: [UInt32] = [0xFF8FB8, 0xFFE38A, 0x9FE3CF, 0x9CCBFF, 0xC9B6FF]
        for i in 0..<10 {
            let fx = 556 + CGFloat(i) * 40
            let tri = TPaint.poly([CGPoint(x: fx, y: 108), CGPoint(x: fx + 32, y: 108), CGPoint(x: fx + 16, y: 136)])
            ctx.fill(tri, with: .color(Color(hex: flagHex[i % flagHex.count])))
            ctx.stroke(tri, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
        }

        // Two floating craft shelves on right (restY = 298, 404)
        for sy: CGFloat in [298, 404] {
            TidySceneArt.shelfShadow(ctx, 564, sy + 14, 382)
            TidySceneArt.plank(ctx, 558, sy, 394, 16, TRGB(0xFFFDF8))
        }

        // Wide craft desk on left (restY = 488)
        drawStudyDesk(ctx, x: 80, topY: 488, width: 460, height: 126, wood: TRGB(0xE8BE8B), drawerTint: TRGB(0xFFF7E2))

        // Cushioned studio reading bench on right (restY = 544)
        let benchBody = Path(roundedRect: CGRect(x: 580, y: 544, width: 358, height: 68), cornerRadius: 14)
        TPaint.body(ctx, benchBody, TRGB(0xFFF8EE), benchBody.boundingRect, line: 2.6)
        let cushion = Path(roundedRect: CGRect(x: 576, y: 530, width: 366, height: 28), cornerRadius: 14)
        TPaint.body(ctx, cushion, TRGB(0xA8E3D0), cushion.boundingRect, line: 2.4)
        for bx: CGFloat in [606, 898] {
            TidySceneArt.plank(ctx, bx, 608, 16, 18, TidySceneArt.wood)
        }
    }

    // MARK: Room 3: Warm Korean Home Kitchen

    private static func drawKoreanKitchenFurniture(_ ctx: GraphicsContext) {
        // Warm woven kitchen runner rug
        let runner = CGRect(x: 130, y: 660, width: 764, height: 94)
        ctx.fill(Path(roundedRect: runner, cornerRadius: 24), with: .color(Color(hex: 0xFFE3C8)))
        ctx.stroke(Path(roundedRect: runner.insetBy(dx: 10, dy: 8), cornerRadius: 18), with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 3, dash: [10, 8]))

        // Retro pastel mint refrigerator on left (magnetic door = wall zone)
        let fridgeRect = CGRect(x: 56, y: 166, width: 198, height: 422)
        let fridge = Path(roundedRect: fridgeRect, cornerRadius: 28)
        TPaint.body(ctx, fridge, TRGB(0xAEE6D5), fridgeRect, line: 3)
        // Freezer divider & chrome handles
        TPaint.stroke(ctx, [CGPoint(x: 62, y: 424), CGPoint(x: 248, y: 424)], Color(hex: 0x72AE9D), 3)
        let handleTop = Path(roundedRect: CGRect(x: 230, y: 266, width: 11, height: 76), cornerRadius: 5.5)
        let handleBot = Path(roundedRect: CGRect(x: 230, y: 454, width: 11, height: 58), cornerRadius: 5.5)
        TPaint.metal(ctx, handleTop, handleTop.boundingRect)
        TPaint.metal(ctx, handleBot, handleBot.boundingRect)
        TPaint.gloss(ctx, CGRect(x: 72, y: 186, width: 14, height: 90), 0.35)

        // Open oak dish shelf across upper wall (restY = 286)
        TidySceneArt.shelfShadow(ctx, 294, 300, 648)
        for bx: CGFloat in [342, 608, 876] {
            ctx.fill(Path(roundedRect: CGRect(x: bx, y: 298, width: 12, height: 24), cornerRadius: 4), with: .color(Color(hex: 0xC68D58)))
        }
        TidySceneArt.plank(ctx, 288, 286, 660, 16, TidySceneArt.wood)

        // Kitchen cabinetry & butcher-block counter (restY = 452)
        let cabRect = CGRect(x: 284, y: 456, width: 450, height: 146)
        TidySceneArt.box(ctx, cabRect, TRGB(0xFFF6EB), radius: 10)
        for i in 0..<3 {
            let dx = 298 + CGFloat(i) * 144
            let door = Path(roundedRect: CGRect(x: dx, y: 474, width: 132, height: 112), cornerRadius: 8)
            ctx.fill(door, with: .color(Color(hex: 0xFFE9D8)))
            ctx.stroke(door, with: .color(Color(hex: 0xD8B49A)), lineWidth: 2)
            TPaint.dot(ctx, dx + 66, 496, 4.5, Color(hex: 0xDDA36B))
        }
        TidySceneArt.plank(ctx, 276, 452, 466, 18, TRGB(0xDFAA72))

        // Cozy padded breakfast banquette on right (restY = 540)
        let back = Path(roundedRect: CGRect(x: 760, y: 434, width: 206, height: 116), cornerRadius: 20)
        TPaint.body(ctx, back, TRGB(0xFFE0B8), back.boundingRect, line: 2.5)
        let seat = Path(roundedRect: CGRect(x: 754, y: 526, width: 218, height: 30), cornerRadius: 14)
        TPaint.body(ctx, seat, TRGB(0xFFA8C6), seat.boundingRect, line: 2.4)
        let base = Path(roundedRect: CGRect(x: 764, y: 554, width: 198, height: 50), cornerRadius: 10)
        TPaint.body(ctx, base, TRGB(0xFFF4E6), base.boundingRect, line: 2.2)
    }

    // MARK: Room 4: Whimsical Fairy Playroom

    private static func drawFairyPlayroomFurniture(_ ctx: GraphicsContext) {
        drawOvalRug(ctx, rect: CGRect(x: 114, y: 658, width: 796, height: 100), fill: TRGB(0xDFD0FF), border: Theme.lemon)

        // Pastel bunting garland across upper center wall
        var cord = Path()
        cord.move(to: CGPoint(x: 320, y: 114))
        cord.addQuadCurve(to: CGPoint(x: 704, y: 114), control: CGPoint(x: 512, y: 152))
        ctx.stroke(cord, with: .color(Color(hex: 0xD2A9E8)), lineWidth: 2.5)
        let cols: [UInt32] = [0xFF9AC2, 0xFFE38A, 0x9FE3CF, 0x9CCBFF, 0xFFB88A]
        for i in 0..<7 {
            let t = CGFloat(i + 1) / 8
            let fx = 320 + t * 384
            let fy: CGFloat = 114 + CGFloat(sin(Double(t) * .pi)) * 20
            let flag = TPaint.poly([CGPoint(x: fx - 14, y: fy), CGPoint(x: fx + 14, y: fy), CGPoint(x: fx, y: fy + 24)])
            ctx.fill(flag, with: .color(Color(hex: cols[i % cols.count])))
        }

        // Twin white cubby bookcases (left & right; shelves at restY = 264, 392)
        for bx: CGFloat in [56, 718] {
            let unit = CGRect(x: bx, y: 150, width: 250, height: 422)
            TidySceneArt.box(ctx, unit, TRGB(0xFFFDFB), radius: 14)
            TidySceneArt.inside(ctx, unit.insetBy(dx: 14, dy: 14), TRGB(0xF6EAFF), radius: 8)
            for sy: CGFloat in [264, 392, 540] {
                TidySceneArt.shelfShadow(ctx, bx + 14, sy + 14, 222)
                TidySceneArt.plank(ctx, bx + 8, sy, 234, 15, TRGB(0xFFFDFB))
            }
        }

        // Cushioned scalloped window seat in center (restY = 474)
        let seatBase = Path(roundedRect: CGRect(x: 326, y: 476, width: 372, height: 96), cornerRadius: 14)
        TPaint.body(ctx, seatBase, TRGB(0xFFF7F2), seatBase.boundingRect, line: 2.5)
        let cushion = Path(roundedRect: CGRect(x: 322, y: 460, width: 380, height: 30), cornerRadius: 15)
        TPaint.body(ctx, cushion, TRGB(0xFFB5D2), cushion.boundingRect, line: 2.4)

        // Low round cloud play-table in front (restY = 588)
        for lx: CGFloat in [386, 616] {
            TidySceneArt.plank(ctx, lx, 594, 16, 46, TidySceneArt.wood)
        }
        let tableTop = Path(roundedRect: CGRect(x: 342, y: 582, width: 340, height: 22), cornerRadius: 11)
        TPaint.body(ctx, tableTop, TRGB(0xFFFDF9), tableTop.boundingRect, line: 2.5)
    }

    // MARK: Room 5: Cozy Pastel Living Room

    private static func drawLivingRoomFurniture(_ ctx: GraphicsContext) {
        drawOvalRug(ctx, rect: CGRect(x: 108, y: 658, width: 808, height: 100), fill: TRGB(0xF7DFC4), border: Color(hex: 0x9AD1A8))

        // Plush cream-peach living room sofa (restY = 472)
        let sofaBack = Path(roundedRect: CGRect(x: 92, y: 344, width: 488, height: 152), cornerRadius: 34)
        TPaint.body(ctx, sofaBack, TRGB(0xFFD5BE), sofaBack.boundingRect, line: 2.8)
        for ax: CGFloat in [84, 540] {
            let arm = Path(roundedRect: CGRect(x: ax, y: 410, width: 48, height: 116), cornerRadius: 22)
            TPaint.body(ctx, arm, TRGB(0xFFC5A8), arm.boundingRect, line: 2.5)
        }
        let sofaSeat = Path(roundedRect: CGRect(x: 116, y: 458, width: 440, height: 64), cornerRadius: 20)
        TPaint.body(ctx, sofaSeat, TRGB(0xFFE4D3), sofaSeat.boundingRect, line: 2.4)
        TPaint.stroke(ctx, [CGPoint(x: 336, y: 462), CGPoint(x: 336, y: 518)], Color(hex: 0xD9A489), 2)
        for lx: CGFloat in [114, 536] {
            TidySceneArt.plank(ctx, lx, 520, 16, 26, TidySceneArt.darkWood)
        }

        // Mid-century wooden coffee table (restY = 584)
        for lx: CGFloat in [190, 466] {
            TidySceneArt.plank(ctx, lx, 594, 16, 52, TidySceneArt.darkWood)
        }
        let coffeeTop = Path(roundedRect: CGRect(x: 146, y: 580, width: 380, height: 22), cornerRadius: 11)
        TPaint.body(ctx, coffeeTop, TidySceneArt.wood, coffeeTop.boundingRect, line: 2.6)

        // Warm wooden bookcase on right (restY = 248, 382, 516)
        let caseRect = CGRect(x: 632, y: 126, width: 330, height: 476)
        TidySceneArt.box(ctx, caseRect, TidySceneArt.wood, radius: 14)
        TidySceneArt.inside(ctx, caseRect.insetBy(dx: 16, dy: 16), TRGB(0xF9EDE0), radius: 8)
        for sy: CGFloat in [248, 382, 516] {
            TidySceneArt.shelfShadow(ctx, 648, sy + 14, 298)
            TidySceneArt.plank(ctx, 640, sy, 314, 16, TidySceneArt.wood)
        }
    }

    // MARK: Room 6: Dreamy Starlight Balcony

    private static func drawStarlightBalconyFurniture(_ ctx: GraphicsContext, time: Double) {
        // Big arched twilight starry sky window pane in center
        let skyRect = CGRect(x: 184, y: 108, width: 656, height: 392)
        let skyPath = Path(roundedRect: skyRect, cornerRadius: 48)
        ctx.fill(
            skyPath,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x5B5194), Color(hex: 0x897DC9), Color(hex: 0xC9B4F2), Color(hex: 0xFAD7E8)]),
                startPoint: CGPoint(x: 512, y: 108),
                endPoint: CGPoint(x: 512, y: 500)
            )
        )
        // Crescent moon & twinkling night stars
        var moonCtx = ctx
        moonCtx.clip(to: skyPath)
        moonCtx.fill(Path(ellipseIn: CGRect(x: 684, y: 146, width: 64, height: 64)), with: .color(Color(hex: 0xFFF0A6)))
        moonCtx.fill(Path(ellipseIn: CGRect(x: 702, y: 138, width: 58, height: 58)), with: .color(Color(hex: 0x6A5FA6)))
        let starPts: [(CGFloat, CGFloat, CGFloat)] = [
            (256, 172, 6), (344, 148, 8), (438, 192, 5.5), (534, 154, 7.5),
            (612, 206, 6), (766, 224, 7), (304, 248, 5), (492, 242, 6.5),
        ]
        for (idx, (sx, sy, sr)) in starPts.enumerated() {
            let alpha = 0.6 + 0.4 * sin(time * 2.5 + Double(idx) * 1.1)
            StorybookArt.sparkle(moonCtx, at: CGPoint(x: sx, y: sy), radius: sr, color: Color(hex: 0xFFF8D6), opacity: alpha)
        }
        // White greenhouse muntin bars
        TPaint.stroke(ctx, [CGPoint(x: 404, y: 112), CGPoint(x: 404, y: 496)], Color(hex: 0xFFF9F4, alpha: 0.78), 7)
        TPaint.stroke(ctx, [CGPoint(x: 620, y: 112), CGPoint(x: 620, y: 496)], Color(hex: 0xFFF9F4, alpha: 0.78), 7)
        TPaint.stroke(ctx, [CGPoint(x: 188, y: 274), CGPoint(x: 836, y: 274)], Color(hex: 0xFFF9F4, alpha: 0.78), 7)
        ctx.stroke(skyPath, with: .color(Color(hex: 0xFFF9F4)), lineWidth: 11)
        ctx.stroke(skyPath, with: .color(Color(hex: 0xB8A6D4)), lineWidth: 2.5)

        // Moonlit woven balcony rug
        drawOvalRug(ctx, rect: CGRect(x: 120, y: 656, width: 784, height: 100), fill: TRGB(0xDCE6FF), border: Theme.lemon)

        // Left & right hanging botanical wall shelves (restY = 286)
        for sx: CGFloat in [52, 740] {
            TidySceneArt.shelfShadow(ctx, sx + 4, 300, 224)
            TidySceneArt.plank(ctx, sx, 286, 232, 16, TidySceneArt.wood)
        }

        // Cushioned wooden sunroom daybed on left (restY = 512)
        let frame = Path(roundedRect: CGRect(x: 68, y: 438, width: 448, height: 158), cornerRadius: 22)
        TPaint.body(ctx, frame, TidySceneArt.wood, frame.boundingRect, line: 2.8)
        let mattress = Path(roundedRect: CGRect(x: 78, y: 496, width: 428, height: 42), cornerRadius: 16)
        TPaint.body(ctx, mattress, TRGB(0xFFF6F2), mattress.boundingRect, line: 2.3)
        let throwBlanket = Path(roundedRect: CGRect(x: 78, y: 520, width: 428, height: 50), cornerRadius: 16)
        TPaint.body(ctx, throwBlanket, TRGB(0xB8D2FF), throwBlanket.boundingRect, line: 2.2)

        // Pastel bistro table on right (restY = 502)
        let stem = Path(roundedRect: CGRect(x: 749, y: 514, width: 20, height: 96), cornerRadius: 6)
        TPaint.body(ctx, stem, TRGB(0xFFF7F0), stem.boundingRect, line: 2.2)
        let foot = Path(ellipseIn: CGRect(x: 688, y: 598, width: 142, height: 22))
        TPaint.body(ctx, foot, TRGB(0xFFF7F0), foot.boundingRect, line: 2.2)
        let top = Path(roundedRect: CGRect(x: 586, y: 498, width: 346, height: 22), cornerRadius: 11)
        TPaint.body(ctx, top, TRGB(0xFFF9F4), top.boundingRect, line: 2.5)
    }

    // MARK: Shared Furniture Helpers

    private static func drawOvalRug(_ ctx: GraphicsContext, rect: CGRect, fill: TRGB, border: Color) {
        ctx.fill(Path(ellipseIn: rect), with: .color(fill.color(0.9)))
        ctx.stroke(Path(ellipseIn: rect), with: .color(fill.line.color(0.45)), lineWidth: 2.5)
        ctx.stroke(
            Path(ellipseIn: rect.insetBy(dx: 16, dy: 9)),
            with: .color(border.opacity(0.85)),
            style: StrokeStyle(lineWidth: 3.2, dash: [11, 8])
        )
    }

    private static func drawStudyDesk(_ ctx: GraphicsContext, x: CGFloat, topY: CGFloat, width: CGFloat, height: CGFloat, wood: TRGB, drawerTint: TRGB) {
        // Left & right legs + drawer pedestal on right
        TidySceneArt.plank(ctx, x + 16, topY + 14, 18, height - 14, wood.shade)
        let pedestal = CGRect(x: x + width - 148, y: topY + 14, width: 132, height: height - 14)
        TidySceneArt.box(ctx, pedestal, wood, radius: 10)
        for row in 0..<2 {
            let dr = CGRect(x: pedestal.minX + 12, y: pedestal.minY + 14 + CGFloat(row) * 48, width: pedestal.width - 24, height: 38)
            ctx.fill(Path(roundedRect: dr, cornerRadius: 7), with: .color(drawerTint.color))
            ctx.stroke(Path(roundedRect: dr, cornerRadius: 7), with: .color(wood.line.color(0.6)), lineWidth: 1.8)
            TPaint.dot(ctx, dr.midX, dr.midY, 4.5, Color(hex: 0xFFE074))
        }
        TidySceneArt.shelfShadow(ctx, x + 6, topY + 16, width - 12)
        TidySceneArt.plank(ctx, x, topY, width, 18, wood)
    }

    /// Draws an Unpacking cardboard box: taped shut (`open == 0`), peeling tape + springing flaps (`0 -> 1`), or folding flat (`collapse > 0`).
    static func drawMovingBox(
        _ ctx: GraphicsContext,
        rect: CGRect,
        open: CGFloat,
        tapePeel: CGFloat,
        remainingCount: Int,
        kick: CGFloat,
        collapse: CGFloat,
        highlightPulse: Double
    ) {
        guard collapse < 0.99 else { return }
        let shrink = max(0.01, 1 - collapse)
        var g = ctx
        g.opacity = Double(max(0, 1 - collapse * 1.15))
        g.translateBy(x: rect.midX, y: rect.maxY)
        g.scaleBy(x: (1 + 0.06 * kick) * shrink, y: (1 - 0.09 * kick) * shrink)
        g.translateBy(x: -rect.midX, y: -rect.maxY)

        if highlightPulse > 0.05 && collapse < 0.05 {
            let glowRect = rect.insetBy(dx: -8, dy: -8)
            g.stroke(
                Path(roundedRect: glowRect, cornerRadius: 14),
                with: .color(Color(hex: 0xFFE38A, alpha: 0.72 * highlightPulse)),
                lineWidth: 6
            )
        }

        // Reuse `TidySceneArt.movingBox` for authentic Glimmie cardboard look
        TidySceneArt.movingBox(g, rect, open: open)

        // When taped closed (`tapePeel < 1`), show crisp horizontal cream packing tape sealing the top seam!
        if tapePeel < 0.98 {
            let tapeAlpha = Double(max(0, 1 - tapePeel))
            let peelLift = tapePeel * 28
            var tCtx = g
            tCtx.opacity *= tapeAlpha
            tCtx.translateBy(x: rect.midX, y: rect.minY - peelLift)
            tCtx.rotate(by: .radians(Double(tapePeel) * 0.35))
            let strip = Path(roundedRect: CGRect(x: -rect.width * 0.48, y: -6, width: rect.width * 0.96, height: 13), cornerRadius: 3)
            tCtx.fill(strip, with: .color(Color(hex: 0xF5DFB5)))
            tCtx.stroke(strip, with: .color(Color(hex: 0xC99E65)), lineWidth: 1.8)
        }

        // Cute pictorial pip dots on box front showing items left inside (zero numbers/words!)
        if remainingCount > 0 && collapse < 0.05 {
            let dots = min(remainingCount, 6)
            let spacing: CGFloat = 13
            let startX = rect.midX - CGFloat(dots - 1) * spacing * 0.5
            let dotY = rect.maxY - 14
            for i in 0..<dots {
                let cx = startX + CGFloat(i) * spacing
                g.fill(Path(ellipseIn: CGRect(x: cx - 4.2, y: dotY - 4.2, width: 8.4, height: 8.4)), with: .color(.white.opacity(0.92)))
                g.fill(Path(ellipseIn: CGRect(x: cx - 2.6, y: dotY - 2.6, width: 5.2, height: 5.2)), with: .color(Theme.pink))
            }
        }
    }
}
