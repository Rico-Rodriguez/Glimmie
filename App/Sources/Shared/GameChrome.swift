import SwiftUI

enum GameChromeLayout {
    static let width: CGFloat = 1024
    static let height: CGFloat = 834
    static let topBarY: CGFloat = 50
    static let homeCenter = CGPoint(x: 54, y: 50)
    static let stickerTarget = CGPoint(x: 132, y: 50)
    static let buttonSize: CGFloat = 64
    static let dockY: CGFloat = 768
}

enum StorybookArt {
    private static func rgb(_ hex: UInt32) -> (Double, Double, Double) {
        (
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    static func color(_ hex: UInt32, alpha: Double = 1) -> Color {
        Color(hex: hex, alpha: alpha)
    }

    /// Derives a darker, slightly warmer sRGB outline from `hex` so outlines stay storybook-soft and never black.
    static func outline(for hex: UInt32, factor: Double = 0.62) -> Color {
        let (r, g, b) = rgb(hex)
        let k = max(0, min(1, factor))
        return Color(
            .sRGB,
            red: min(1, max(0.18, r * k + 0.04)),
            green: min(1, max(0.12, g * k * 0.96)),
            blue: min(1, max(0.14, b * k * 0.92)),
            opacity: 1
        )
    }

    static func shade(for hex: UInt32, factor: Double = 0.86) -> Color {
        let (r, g, b) = rgb(hex)
        let k = max(0, min(1, factor))
        return Color(.sRGB, red: r * k, green: g * k, blue: b * k, opacity: 1)
    }

    static func tint(for hex: UInt32, amount: Double = 0.32) -> Color {
        let (r, g, b) = rgb(hex)
        let a = max(0, min(1, amount))
        return Color(
            .sRGB,
            red: r + (1 - r) * a,
            green: g + (1 - g) * a,
            blue: b + (1 - b) * a,
            opacity: 1
        )
    }

    static func fillAndStroke(
        _ g: GraphicsContext,
        _ path: Path,
        fill: Color,
        stroke: Color,
        width: CGFloat = 3
    ) {
        g.fill(path, with: .color(fill))
        g.stroke(path, with: .color(stroke), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    static func shape(_ g: GraphicsContext, _ path: Path, hex: UInt32, width: CGFloat = 3) {
        fillAndStroke(g, path, fill: color(hex), stroke: outline(for: hex), width: width)
    }

    static func highlight(_ g: GraphicsContext, in rect: CGRect, opacity: Double = 0.45) {
        g.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
    }

    static func sparkle(
        _ g: GraphicsContext,
        at center: CGPoint,
        radius: CGFloat,
        color: Color = Theme.lemon,
        opacity: Double = 1
    ) {
        var p = Path()
        let k = radius * 0.22
        p.move(to: CGPoint(x: center.x, y: center.y - radius))
        p.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + k, y: center.y - k))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x + k, y: center.y + k))
        p.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - k, y: center.y + k))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x - k, y: center.y - k))
        p.closeSubpath()
        g.fill(p, with: .color(color.opacity(opacity)))
    }

    static func heart(
        _ g: GraphicsContext,
        at center: CGPoint,
        size: CGFloat,
        color: Color = Theme.pink,
        opacity: Double = 1
    ) {
        let r = size * 0.5
        let cx = center.x, cy = center.y
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - r * 0.25))
        p.addCurve(
            to: CGPoint(x: cx + r, y: cy - r * 0.15),
            control1: CGPoint(x: cx + r * 0.35, y: cy - r * 1.05),
            control2: CGPoint(x: cx + r * 1.08, y: cy - r * 0.82)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy + r * 0.88),
            control1: CGPoint(x: cx + r * 0.96, y: cy + r * 0.35),
            control2: CGPoint(x: cx + r * 0.35, y: cy + r * 0.65)
        )
        p.addCurve(
            to: CGPoint(x: cx - r, y: cy - r * 0.15),
            control1: CGPoint(x: cx - r * 0.35, y: cy + r * 0.65),
            control2: CGPoint(x: cx - r * 0.96, y: cy + r * 0.35)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy - r * 0.25),
            control1: CGPoint(x: cx - r * 1.08, y: cy - r * 0.82),
            control2: CGPoint(x: cx - r * 0.35, y: cy - r * 1.05)
        )
        p.closeSubpath()
        g.fill(p, with: .color(color.opacity(opacity)))
    }

    static func thoughtBubble(
        _ g: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        tailToward: CGPoint
    ) {
        // Stroke all overlapping puffs at 2x width first, then fill white on top so the outer contour stays crisp with zero inner seams.
        var puffs: [Path] = []
        let count = 6
        let ring = radius * 0.44
        let puffR = radius * 0.54
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * 2 * .pi - .pi / 6
            let px = center.x + cos(a) * ring * 1.05
            let py = center.y + sin(a) * ring * 0.94
            puffs.append(Path(ellipseIn: CGRect(x: px - puffR, y: py - puffR, width: puffR * 2, height: puffR * 2)))
        }
        let coreR = radius * 0.78
        puffs.append(Path(ellipseIn: CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)))

        let outlineStyle = StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
        for p in puffs {
            g.stroke(p, with: .color(Theme.blush), style: outlineStyle)
        }
        for p in puffs {
            g.fill(p, with: .color(.white))
        }

        let dx = tailToward.x - center.x
        let dy = tailToward.y - center.y
        let dist = hypot(dx, dy)
        let ux: CGFloat = dist > 1 ? dx / dist : 0
        let uy: CGFloat = dist > 1 ? dy / dist : 1

        let r1 = max(6, radius * 0.18)
        let r2 = max(4.5, radius * 0.12)
        let d1 = radius * 1.2
        let d2 = d1 + r1 + r2 + max(4, radius * 0.08)

        let dot1Center = CGPoint(x: center.x + ux * d1, y: center.y + uy * d1)
        let dot2Center = CGPoint(x: center.x + ux * d2, y: center.y + uy * d2)
        let dot1 = Path(ellipseIn: CGRect(x: dot1Center.x - r1, y: dot1Center.y - r1, width: r1 * 2, height: r1 * 2))
        let dot2 = Path(ellipseIn: CGRect(x: dot2Center.x - r2, y: dot2Center.y - r2, width: r2 * 2, height: r2 * 2))
        fillAndStroke(g, dot1, fill: .white, stroke: Theme.blush, width: 3.5)
        fillAndStroke(g, dot2, fill: .white, stroke: Theme.blush, width: min(3.5, max(2.5, r2 * 0.6)))
    }
}

struct GameStageMap {
    let scale: CGFloat
    let origin: CGPoint
    let size: CGSize

    init(size: CGSize) {
        self.size = size
        let s = max(0.1, min(size.width / GameChromeLayout.width, size.height / GameChromeLayout.height))
        self.scale = s
        self.origin = CGPoint(
            x: (size.width - GameChromeLayout.width * s) / 2,
            y: (size.height - GameChromeLayout.height * s) / 2
        )
    }

    func screen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
    }

    func design(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - origin.x) / scale, y: (p.y - origin.y) / scale)
    }
}

struct GameStage<Background: View, Content: View>: View {
    let background: () -> Background
    let content: () -> Content

    init(
        @ViewBuilder background: @escaping () -> Background,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.background = background
        self.content = content
    }

    var body: some View {
        ZStack {
            background().ignoresSafeArea()
            DesignCanvas {
                content()
                    .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
            }
        }
    }
}

struct GameTopBar<Center: View, Trailing: View>: View {
    let gameID: String
    let showStickerBook: Bool
    let showCoins: Bool
    let onExit: () -> Void
    let onStickerBook: (() -> Void)?
    let center: () -> Center
    let trailing: () -> Trailing

    init(
        gameID: String,
        showStickerBook: Bool = false,
        showCoins: Bool = false,
        onExit: @escaping () -> Void,
        onStickerBook: (() -> Void)? = nil,
        @ViewBuilder center: @escaping () -> Center,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.gameID = gameID
        self.showStickerBook = showStickerBook
        self.showCoins = showCoins
        self.onExit = onExit
        self.onStickerBook = onStickerBook
        self.center = center
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 14) {
            HomeButton(size: GameChromeLayout.buttonSize, action: onExit)
            if showStickerBook, let onStickerBook {
                StickerBookButton(game: gameID, size: GameChromeLayout.buttonSize, action: onStickerBook)
            }
            Spacer()
            center()
            Spacer()
            if showCoins {
                CoinCounter(game: gameID, height: GameChromeLayout.buttonSize)
            }
            trailing()
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

extension GameTopBar where Center == EmptyView, Trailing == EmptyView {
    init(
        gameID: String,
        showStickerBook: Bool = false,
        showCoins: Bool = false,
        onExit: @escaping () -> Void,
        onStickerBook: (() -> Void)? = nil
    ) {
        self.init(
            gameID: gameID,
            showStickerBook: showStickerBook,
            showCoins: showCoins,
            onExit: onExit,
            onStickerBook: onStickerBook,
            center: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}

extension GameTopBar where Center == EmptyView {
    init(
        gameID: String,
        showStickerBook: Bool = false,
        showCoins: Bool = false,
        onExit: @escaping () -> Void,
        onStickerBook: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.init(
            gameID: gameID,
            showStickerBook: showStickerBook,
            showCoins: showCoins,
            onExit: onExit,
            onStickerBook: onStickerBook,
            center: { EmptyView() },
            trailing: trailing
        )
    }
}

extension GameTopBar where Trailing == EmptyView {
    init(
        gameID: String,
        showStickerBook: Bool = false,
        showCoins: Bool = false,
        onExit: @escaping () -> Void,
        onStickerBook: (() -> Void)? = nil,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self.init(
            gameID: gameID,
            showStickerBook: showStickerBook,
            showCoins: showCoins,
            onExit: onExit,
            onStickerBook: onStickerBook,
            center: center,
            trailing: { EmptyView() }
        )
    }
}

struct GameTrayCard<Content: View>: View {
    var cornerRadius: CGFloat = 32
    var paddingH: CGFloat = 14
    var paddingV: CGFloat = 10
    let content: () -> Content

    init(
        cornerRadius: CGFloat = 32,
        paddingH: CGFloat = 14,
        paddingV: CGFloat = 10,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.paddingH = paddingH
        self.paddingV = paddingV
        self.content = content
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content()
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background(shape.fill(Theme.cream.opacity(0.96)))
            .overlay(shape.stroke(Theme.blush, lineWidth: 3.5))
            .shadow(color: Theme.ink.opacity(0.16), radius: 10, y: 5)
    }
}

struct GameDockTile<Icon: View>: View {
    var size: CGFloat = 82
    var selected: Bool = false
    var pulsing: Bool = false
    var tint: Color = .white
    var cornerRadius: CGFloat = 24
    let icon: () -> Icon

    init(
        size: CGFloat = 82,
        selected: Bool = false,
        pulsing: Bool = false,
        tint: Color = .white,
        cornerRadius: CGFloat = 24,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.size = size
        self.selected = selected
        self.pulsing = pulsing
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.icon = icon
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !pulsing)) { tl in
            let bob: CGFloat = pulsing ? CGFloat(sin(tl.date.timeIntervalSinceReferenceDate * 4.5) * 3.5) : 0
            ZStack {
                shape.fill(tint)
                icon()
            }
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay(shape.stroke(selected ? Theme.pink : Theme.blush, lineWidth: selected ? 4.5 : 2.5))
            .shadow(color: Theme.ink.opacity(selected ? 0.22 : 0.12), radius: selected ? 7 : 4, y: selected ? 4 : 2)
            .scaleEffect(selected ? 1.07 : 1)
            .offset(y: bob)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: selected)
        }
    }
}

struct ReturnDropBadge: View {
    let hovered: Bool

    init(hovered: Bool) {
        self.hovered = hovered
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(hovered ? Theme.pink : Theme.peach)
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 72, height: 72)
        .overlay(Circle().stroke(.white, lineWidth: 4))
        .shadow(color: Theme.ink.opacity(hovered ? 0.28 : 0.18), radius: hovered ? 10 : 6, y: 4)
        .scaleEffect(hovered ? 1.16 : 1)
        .animation(.spring(response: 0.26, dampingFraction: 0.65), value: hovered)
    }
}

struct PictorialWishBubble<Content: View>: View {
    var size: CGFloat = 86
    let content: () -> Content
    @State private var bob = false

    init(size: CGFloat = 86, @ViewBuilder content: @escaping () -> Content) {
        self.size = size
        self.content = content
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.white)
                content()
                    .padding(size * 0.14)
            }
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Theme.blush, lineWidth: 3.5))
            .shadow(color: Theme.ink.opacity(0.14), radius: 8, y: 4)

            Circle()
                .fill(.white)
                .frame(width: size * 0.18, height: size * 0.18)
                .overlay(Circle().stroke(Theme.blush, lineWidth: 2.5))
                .offset(x: -size * 0.08)

            Circle()
                .fill(.white)
                .frame(width: size * 0.11, height: size * 0.11)
                .overlay(Circle().stroke(Theme.blush, lineWidth: 2))
                .offset(x: -size * 0.17)
        }
        .offset(y: bob ? -4 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
    }
}
