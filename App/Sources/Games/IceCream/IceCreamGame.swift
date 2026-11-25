import SwiftUI

// Standalone Ice Cream & Bingsu Parlor: scoop cabinet, soft-serve levers, smoothie blender, and Korean bingsu shaver.

enum IceCreamGame {
    static let entry = GameEntry(
        id: IceSim.gameID,
        title: "Ice Cream",
        tint: Color(hex: 0x9BE7E0),
        icon: { AnyView(IceCreamTileIcon()) },
        play: { exit in AnyView(IceCreamView(exit: exit)) },
        stickers: IceCreamFind.stickers
    )
}

struct IceCreamTileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 240
            var g = ctx
            g.translateBy(x: (size.width - 240 * s) / 2, y: (size.height - 240 * s) / 2)
            g.scaleBy(x: s, y: s)

            // Soft sunlit parlor glow behind the treats
            g.fill(
                Path(ellipseIn: CGRect(x: 22, y: 26, width: 196, height: 186)),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.68), .white.opacity(0)]),
                    center: CGPoint(x: 120, y: 120),
                    startRadius: 10,
                    endRadius: 98
                )
            )

            // Right: Shaved-snow Korean bingsu bowl with strawberry, cherry & pastel spoon
            var spoon = Path()
            spoon.move(to: CGPoint(x: 174, y: 126))
            spoon.addLine(to: CGPoint(x: 212, y: 58))
            g.stroke(spoon, with: .color(StorybookArt.outline(for: 0xFF9EC4)), style: StrokeStyle(lineWidth: 16, lineCap: .round))
            g.stroke(spoon, with: .color(StorybookArt.color(0xFFD0E3)), style: StrokeStyle(lineWidth: 9.5, lineCap: .round))

            var snow = Path()
            snow.move(to: CGPoint(x: 108, y: 138))
            snow.addCurve(to: CGPoint(x: 162, y: 72), control1: CGPoint(x: 106, y: 98), control2: CGPoint(x: 132, y: 72))
            snow.addCurve(to: CGPoint(x: 216, y: 138), control1: CGPoint(x: 192, y: 72), control2: CGPoint(x: 218, y: 98))
            snow.closeSubpath()
            g.fill(
                snow,
                with: .radialGradient(
                    Gradient(colors: [.white, StorybookArt.color(0xF3FAFF), StorybookArt.color(0xD8ECF9)]),
                    center: CGPoint(x: 146, y: 98),
                    startRadius: 4,
                    endRadius: 68
                )
            )
            g.stroke(snow, with: .color(StorybookArt.outline(for: 0xAED0E8)), lineWidth: 5)

            // Condensed-milk drizzle on snow dome
            var drizzle = Path()
            drizzle.move(to: CGPoint(x: 132, y: 108))
            drizzle.addQuadCurve(to: CGPoint(x: 156, y: 102), control: CGPoint(x: 144, y: 118))
            drizzle.addQuadCurve(to: CGPoint(x: 186, y: 110), control: CGPoint(x: 170, y: 92))
            g.stroke(drizzle, with: .color(StorybookArt.color(0xFFF2C8)), style: StrokeStyle(lineWidth: 8, lineCap: .round))

            // Sliced strawberry & mango on bingsu + glossy cherry crown
            let mango = Path(roundedRect: CGRect(x: 122, y: 112, width: 20, height: 18), cornerRadius: 5)
            StorybookArt.fillAndStroke(g, mango, fill: StorybookArt.color(0xFFB838), stroke: StorybookArt.outline(for: 0xD88318), width: 3.4)
            let bBerry = Path(ellipseIn: CGRect(x: 174, y: 108, width: 24, height: 22))
            StorybookArt.fillAndStroke(g, bBerry, fill: StorybookArt.color(0xF04564), stroke: StorybookArt.outline(for: 0xB82542), width: 3.4)
            StorybookArt.highlight(g, in: CGRect(x: 180, y: 112, width: 8, height: 6), opacity: 0.7)

            let bCherry = Path(ellipseIn: CGRect(x: 150, y: 60, width: 22, height: 22))
            StorybookArt.fillAndStroke(g, bCherry, fill: StorybookArt.color(0xF24464), stroke: StorybookArt.outline(for: 0xC22244), width: 3.6)
            StorybookArt.highlight(g, in: CGRect(x: 155, y: 64, width: 7, height: 5), opacity: 0.85)

            // Footed celadon-blush bingsu bowl
            let foot = Path(roundedRect: CGRect(x: 136, y: 184, width: 52, height: 18), cornerRadius: 8)
            StorybookArt.fillAndStroke(g, foot, fill: StorybookArt.color(0xFFF6F9), stroke: StorybookArt.outline(for: 0xE6A4BE), width: 4.5)
            var bowl = Path()
            bowl.move(to: CGPoint(x: 102, y: 136))
            bowl.addLine(to: CGPoint(x: 222, y: 136))
            bowl.addCurve(to: CGPoint(x: 102, y: 136), control1: CGPoint(x: 214, y: 196), control2: CGPoint(x: 110, y: 196))
            bowl.closeSubpath()
            StorybookArt.fillAndStroke(g, bowl, fill: StorybookArt.color(0xFFD6E6), stroke: StorybookArt.outline(for: 0xE882AB), width: 5)
            let bowlRim = Path(roundedRect: CGRect(x: 98, y: 128, width: 128, height: 14), cornerRadius: 7)
            StorybookArt.fillAndStroke(g, bowlRim, fill: StorybookArt.color(0xFFF2F7), stroke: StorybookArt.outline(for: 0xE882AB), width: 4)
            StorybookArt.highlight(g, in: CGRect(x: 124, y: 150, width: 26, height: 10), opacity: 0.55)

            // Left front: Tall golden waffle cone with pastel double scoops & cherry
            var cone = Path()
            cone.move(to: CGPoint(x: 36, y: 120))
            cone.addLine(to: CGPoint(x: 118, y: 120))
            cone.addQuadCurve(to: CGPoint(x: 77, y: 214), control: CGPoint(x: 100, y: 178))
            cone.addQuadCurve(to: CGPoint(x: 36, y: 120), control: CGPoint(x: 54, y: 178))
            cone.closeSubpath()
            StorybookArt.fillAndStroke(g, cone, fill: StorybookArt.color(0xF2B872), stroke: StorybookArt.outline(for: 0xD48E40), width: 5.5)

            var waffleClip = g
            waffleClip.clip(to: cone)
            var grid = Path()
            for k in -2...4 {
                let gx = 40 + CGFloat(k) * 20
                grid.move(to: CGPoint(x: gx - 24, y: 120)); grid.addLine(to: CGPoint(x: gx + 36, y: 210))
                grid.move(to: CGPoint(x: gx + 36, y: 120)); grid.addLine(to: CGPoint(x: gx - 24, y: 210))
            }
            waffleClip.stroke(grid, with: .color(StorybookArt.outline(for: 0xD48E40).opacity(0.55)), lineWidth: 3.5)

            let coneRim = Path(roundedRect: CGRect(x: 32, y: 114, width: 90, height: 14), cornerRadius: 7)
            StorybookArt.fillAndStroke(g, coneRim, fill: StorybookArt.color(0xF7C986), stroke: StorybookArt.outline(for: 0xD48E40), width: 4.5)

            // Bottom mint scoop
            let scoop1 = Path(ellipseIn: CGRect(x: 32, y: 74, width: 90, height: 58))
            StorybookArt.fillAndStroke(g, scoop1, fill: StorybookArt.color(0x9EE7CC), stroke: StorybookArt.outline(for: 0x5CC09E), width: 5)
            StorybookArt.highlight(g, in: CGRect(x: 46, y: 84, width: 22, height: 12), opacity: 0.65)

            // Top strawberry scoop
            let scoop2 = Path(ellipseIn: CGRect(x: 40, y: 38, width: 74, height: 54))
            StorybookArt.fillAndStroke(g, scoop2, fill: StorybookArt.color(0xFF9AC2), stroke: StorybookArt.outline(for: 0xE06294), width: 5)
            StorybookArt.highlight(g, in: CGRect(x: 54, y: 48, width: 20, height: 11), opacity: 0.7)

            // Rainbow sprinkles on top scoop
            let sprinkles: [(CGFloat, CGFloat, Double, UInt32)] = [
                (58, 66, 0.35, 0xFFE38A), (82, 58, -0.45, 0x9CCBFF),
                (94, 72, 0.2, 0xFFFDFB), (68, 78, -0.25, 0xFF6FA8),
            ]
            for (sx, sy, rot, hex) in sprinkles {
                var sp = g
                sp.translateBy(x: sx, y: sy)
                sp.rotate(by: .radians(rot))
                sp.fill(Path(roundedRect: CGRect(x: -5, y: -2.2, width: 10, height: 4.4), cornerRadius: 2.2), with: .color(StorybookArt.color(hex)))
            }

            // Cherry on top of cone
            var stem = Path()
            stem.move(to: CGPoint(x: 78, y: 24))
            stem.addQuadCurve(to: CGPoint(x: 92, y: 10), control: CGPoint(x: 82, y: 12))
            g.stroke(stem, with: .color(StorybookArt.color(0x63BA6B)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            let cherry = Path(ellipseIn: CGRect(x: 64, y: 18, width: 26, height: 26))
            StorybookArt.fillAndStroke(g, cherry, fill: StorybookArt.color(0xF24464), stroke: StorybookArt.outline(for: 0xC22244), width: 4.2)
            StorybookArt.highlight(g, in: CGRect(x: 70, y: 23, width: 8, height: 6), opacity: 0.85)

            // Cheerful sparkles
            StorybookArt.sparkle(g, at: CGPoint(x: 28, y: 44), radius: 13, color: Theme.lemon)
            StorybookArt.sparkle(g, at: CGPoint(x: 214, y: 36), radius: 11, color: .white)
            StorybookArt.sparkle(g, at: CGPoint(x: 126, y: 42), radius: 9, color: Theme.pink)
        }
    }
}

final class IceHand {
    enum Mode { case none, held, lever, blend, shaver, tickle, bin(Int) }
    var mode: Mode = .none
    var active = false
    var start = CGPoint.zero
    var beganAt = Date()
    var wasBlendToggle = false
    var tubTapped: Int?
    var leverTapped: Int?
    var toppingDragging = false
    /// The lifted thing's offset from her finger, eased so it glides up instead of jumping.
    var offset = CGSize.zero
}

private struct ICDockPlate: View, Equatable {
    let topping: ICTopping
    let wanted: Bool

    var body: some View {
        GameDockTile(size: 82, selected: false, pulsing: false, tint: .white, cornerRadius: 24) {
            Canvas { ctx, size in
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                switch topping {
                case .cherry:
                    g.translateBy(x: 0, y: 10)
                    g.scaleBy(x: 0.92, y: 0.92)
                    ICScene.topping(g, topping, held: false)
                case .wafer:
                    g.translateBy(x: 0, y: 2)
                    g.scaleBy(x: 0.72, y: 0.72)
                    ICScene.topping(g, topping, held: false)
                case .straw:
                    g.translateBy(x: -7, y: 4)
                    g.scaleBy(x: 0.44, y: 0.44)
                    ICScene.topping(g, topping, held: false)
                case .redBean, .mangoCubes, .strawberries, .injeolmi:
                    g.translateBy(x: 0, y: 2)
                    g.scaleBy(x: 1.0, y: 1.0)
                    ICScene.topping(g, topping, held: false)
                default:
                    g.translateBy(x: 0, y: 36)
                    g.scaleBy(x: 0.48, y: 0.48)
                    ICScene.topping(g, topping, held: false)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if wanted {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.pink)
                    .padding(5)
                    .background(Circle().fill(.white))
                    .overlay(Circle().stroke(Theme.blush, lineWidth: 2))
                    .offset(x: 8, y: -8)
            }
        }
    }
}

private struct ICBaseInlineButton: View {
    let base: ICBase
    let sim: IceSim
    let order: ICOrder
    let waiting: Bool
    let tap: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { _ in
            let selected = sim.build.base == base
            let wanted = waiting && order.base == base && !selected
            Button(action: tap) {
                GameDockTile(size: 76, selected: selected, pulsing: false, tint: Color(hex: 0xFFF9F4), cornerRadius: 22) {
                    Canvas { ctx, size in
                        var g = ctx
                        var one = ICBuild()
                        one.base = base
                        let k: CGFloat = base == .cup ? 0.50 : 0.42
                        g.translateBy(x: size.width / 2, y: size.height / 2 - base.depth * k * 0.5 + 3)
                        g.scaleBy(x: k, y: k)
                        ICArt.drawBuild(g, one, at: .zero, time: 0)
                    }
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topTrailing) {
                    if wanted {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Theme.pink)
                            .padding(4)
                            .background(Circle().fill(.white))
                            .overlay(Circle().stroke(Theme.blush, lineWidth: 2))
                            .offset(x: 7, y: -7)
                    }
                }
            }
            .buttonStyle(Squish())
            .accessibilityLabel(label)
        }
    }

    private var label: String {
        switch base {
        case .waffle: return "Waffle Cone"
        case .choco: return "Chocolate Cone"
        case .cup: return "Cup"
        default: return "Base"
        }
    }
}

private struct ICStationSwitcher: View {
    let active: ICStation
    let disabled: Bool
    let select: (ICStation) -> Void

    var body: some View {
        GameTrayCard(cornerRadius: 26, paddingH: 7, paddingV: 5) {
            HStack(spacing: 5) {
                ForEach(ICStation.allCases, id: \.self) { s in
                    let isSelected = s == active
                    Button {
                        select(s)
                    } label: {
                        Canvas { ctx, size in
                            drawIcon(ctx, size: size, station: s)
                        }
                        .frame(width: 50, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isSelected ? Color.white : Theme.cream.opacity(0.65))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isSelected ? Theme.pink : Theme.blush.opacity(0.6), lineWidth: isSelected ? 3.5 : 2)
                        )
                        .scaleEffect(isSelected ? 1.05 : 0.94)
                        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isSelected)
                    }
                    .buttonStyle(Squish())
                    .disabled(disabled)
                    .accessibilityLabel(label(for: s))
                }
            }
        }
    }

    private func label(for s: ICStation) -> String {
        switch s {
        case .scoop: return "Scoops"
        case .soft: return "Soft Serve"
        case .smoothie: return "Smoothies"
        case .bingsu: return "Bingsu"
        }
    }

    private func drawIcon(_ ctx: GraphicsContext, size: CGSize, station: ICStation) {
        let s = min(size.width, size.height) / 48
        var g = ctx
        g.translateBy(x: (size.width - 48 * s) / 2, y: (size.height - 48 * s) / 2)
        g.scaleBy(x: s, y: s)

        switch station {
        case .scoop:
            var cone = Path()
            cone.move(to: CGPoint(x: 16, y: 26))
            cone.addLine(to: CGPoint(x: 32, y: 26))
            cone.addQuadCurve(to: CGPoint(x: 24, y: 44), control: CGPoint(x: 28.5, y: 37))
            cone.addQuadCurve(to: CGPoint(x: 16, y: 26), control: CGPoint(x: 19.5, y: 37))
            cone.closeSubpath()
            StorybookArt.shape(g, cone, hex: 0xF0B870, width: 2.2)

            let s1 = Path(ellipseIn: CGRect(x: 14, y: 15.5, width: 20, height: 14.5))
            StorybookArt.shape(g, s1, hex: 0xA8E8CF, width: 2.2)
            let s2 = Path(ellipseIn: CGRect(x: 16, y: 7, width: 16, height: 13))
            StorybookArt.shape(g, s2, hex: 0xFF9EC4, width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: 18.5, y: 9.5, width: 4.5, height: 2.6), opacity: 0.7)
            let ch = Path(ellipseIn: CGRect(x: 21, y: 3, width: 6, height: 6))
            StorybookArt.shape(g, ch, hex: 0xF25474, width: 1.5)

        case .soft:
            var cone = Path()
            cone.move(to: CGPoint(x: 16, y: 28))
            cone.addLine(to: CGPoint(x: 32, y: 28))
            cone.addQuadCurve(to: CGPoint(x: 24, y: 44), control: CGPoint(x: 28.5, y: 38))
            cone.addQuadCurve(to: CGPoint(x: 16, y: 28), control: CGPoint(x: 19.5, y: 38))
            cone.closeSubpath()
            StorybookArt.shape(g, cone, hex: 0xE6A764, width: 2.2)

            let r1 = Path(ellipseIn: CGRect(x: 12.5, y: 20, width: 23, height: 10.5))
            StorybookArt.shape(g, r1, hex: 0xFFF2CF, width: 2.1)
            let r2 = Path(ellipseIn: CGRect(x: 15, y: 13, width: 18, height: 9.5))
            StorybookArt.shape(g, r2, hex: 0xFFBDD6, width: 2.1)
            var tip = Path()
            tip.move(to: CGPoint(x: 18, y: 15))
            tip.addCurve(to: CGPoint(x: 30, y: 15), control1: CGPoint(x: 19, y: 4), control2: CGPoint(x: 26, y: 3))
            tip.closeSubpath()
            StorybookArt.shape(g, tip, hex: 0xFFF6DF, width: 2)
            StorybookArt.highlight(g, in: CGRect(x: 16, y: 22.2, width: 7, height: 3), opacity: 0.65)

        case .smoothie:
            var straw = Path()
            straw.move(to: CGPoint(x: 26, y: 18))
            straw.addLine(to: CGPoint(x: 33, y: 4.5))
            g.stroke(straw, with: .color(StorybookArt.outline(for: 0xFF7FA8)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
            g.stroke(straw, with: .color(.white), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            var glass = Path()
            glass.move(to: CGPoint(x: 14, y: 16))
            glass.addLine(to: CGPoint(x: 34, y: 16))
            glass.addLine(to: CGPoint(x: 30.5, y: 42.5))
            glass.addQuadCurve(to: CGPoint(x: 17.5, y: 42.5), control: CGPoint(x: 24, y: 45))
            glass.closeSubpath()
            var clipped = g
            clipped.clip(to: glass)
            clipped.fill(
                Path(CGRect(x: 12, y: 18, width: 24, height: 28)),
                with: .linearGradient(
                    Gradient(colors: [StorybookArt.color(0xFF8EB8), StorybookArt.color(0xFFB870)]),
                    startPoint: CGPoint(x: 0, y: 18),
                    endPoint: CGPoint(x: 0, y: 44)
                )
            )
            g.stroke(glass, with: .color(StorybookArt.outline(for: 0x9CD0EC)), lineWidth: 2.4)
            let cap = Path(ellipseIn: CGRect(x: 14.5, y: 10.5, width: 19, height: 9))
            StorybookArt.shape(g, cap, hex: 0xFFFDFB, width: 1.9)
            StorybookArt.highlight(g, in: CGRect(x: 17, y: 21, width: 3.5, height: 15), opacity: 0.55)

        case .bingsu:
            var spoon = Path()
            spoon.move(to: CGPoint(x: 29, y: 24))
            spoon.addLine(to: CGPoint(x: 39, y: 7))
            g.stroke(spoon, with: .color(StorybookArt.outline(for: 0xFF9EC4)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
            g.stroke(spoon, with: .color(StorybookArt.color(0xFFC2DA)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            var snow = Path()
            snow.move(to: CGPoint(x: 9, y: 27))
            snow.addCurve(to: CGPoint(x: 24, y: 8), control1: CGPoint(x: 9, y: 16), control2: CGPoint(x: 16, y: 8))
            snow.addCurve(to: CGPoint(x: 39, y: 27), control1: CGPoint(x: 32, y: 8), control2: CGPoint(x: 39, y: 16))
            snow.closeSubpath()
            StorybookArt.fillAndStroke(g, snow, fill: StorybookArt.color(0xF6FBFF), stroke: StorybookArt.outline(for: 0xB4D4EA), width: 2)

            let pat = Path(ellipseIn: CGRect(x: 18, y: 7, width: 12, height: 7.5))
            StorybookArt.shape(g, pat, hex: 0x7A3242, width: 1.6)
            let berry = Path(ellipseIn: CGRect(x: 28, y: 17, width: 6.5, height: 6))
            StorybookArt.shape(g, berry, hex: 0xED3B5B, width: 1.4)
            let mango = Path(roundedRect: CGRect(x: 12.5, y: 17, width: 6.5, height: 6), cornerRadius: 1.8)
            StorybookArt.shape(g, mango, hex: 0xFFB62F, width: 1.4)

            let foot = Path(roundedRect: CGRect(x: 17, y: 38, width: 14, height: 5), cornerRadius: 2.5)
            StorybookArt.shape(g, foot, hex: 0x86D4C2, width: 1.8)
            var bowl = Path()
            bowl.move(to: CGPoint(x: 7, y: 26))
            bowl.addLine(to: CGPoint(x: 41, y: 26))
            bowl.addCurve(to: CGPoint(x: 7, y: 26), control1: CGPoint(x: 38, y: 42), control2: CGPoint(x: 10, y: 42))
            bowl.closeSubpath()
            StorybookArt.shape(g, bowl, hex: 0x9EE4D2, width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: 12, y: 29, width: 7, height: 2.6), opacity: 0.55)
        }
    }
}

private struct ICServeBellButton: View {
    let sim: IceSim
    let waiting: Bool
    let bob: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { _ in
            let canServe = waiting && sim.canServe
            Button {
                guard canServe else { return }
                action()
            } label: {
                ZStack {
                    if canServe {
                        Circle()
                            .stroke(Theme.lemon.opacity(0.85), lineWidth: 5)
                            .frame(width: 96, height: 96)
                            .scaleEffect(bob ? 1.08 : 0.96)
                    }
                    Circle().fill(canServe ? Color(hex: 0xFFD84A) : Color(hex: 0xE5DDD2))
                    Image(systemName: "bell.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 82, height: 82)
                .overlay(Circle().stroke(.white, lineWidth: 5.5))
                .shadow(color: Theme.ink.opacity(canServe ? 0.25 : 0.1), radius: 6, y: 4)
            }
            .buttonStyle(Squish())
            .opacity(canServe ? 1 : 0.45)
            .scaleEffect(bob && canServe ? 1.08 : 1)
            .disabled(!canServe)
            .accessibilityLabel("Serve Treat")
        }
    }
}

struct IceCreamView: View {
    let initialStation: ICStation
    let exit: () -> Void

    init(station: ICStation = .scoop, exit: @escaping () -> Void) {
        initialStation = station
        self.exit = exit
        _station = State(initialValue: station)
    }

    private enum Phase { case arriving, waiting, eating, happy, leaving }

    @StateObject private var store = IceCreamStore()
    @State private var sim = IceSim()
    @State private var station: ICStation
    @State private var hand = IceHand()
    @GestureState private var handDown = false
    @GestureState private var toppingDown = false
    @State private var showStickers = false
    @State private var order = ICOrder.random(customer: 0, kind: .scoops)
    @State private var picture = ICBuild()
    @State private var phase: Phase = .arriving
    @State private var custX: CGFloat = 520
    @State private var eyes = "open"
    @State private var mouth = "smile"
    @State private var bob = false
    @State private var stars: Int?
    @State private var floating = 0
    @State private var jarBounce = false
    @State private var carrying: ICTopping?
    @State private var started = false
    @State private var demoServe = false

    static func dockLayout(for s: ICStation) -> (hasBase: Bool, baseSpots: [CGPoint], toppings: [ICTopping], spots: [CGPoint]) {
        let hasBase = (s == .scoop || s == .soft)
        let baseSpots: [CGPoint] = hasBase
            ? [CGPoint(x: 84, y: ICGeo.dockY), CGPoint(x: 170, y: ICGeo.dockY), CGPoint(x: 256, y: ICGeo.dockY)]
            : []
        let toppings: [ICTopping]
        switch s {
        case .scoop, .soft: toppings = ICTopping.parlor
        case .smoothie: toppings = ICTopping.smoothie
        case .bingsu: toppings = ICTopping.bingsu
        }
        let spots: [CGPoint]
        if hasBase {
            let startX: CGFloat = 374
            let step: CGFloat = 94
            spots = toppings.indices.map { CGPoint(x: startX + CGFloat($0) * step, y: ICGeo.dockY) }
        } else {
            let step: CGFloat = toppings.count <= 4 ? 136 : 126
            let startX = 512 - CGFloat(toppings.count - 1) * step / 2
            spots = toppings.indices.map { CGPoint(x: startX + CGFloat($0) * step, y: ICGeo.dockY) }
        }
        return (hasBase, baseSpots, toppings, spots)
    }

    var body: some View {
        GeometryReader { geo in
            let map = ICMap(size: geo.size)
            ZStack {
                Canvas(opaque: true) { ctx, _ in
                    ICScene.drawBackdrop(ctx, map: map, station: station)
                }
                .allowsHitTesting(false)
                customerLayer
                    .frame(width: 1024, height: 834)
                    .scaleEffect(map.s)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .allowsHitTesting(false)
                // Everything that moves, capped at 60 fps so 120 Hz screens do not double the work.
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
                    Canvas { ctx, _ in
                        sim.step(tl.date)
                        ICScene.draw(ctx, map: map, sim: sim)
                    }
                }
                .contentShape(Rectangle())
                .gesture(handGesture(map))
                controls(map)
                    .frame(width: 1024, height: 834)
                    .coinPurse(game: IceSim.gameID)
                    .scaleEffect(map.s)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                if showStickers {
                    StickerBookView(game: IceSim.gameID) {
                        withAnimation(.spring(response: 0.35)) { showStickers = false }
                    }
                    .transition(.opacity)
                    .zIndex(5)
                }
            }
            .coordinateSpace(name: "ice")
        }
        .ignoresSafeArea()
        .defersSystemGestures(on: .bottom)
        .onAppear(perform: start)
        .onDisappear {
            IceSound.shared.stopLoops()
            store.save()
        }
        .onChange(of: handDown) { down in
            if !down && hand.active {
                sim.cancelInteraction()
                hand.mode = .none
                hand.active = false
                hand.tubTapped = nil
                hand.leverTapped = nil
            }
        }
        .onChange(of: toppingDown) { down in
            if !down && carrying != nil {
                if hand.toppingDragging { sim.cancelInteraction() }
                hand.toppingDragging = false
                carrying = nil
            }
        }
        .task { await blinkLoop() }
    }

    private func start() {
        guard !started else { return }
        started = true
        _ = IceSound.shared
        sim.setStation(initialStation)
        order = ICOrder.random(customer: Int.random(in: 0..<BakeryPalette.customers.count), kind: kindFor(station))
        picture = order.picture()
        applyLaunchArguments()
        if !demoServe { arrive() }
    }

    private func switchStation(to next: ICStation) {
        guard next != station, phase != .eating else { return }
        Sound.shared.tap()
        Sound.shared.play(.flip, volume: 0.65)
        carrying = nil
        hand.toppingDragging = false
        hand.mode = .none
        hand.active = false
        hand.tubTapped = nil
        hand.leverTapped = nil
        sim.cancelInteraction()
        let incompatibleBase =
            (next == .smoothie && sim.build.base != .glass) ||
            (next != .smoothie && sim.build.base == .glass) ||
            (next == .bingsu && sim.build.base != .bowl) ||
            (next != .bingsu && sim.build.base == .bowl)
        if incompatibleBase {
            sim.build = ICBuild()
            sim.baseDrop = nil
            sim.resetSoft()
            sim.profileDirty = true
        }
        sim.setStation(next)
        station = next
        order = ICOrder.random(customer: order.customer, kind: kindFor(next))
        picture = order.picture()
        sim.order = order
        if phase == .waiting {
            Sound.shared.play(.bubble, volume: 0.5)
        }
    }

    // MARK: Her hand on the shop

    private func handGesture(_ map: ICMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("ice"))
            .updating($handDown) { _, down, _ in down = true }
            .onChanged { v in
                let p = map.design(v.location)
                if !hand.active {
                    hand.active = true
                    hand.beganAt = Date()
                    began(p)
                } else {
                    moved(p)
                }
            }
            .onEnded { v in
                guard hand.active else { return }
                let p = map.design(v.location)
                let dist = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                let elapsed = Date().timeIntervalSince(hand.beganAt)
                ended(p, dist: dist, elapsed: elapsed)
                hand.active = false
                hand.tubTapped = nil
                hand.leverTapped = nil
            }
    }

    private func began(_ p: CGPoint) {
        guard carrying == nil, sim.held == nil else {
            hand.active = false
            return
        }
        hand.start = p
        hand.tubTapped = nil
        hand.leverTapped = nil
        hand.wasBlendToggle = false
        switch sim.station {
        case .scoop:
            if hypot(p.x - ICGeo.well.x, p.y - (ICGeo.well.y - 24)) < 68 {
                grab(.scoop, at: p, from: CGPoint(x: ICGeo.well.x, y: ICGeo.well.y - 44))
                return
            }
            if let i = sim.tub(at: p) {
                hand.tubTapped = i
                hand.mode = .held
                hand.offset = .zero
                Sound.shared.tap()
                sim.pickUpScoop(fromTub: i, at: p)
                moved(p)
                return
            }
        case .soft:
            for (i, c) in ICGeo.softButtons.enumerated()
            where abs(p.x - c.x) <= ICGeo.softButtonR && abs(p.y - c.y) <= 68 {
                hand.mode = .lever
                hand.leverTapped = i
                sim.pressLever(i)
                return
            }
        case .smoothie:
            if hypot(p.x - ICGeo.blendButton.x, p.y - ICGeo.blendButton.y) < 50 && sim.jarOnBase {
                hand.mode = .blend
                hand.wasBlendToggle = sim.blendingToggle
                if sim.blendingToggle {
                    sim.blendingToggle = false
                    sim.blending = false
                    sim.blendAutoPour = false
                    IceSound.shared.play(.lever, volume: 0.45, rate: 0.9)
                } else {
                    sim.ensureBlendMilk()
                    sim.blending = true
                    IceSound.shared.play(.lever, volume: 0.5, rate: 1.3)
                }
                Sound.shared.tap()
                return
            }
            if sim.autoPour != .milk && hypot(p.x - ICGeo.milkHome.x, p.y - ICGeo.milkHome.y) < 62 {
                grab(.milk, at: p, from: ICGeo.milkHome)
                return
            }
            for (i, c) in ICGeo.bins.enumerated() where abs(p.x - c.x) < 44 && abs(p.y - c.y) < 48 {
                hand.mode = .bin(i)
                Sound.shared.tap()
                return
            }
            let jp = sim.jarP
            if sim.jarOnBase && sim.autoPour != .jar && p.x > jp.x - 130 && p.x < jp.x + 96 && p.y > jp.y - ICGeo.jarH - 12 && p.y < jp.y + 12 {
                grab(.jar, at: p, from: CGPoint(x: jp.x, y: jp.y - ICGeo.jarH / 2))
                return
            }
        case .bingsu:
            let onButton = hypot(p.x - ICGeo.snowButton.x, p.y - ICGeo.snowButton.y) < ICGeo.snowButtonR + 24
            let onChamber = ICGeo.snowChamber.insetBy(dx: -14, dy: -14).contains(p)
            let onIceTray = ICGeo.snowIceTray.contains(p)
            let onBowl = abs(p.x - sim.S.x) < 92 && p.y > sim.S.y - 115 && p.y < sim.S.y + 92
            if onButton || onChamber || onIceTray || onBowl {
                hand.mode = .shaver
                sim.pressShaver(true)
                return
            }
        }
        if ICGeo.window.contains(p) {
            if phase == .waiting && sim.canServe {
                hand.mode = .none
                hand.active = false
                serve()
            } else {
                hand.mode = .tickle
                tickle()
            }
            return
        }
        hand.mode = .none
    }

    private func grab(_ h: ICHeld, at p: CGPoint, from home: CGPoint) {
        hand.mode = .held
        hand.offset = CGSize(width: home.x - p.x, height: home.y - p.y)
        Sound.shared.tap()
        sim.pickUp(h, at: p)
        moved(p)
    }

    private func moved(_ p: CGPoint) {
        switch hand.mode {
        case .held:
            guard let h = sim.held else { return }
            let target: CGPoint
            if h == .scoop, sim.scoopLockedTub != nil, p.x < 460 && p.y > 360 && p.y < 630 {
                // Keep the dipper visually seated inside the touched tub so front-row scoops never jump upward into the back row.
                target = CGPoint(x: p.x, y: p.y - 14)
            } else {
                target = IceCreamView.lifted(p, h)
            }
            hand.offset = FingerLift.ease(hand.offset, toward: CGSize(width: target.x - p.x, height: target.y - p.y))
            sim.carry(to: CGPoint(x: p.x + hand.offset.width, y: p.y + hand.offset.height), finger: p)
        case .bin(let i):
            if hypot(p.x - hand.start.x, p.y - hand.start.y) > 16 {
                grab(.fruit(ICFruit.allCases[i]), at: p, from: ICGeo.bins[i])
            }
        default:
            break
        }
    }

    private func ended(_ p: CGPoint, dist: CGFloat, elapsed: TimeInterval) {
        switch hand.mode {
        case .held:
            let heldNow = sim.held
            if dist < 28, heldNow == .milk, sim.jarOnBase {
                sim.autoPourMilk()
            } else if dist < 30, heldNow == .jar, sim.jarVolume > 0.01 {
                sim.autoPourJar()
            } else if heldNow == .scoop, let tubIdx = hand.tubTapped, dist < 44, abs(sim.tip.x - sim.S.x) >= 135 {
                sim.tapTub(tubIdx)
            } else {
                moved(p)
                sim.release()
            }
        case .lever:
            if let idx = hand.leverTapped, elapsed < 0.38 && dist < 36 && !sim.softFull {
                sim.triggerSoftBurst(idx, duration: 0.9)
            } else {
                sim.pressLever(nil)
            }
        case .shaver:
            sim.pressShaver(false)
            if dist < 36 && elapsed < 0.45 { sim.tapShaver() }
        case .blend:
            if hand.wasBlendToggle {
                sim.blending = false
                sim.blendingToggle = false
                sim.blendAutoPour = false
            } else if dist < 36 && elapsed < 0.45 {
                sim.tapBlend()
            } else {
                sim.blendingToggle = false
                sim.blending = false
                sim.blendAutoPour = false
            }
        case .bin(let i):
            if dist < 24 { sim.tossFruit(ICFruit.allCases[i]) }
        default:
            break
        }
        hand.mode = .none
    }

    /// Where a held thing goes for her finger at p. The dipper works just ahead of her finger, held by its handle; pourers and carried things sit above.
    static func lifted(_ p: CGPoint, _ h: ICHeld) -> CGPoint {
        let lift: CGFloat
        switch h {
        case .scoop: lift = FingerLift.tool
        case .topping(let t):
            switch t {
            case .cherry, .wafer, .straw, .redBean, .mangoCubes, .strawberries, .injeolmi: lift = FingerLift.item
            default: lift = FingerLift.pour
            }
        case .fruit: lift = FingerLift.item
        case .milk, .jar: lift = FingerLift.carry(below: 46)
        }
        return FingerLift.point(p, lift: lift, bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
    }

    // MARK: Controls

    private func controls(_ map: ICMap) -> some View {
        ZStack {
            HStack(spacing: 14) {
                HomeButton(size: GameChromeLayout.buttonSize) {
                    store.save()
                    exit()
                }
                .disabled(phase == .eating)
                StickerBookButton(game: IceSim.gameID, size: GameChromeLayout.buttonSize) {
                    withAnimation(.spring(response: 0.35)) { showStickers = true }
                }
                ICStationSwitcher(active: station, disabled: phase == .eating) { next in
                    switchStation(to: next)
                }
                Spacer(minLength: 12)
                RoundButton(symbol: "arrow.counterclockwise", tint: Color(hex: 0x46B7B0), size: 58) {
                    Sound.shared.play(.whoosh, volume: 0.6)
                    sim.clearStand()
                    carrying = nil
                    hand.toppingDragging = false
                }
                .accessibilityLabel("Start Over")
                CoinCounter(game: IceSim.gameID, height: GameChromeLayout.buttonSize)
                heartJar
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if phase == .waiting || phase == .happy {
                orderBubble
                    .position(x: 879, y: 184)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
            ForEach(0..<floating, id: \.self) { i in
                ICFloatingHeart(index: i).position(x: 879, y: 300)
            }
            ICServeBellButton(sim: sim, waiting: phase == .waiting, bob: bob) {
                serve()
            }
            .position(ICGeo.serveBell)

            dock(map)
            StickerToast(game: IceSim.gameID, target: GameChromeLayout.stickerTarget)
        }
    }

    private func kindFor(_ s: ICStation) -> ICKind {
        switch s {
        case .scoop: return .scoops
        case .soft: return .soft
        case .smoothie: return .smoothie
        case .bingsu: return .bingsu
        }
    }

    private var heartJar: some View {
        ZStack(alignment: .bottomTrailing) {
            Sprite("heartjar", box: Box.thing).frame(width: 72, height: 72)
            Text("\(store.hearts)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 2)
                .background(Capsule().fill(Color(hex: 0xF45C9A)))
                .offset(x: 6, y: 4)
        }
        .scaleEffect(jarBounce ? 1.3 : 1)
        .allowsHitTesting(false)
    }

    private var orderBubble: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.white)
                .shadow(color: Theme.ink.opacity(0.22), radius: 8, y: 5)
            if phase == .happy, let s = stars {
                StarRating(filled: s, size: 48)
            } else {
                HStack(spacing: 4) {
                    ICPictureView(build: picture)
                        .equatable()
                        .frame(width: 108, height: 124)
                    ICOrderParts(order: order, sim: sim)
                        .frame(width: 88)
                }
            }
        }
        .frame(width: 222, height: 134)
        .scaleEffect(bob ? 1.03 : 0.98)
    }

    private func dock(_ map: ICMap) -> some View {
        let layout = IceCreamView.dockLayout(for: station)
        let trayW: CGFloat = layout.hasBase ? 972 : (layout.toppings.count <= 4 ? 592 : 684)
        return ZStack {
            GameTrayCard(cornerRadius: 34, paddingH: 0, paddingV: 0) {
                Color.clear.frame(width: trayW, height: 100)
            }
            .position(x: 512, y: ICGeo.dockY)
            .allowsHitTesting(false)

            if layout.hasBase {
                ForEach(Array(ICBase.parlorBases.enumerated()), id: \.element) { i, b in
                    ICBaseInlineButton(base: b, sim: sim, order: order, waiting: phase == .waiting) {
                        Sound.shared.tap()
                        sim.placeBase(b)
                    }
                    .position(layout.baseSpots[i])
                }
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(Theme.blush)
                    .frame(width: 5, height: 64)
                    .position(x: 314, y: ICGeo.dockY)
                    .allowsHitTesting(false)
            }
            ForEach(Array(layout.toppings.enumerated()), id: \.element) { i, t in
                let spot = layout.spots[i]
                let wanted = phase == .waiting && (order.topping == t || sim.wanted(bingsu: t))
                ICDockPlate(topping: t, wanted: wanted)
                    .equatable()
                    .opacity(carrying == t && hand.toppingDragging ? 0.35 : 1)
                    .gesture(toppingGesture(t, spot: spot, map: map))
                    .position(spot)
            }
        }
    }

    private func toppingGesture(_ t: ICTopping, spot: CGPoint, map: ICMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("ice"))
            .updating($toppingDown) { _, down, _ in down = true }
            .onChanged { v in
                let p = map.design(v.location)
                let movedDist = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                if carrying == nil {
                    guard !hand.active, sim.held == nil else { return }
                    carrying = t
                    hand.toppingDragging = false
                    sim.dockHome[t] = spot
                }
                guard carrying == t else { return }
                // Wait until she drags past the tap threshold before picking up so touch-down never leaks sprinkles in the dock.
                if !hand.toppingDragging && movedDist >= 14 {
                    hand.toppingDragging = true
                    hand.offset = CGSize(width: spot.x - p.x, height: spot.y - p.y)
                    Sound.shared.tap()
                    sim.pickUp(.topping(t), at: p)
                }
                guard hand.toppingDragging, let h = sim.held else { return }
                let target = IceCreamView.lifted(p, h)
                hand.offset = FingerLift.ease(hand.offset, toward: CGSize(width: target.x - p.x, height: target.y - p.y))
                sim.carry(to: CGPoint(x: p.x + hand.offset.width, y: p.y + hand.offset.height), finger: p)
            }
            .onEnded { v in
                guard carrying == t else { return }
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                if !hand.toppingDragging || moved < 14 {
                    if hand.toppingDragging { sim.held = nil }
                    Sound.shared.tap()
                    sim.autoTopping(t)
                } else {
                    let p = map.design(v.location)
                    if let h = sim.held { sim.carry(to: IceCreamView.lifted(p, h), finger: p) }
                    sim.release()
                }
                hand.toppingDragging = false
                carrying = nil
            }
    }

    // MARK: The customer

    private var customerLayer: some View {
        let name = BakeryPalette.customers[max(0, min(BakeryPalette.customers.count - 1, order.customer))]
        return ZStack {
            Sprite("cust_\(name)", box: Box.customer)
            Sprite("eyes_\(eyes)", box: Box.customer)
            Sprite("mouth_\(mouth)", box: Box.customer)
        }
        .frame(width: 400, height: 440)
        .scaleEffect(ICGeo.customerScale)
        .offset(y: bob ? -5 : 4)
        .position(x: ICGeo.customer.x + custX, y: ICGeo.customer.y + 20)
        .opacity(phase == .leaving && custX < -100 ? 0 : 1)
    }

    private func arrive() {
        custX = 420
        eyes = "open"
        mouth = "smile"
        stars = nil
        sim.order = order
        IceSound.shared.play(.door, volume: 0.7)
        withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) { custX = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { phase = .waiting }
            Sound.shared.play(.bubble, volume: 0.6)
        }
    }

    private func tickle() {
        guard phase == .waiting else { return }
        Sound.shared.play(.boing, volume: 0.7)
        Sound.shared.tap()
        eyes = "happy"
        mouth = "open"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if phase == .waiting { eyes = "open"; mouth = "smile" }
        }
    }

    private func serve() {
        guard phase == .waiting, let b = sim.serve() else { return }
        IceSound.shared.play(.bell, volume: 0.8)
        Sound.shared.tap()
        let s = order.stars(for: b)
        if !demoServe {
            store.recordServe(hearts: s)
        }
        phase = .eating
        eyes = "happy"
        mouth = "open"
        for k in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(k) * 0.6) {
                IceSound.shared.play(b.kind == .smoothie ? .slurp : .nom)
                Sound.shared.tap()
                mouth = "chew"
                sim.bites = k
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { mouth = "open" }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            sim.served = nil
            Coins.shared.earn(Coins.reward(stars: s), game: IceSim.gameID, from: CGPoint(x: ICGeo.customer.x, y: ICGeo.customer.y - 20))
            if !demoServe && !sim.demo {
                for find in IceCreamFind.earned(for: b, stars: s, totalServed: store.served) {
                    StickerBook.shared.find(game: IceSim.gameID, id: find.rawValue)
                }
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                stars = s
                phase = .happy
            }
            eyes = s == 3 ? "star" : "happy"
            mouth = "open"
            IceSound.shared.play(.yay)
            Sound.shared.play(s == 3 ? .fanfare : .cheer, volume: 0.7)
            floating = 2 + s * 2
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { jarBounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { jarBounce = false }
            }
            if !demoServe { DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { leave() } }
        }
    }

    private func leave() {
        withAnimation(.easeOut(duration: 0.25)) { phase = .leaving }
        floating = 0
        Sound.shared.play(.whoosh, volume: 0.5)
        withAnimation(.easeIn(duration: 0.6)) { custX = -700 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            var next = Int.random(in: 0..<BakeryPalette.customers.count)
            if next == order.customer { next = (next + 1) % BakeryPalette.customers.count }
            order = ICOrder.random(customer: next, kind: kindFor(station))
            picture = order.picture()
            phase = .arriving
            arrive()
        }
    }

    private func blinkLoop() async {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.2...4.2) * 1_000_000_000))
            if eyes == "open" {
                eyes = "blink"
                try? await Task.sleep(nanoseconds: 140_000_000)
                if eyes == "blink" { eyes = "open" }
            }
        }
    }

    // MARK: Screenshot hooks

    /// -iceDemo scoop | soft | blend | pour | sundae | bingsu | serve. Freezes the shop mid-action; nothing is saved.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-iceDemo"), i + 1 < args.count else { return }
        sim.demo = true
        Coins.shared.demo = true
        let what = args[i + 1]
        let dt: CGFloat = 1.0 / 60
        func run(_ seconds: CGFloat) { for _ in 0..<Int(seconds * 60) { sim.step(dt: dt) } }
        switch what {
        case "scoop":
            station = .scoop
            sim.setStation(.scoop)
            order = ICOrder.random(customer: 1, seed: 21, kind: .scoops)
            picture = order.picture()
            sim.placeBase(.waffle)
            sim.dropScoop(flavor: .strawberry, swirl: nil, size: 1, dx: 0, fromY: 300)
            run(1.2)
            let c = ICGeo.tubs[1]
            sim.pickUp(.scoop, at: CGPoint(x: c.x - 40, y: c.y))
            for k in 0..<50 {
                let a = CGFloat(k) / 50 * 2.6
                sim.carry(to: CGPoint(x: c.x - 40 + cos(a) * -30 + CGFloat(k) * 1.4, y: c.y + sin(a) * 10), finger: CGPoint(x: c.x, y: c.y + 120))
                sim.step(dt: dt)
            }
            sim.frozen = true
        case "soft":
            station = .soft
            sim.setStation(.soft)
            order = ICOrder.random(customer: 1, seed: 21, kind: .soft)
            picture = order.picture()
            sim.placeBase(.waffle)
            run(0.6)
            sim.pressLever(2)
            run(2.6)
            sim.frozen = true
        case "blend", "pour":
            station = .smoothie
            sim.setStation(.smoothie)
            order = ICOrder.random(customer: 1, seed: 21, kind: .smoothie)
            picture = order.picture()
            for f in [ICFruit.strawberry, .strawberry, .banana, .banana, .blueberry, .strawberry, .ice, .mango] {
                sim.dropFruit(f, at: CGPoint(x: sim.jarP.x + CGFloat.random(in: -30...30), y: sim.jarP.y - ICGeo.jarH - 40), v: CGVector(dx: 0, dy: 100))
                run(0.25)
            }
            sim.pickUp(.milk, at: ICGeo.milkHome)
            sim.carry(to: CGPoint(x: sim.jarP.x + 30, y: sim.jarP.y - ICGeo.jarH - 50), finger: CGPoint(x: sim.jarP.x + 30, y: 300))
            run(1.2)
            sim.release()
            run(0.5)
            sim.blending = true
            run(what == "blend" ? 1.2 : 4.5)
            if what == "pour" {
                sim.blending = false
                run(1.0)
                sim.pickUp(.jar, at: sim.jarP)
                let at = CGPoint(x: sim.S.x - 150, y: sim.S.y - 170)
                for _ in 0..<70 {
                    sim.carry(to: at, finger: CGPoint(x: at.x, y: at.y + 180))
                    sim.step(dt: dt)
                }
            }
            sim.frozen = true
        case "sundae":
            station = .scoop
            sim.setStation(.scoop)
            order = ICOrder.random(customer: 1, seed: 21, kind: .scoops)
            picture = order.picture()
            sim.placeBase(.choco)
            for (k, f) in [ICFlavor.chocolate, .vanilla, .strawberry].enumerated() {
                sim.dropScoop(flavor: f, swirl: k == 1 ? .blueberry : nil, size: 1 - CGFloat(k) * 0.15, dx: 0, fromY: 200)
                run(0.9)
            }
            sim.autoTopping(.chocoSauce)
            run(2.5)
            sim.autoTopping(.sprinkles)
            run(1.5)
            sim.autoTopping(.whip)
            sim.autoTopping(.cherry)
            sim.autoTopping(.wafer)
            run(2)
            sim.frozen = true
        case "bingsu":
            station = .bingsu
            sim.setStation(.bingsu)
            order = ICOrder.random(customer: 1, seed: 21, kind: .bingsu)
            picture = order.picture()
            sim.pressShaver(true)
            run(2.1)
            sim.pressShaver(false)
            sim.autoTopping(.condensedMilk)
            run(1.8)
            sim.autoTopping(.redBean)
            sim.autoTopping(.strawberries)
            sim.autoTopping(.mangoCubes)
            run(0.6)
            sim.frozen = true
        case "serve":
            demoServe = true
            order = ICOrder.random(customer: 1, seed: 21, kind: kindFor(station))
            picture = order.picture()
            sim.placeBase(order.base)
            sim.autoTopping(.sprinkles)
            run(0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                phase = .waiting
                sim.order = order
                sim.build = order.picture()
                sim.build.picture = false
                serve()
            }
        default:
            break
        }
    }
}

// MARK: - Order card pieces

/// The dreamed-of treat, drawn once.
private struct ICPictureView: View, Equatable {
    let build: ICBuild

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let top = (build.profile.max() ?? 0) + (build.cherry != nil ? 30 : 0) + (build.straw != nil ? 40 : 0) + (build.wafer != nil ? 50 : 0)
            let depth = build.base?.depth ?? 120
            let total = max(120, top + depth + 20)
            let k = min(0.6, size.height / total)
            g.translateBy(x: size.width / 2, y: size.height - (depth + 14) * k)
            g.scaleBy(x: k, y: k)
            ICArt.drawBuild(g, build, at: .zero, time: 0)
        }
    }
}

/// The three parts of the order, each ticked green once the treat on the stand matches it.
private struct ICOrderParts: View {
    let order: ICOrder
    let sim: IceSim

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { _ in
            VStack(spacing: 5) {
                ForEach(Array(ICOrder.Part.allCases.enumerated()), id: \.offset) { _, part in
                    let ok = order.matches(part, sim.build)
                    ZStack {
                        Circle().fill(ok ? Color(hex: 0xD7F5DD) : Color(hex: 0xFFF1F6))
                        Canvas { ctx, size in
                            var g = ctx
                            g.translateBy(x: size.width / 2, y: size.height / 2)
                            ICOrderParts.icon(g, part, order)
                        }
                        if ok {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(Color(hex: 0x3EBE5E))
                                .background(Circle().fill(.white))
                                .offset(x: 13, y: -11)
                        }
                    }
                    .frame(width: 38, height: 38)
                }
            }
        }
    }

    static func icon(_ g: GraphicsContext, _ p: ICOrder.Part, _ o: ICOrder) {
        switch p {
        case .base:
            var b = ICBuild()
            b.base = o.base
            if o.kind == .bingsu { b.snowLevel = 0.9 }
            var c = g
            let k: CGFloat = o.base == .glass ? 0.2 : (o.base == .bowl ? 0.16 : 0.22)
            c.translateBy(x: 0, y: o.base == .bowl ? 4 : -o.base.depth * k * 0.5)
            c.scaleBy(x: k, y: k)
            ICArt.drawBuild(c, b, at: .zero, time: 0)
        case .flavor:
            let colors: [ICColor]
            switch o.kind {
            case .scoops: colors = o.flavors.map { (ICFlavor(rawValue: $0) ?? .vanilla).color }
            case .soft:
                let f = ICSoft(rawValue: o.flavors.first ?? 0) ?? .vanilla
                colors = f.colors.0 == f.colors.1 ? [f.colors.0] : [f.colors.0, f.colors.1]
            case .smoothie:
                for (i, f) in o.flavors.enumerated() {
                    let fr = ICFruit(rawValue: f) ?? .strawberry
                    let x = o.flavors.count == 1 ? 0 : (i == 0 ? -7 : 7)
                    ICArt.fruit(g, fr, at: CGPoint(x: CGFloat(x), y: 0), r: fr == .blueberry ? 8 : 10, rot: 0, seed: i)
                }
                return
            case .bingsu:
                let hero = ICBingsuHero(rawValue: o.flavors.first ?? 0) ?? .redBean
                var c = g
                c.scaleBy(x: 0.52, y: 0.52)
                ICArt.bingsuCluster(c, hero.topping)
                return
            }
            for (i, c) in colors.enumerated() {
                let x: CGFloat = colors.count == 1 ? 0 : (i == 0 ? -6 : 6)
                let ball = ICArt.circle(CGPoint(x: x, y: 0), 10)
                ICArt.ballFill(g, ball, CGPoint(x: x, y: 0), 10, c)
                g.stroke(ball, with: .color(ICArt.outline(c)), lineWidth: 1.5)
            }
        case .topping:
            var c = g
            switch o.topping {
            case .cherry:
                c.translateBy(x: 0, y: 6)
                c.scaleBy(x: 0.8, y: 0.8)
            case .wafer:
                c.translateBy(x: 0, y: 14)
                c.scaleBy(x: 0.3, y: 0.3)
            case .straw:
                c.translateBy(x: -4, y: 14)
                c.scaleBy(x: 0.18, y: 0.18)
            case .redBean, .mangoCubes, .strawberries, .injeolmi:
                c.scaleBy(x: 0.48, y: 0.48)
            default:
                c.translateBy(x: 0, y: 15)
                c.scaleBy(x: 0.2, y: 0.2)
            }
            ICScene.topping(c, o.topping, held: false)
        }
    }
}

private struct ICFloatingHeart: View {
    let index: Int
    @State private var go = false

    var body: some View {
        let dx = CGFloat((index * 37) % 120) - 60
        Image(systemName: "heart.fill")
            .font(.system(size: CGFloat(30 + (index % 3) * 8), weight: .black))
            .foregroundStyle(index % 2 == 0 ? Theme.pink : Color(hex: 0xFF6FA8))
            .offset(x: go ? dx * 1.4 : dx * 0.3, y: go ? -220 : 0)
            .opacity(go ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).delay(Double(index) * 0.12)) { go = true }
            }
    }
}
