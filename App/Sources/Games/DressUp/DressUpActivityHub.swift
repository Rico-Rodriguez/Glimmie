import SwiftUI

enum DressUpActivity: String, CaseIterable, Identifiable {
    case makeup
    case nails
    case pets
    case playhouse
    case runway
    case gallery

    var id: String { rawValue }

    var beautyMode: BeautyWorld.Mode? {
        switch self {
        case .makeup: return .makeup
        case .nails: return .nails
        default: return nil
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .makeup: return "Makeup Studio"
        case .nails: return "Nail Salon"
        case .pets: return "My Pet"
        case .playhouse: return "Backyard Playhouse"
        case .runway: return "Fashion Runway"
        case .gallery: return "Photo Album"
        }
    }
}

/// Custom magic star + pastel playhouse emblem for the bottom-stage Activities pill.
struct PlayHubButtonArt: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // Soft pastel playhouse on the left half
            let houseX = w * 0.34
            let houseBaseY = h * 0.78
            let houseW = w * 0.30
            let houseH = h * 0.34

            let walls = Path(roundedRect: CGRect(x: houseX - houseW * 0.5, y: houseBaseY - houseH, width: houseW, height: houseH), cornerRadius: 5)
            StorybookArt.fillAndStroke(ctx, walls, fill: Color(hex: 0xFFF9EE), stroke: Color(hex: 0x7A4E8F), width: 2.6)

            var roof = Path()
            roof.move(to: CGPoint(x: houseX - houseW * 0.68, y: houseBaseY - houseH + 3))
            roof.addLine(to: CGPoint(x: houseX, y: houseBaseY - houseH - h * 0.24))
            roof.addLine(to: CGPoint(x: houseX + houseW * 0.68, y: houseBaseY - houseH + 3))
            roof.closeSubpath()
            StorybookArt.fillAndStroke(ctx, roof, fill: Color(hex: 0xFF84B7), stroke: Color(hex: 0x7A4E8F), width: 2.6)

            let doorW = houseW * 0.34
            let doorH = houseH * 0.62
            let door = Path(roundedRect: CGRect(x: houseX - doorW * 0.5, y: houseBaseY - doorH, width: doorW, height: doorH), cornerRadius: doorW * 0.5)
            StorybookArt.fillAndStroke(ctx, door, fill: Color(hex: 0xFFE28A), stroke: Color(hex: 0x7A4E8F), width: 2)

            // Big gleaming magic star on the right half
            let starCenter = CGPoint(x: w * 0.72, y: h * 0.46)
            let star = DressUpCulturalOutfits.starPath(center: starCenter, outer: h * 0.30, inner: h * 0.14)
            StorybookArt.fillAndStroke(ctx, star, fill: Color(hex: 0xFFE678), stroke: Color(hex: 0xD98B2B), width: 2.6)
            StorybookArt.highlight(ctx, in: CGRect(x: starCenter.x - 6, y: starCenter.y - 8, width: 8, height: 5), opacity: 0.75)

            // Floating twinkles tying the playhouse and star together
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.54, y: h * 0.24), radius: 7, color: .white)
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.88, y: h * 0.72), radius: 5.5, color: Theme.lemon)
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.14, y: h * 0.30), radius: 5, color: Theme.lemon)
        }
    }
}

/// Joyful zero-text 2x3 visual activity chooser for Makeup, Nails, Pets, Backyard Playhouse, Runway, and Photo Album.
struct DressUpActivityHub: View {
    let look: Look
    let latestPhoto: Look?
    let hasGalleryItems: Bool
    let close: () -> Void
    let select: (DressUpActivity) -> Void

    private let columns = Array(repeating: GridItem(.fixed(242), spacing: 20), count: 3)

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    Sound.shared.play(.whoosh, volume: 0.55)
                    close()
                }

            DesignCanvas {
                VStack(spacing: 20) {
                    HStack {
                        Color.clear.frame(width: 58, height: 58)
                        Spacer()
                        hubHeaderEmblem
                        Spacer()
                        RoundButton(symbol: "xmark", tint: Theme.pink, size: 58) {
                            Sound.shared.play(.whoosh, volume: 0.6)
                            close()
                        }
                        .accessibilityLabel("Close")
                    }
                    .frame(width: 766)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(DressUpActivity.allCases) { activity in
                            activityCard(activity)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 24)
                .padding(.bottom, 30)
                .background(
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .fill(Theme.cream.opacity(0.98))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .stroke(Theme.blush, lineWidth: 5)
                )
                .shadow(color: Theme.ink.opacity(0.24), radius: 22, y: 10)
            }
        }
    }

    private var hubHeaderEmblem: some View {
        HStack(spacing: 12) {
            Twinkle().fill(Theme.lemon).frame(width: 24, height: 24)
            Twinkle().fill(Theme.pink).frame(width: 34, height: 34)
            Twinkle().fill(Theme.sky).frame(width: 24, height: 24)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Capsule().fill(.white.opacity(0.9)))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 3))
    }

    private func activityCard(_ activity: DressUpActivity) -> some View {
        let style = cardStyle(for: activity)
        return Button {
            Sound.shared.tap()
            select(activity)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [style.top, style.bottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                cardIllustration(activity)
                    .padding(10)
            }
            .frame(width: 242, height: 204)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(style.border, lineWidth: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.65), lineWidth: 2.5)
                    .padding(4)
            )
            .shadow(color: style.border.opacity(0.28), radius: 10, y: 5)
            .overlay(alignment: .topTrailing) {
                if activity == .gallery && hasGalleryItems {
                    ZStack {
                        Circle().fill(Color(hex: 0xF45C9A))
                        Image(systemName: "sparkle")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.lemon)
                    }
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: Theme.ink.opacity(0.22), radius: 4, y: 2)
                    .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(Squish())
        .accessibilityLabel(activity.accessibilityLabel)
    }

    private func cardStyle(for activity: DressUpActivity) -> (top: Color, bottom: Color, border: Color) {
        switch activity {
        case .makeup:
            return (Color(hex: 0xFFEAF3), Color(hex: 0xFFD0E5), Color(hex: 0xF45C9A))
        case .nails:
            return (Color(hex: 0xF4EAFF), Color(hex: 0xE3D0FF), Color(hex: 0xA374E8))
        case .pets:
            return (Color(hex: 0xFFF3E2), Color(hex: 0xFFE0BD), Color(hex: 0xFFA24C))
        case .playhouse:
            return (Color(hex: 0xE6FBF1), Color(hex: 0xD2EEFF), Color(hex: 0x46BE9B))
        case .runway:
            return (Color(hex: 0xFFF7D6), Color(hex: 0xFFE1A8), Color(hex: 0xF2B83E))
        case .gallery:
            return (Color(hex: 0xE3F9F8), Color(hex: 0xCDECF9), Color(hex: 0x46B7B0))
        }
    }

    @ViewBuilder
    private func cardIllustration(_ activity: DressUpActivity) -> some View {
        switch activity {
        case .makeup:
            MakeupStudioCardArt()
        case .nails:
            NailSalonCardArt()
        case .pets:
            PetCornerCardArt(pet: look.pet ?? PetLook(kind: "puppy"))
        case .playhouse:
            PlayhouseCardArt()
        case .runway:
            RunwayCardArt()
        case .gallery:
            PhotoAlbumCardArt(look: latestPhoto ?? look)
        }
    }
}

// MARK: - Custom Storybook Activity Card Illustrations

private struct MakeupStudioCardArt: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // Soft white glow behind tools
            ctx.fill(
                Path(ellipseIn: CGRect(x: w * 0.08, y: h * 0.14, width: w * 0.84, height: h * 0.74)),
                with: .color(.white.opacity(0.55))
            )

            // Open Blush Compact on the left: upper lid with mirror
            let lidCenter = CGPoint(x: w * 0.34, y: h * 0.35)
            let lidR = min(w, h) * 0.22
            let lidOuter = Path(ellipseIn: CGRect(x: lidCenter.x - lidR, y: lidCenter.y - lidR * 0.82, width: lidR * 2, height: lidR * 1.64))
            StorybookArt.fillAndStroke(ctx, lidOuter, fill: Color(hex: 0xFF9AC5), stroke: StorybookArt.outline(for: 0xF45C9A), width: 3)

            let mirror = Path(ellipseIn: CGRect(x: lidCenter.x - lidR * 0.76, y: lidCenter.y - lidR * 0.60, width: lidR * 1.52, height: lidR * 1.20))
            StorybookArt.fillAndStroke(ctx, mirror, fill: Color(hex: 0xE6F4FF), stroke: .white, width: 2.5)
            var sheen = Path()
            sheen.move(to: CGPoint(x: lidCenter.x - lidR * 0.36, y: lidCenter.y + lidR * 0.25))
            sheen.addLine(to: CGPoint(x: lidCenter.x + lidR * 0.18, y: lidCenter.y - lidR * 0.32))
            ctx.stroke(sheen, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

            // Compact base with rosy blush powder pan
            let baseCenter = CGPoint(x: w * 0.34, y: h * 0.68)
            let baseOuter = Path(ellipseIn: CGRect(x: baseCenter.x - lidR * 1.06, y: baseCenter.y - lidR * 0.78, width: lidR * 2.12, height: lidR * 1.56))
            StorybookArt.fillAndStroke(ctx, baseOuter, fill: Color(hex: 0xFFF2F7), stroke: StorybookArt.outline(for: 0xF45C9A), width: 3)
            let pan = Path(ellipseIn: CGRect(x: baseCenter.x - lidR * 0.78, y: baseCenter.y - lidR * 0.56, width: lidR * 1.56, height: lidR * 1.12))
            StorybookArt.fillAndStroke(ctx, pan, fill: Color(hex: 0xFF7CA9), stroke: StorybookArt.outline(for: 0xE85A8B), width: 2.2)
            StorybookArt.highlight(ctx, in: CGRect(x: baseCenter.x - lidR * 0.45, y: baseCenter.y - lidR * 0.34, width: lidR * 0.55, height: lidR * 0.26), opacity: 0.48)

            // Glossy lipstick tilted on the right
            var lip = ctx
            lip.translateBy(x: w * 0.74, y: h * 0.55)
            lip.rotate(by: .degrees(14))

            let tube = Path(roundedRect: CGRect(x: -18, y: 2, width: 36, height: 50), cornerRadius: 9)
            StorybookArt.fillAndStroke(lip, tube, fill: Color(hex: 0xC9A8FF), stroke: StorybookArt.outline(for: 0x8F68D8), width: 3)
            let collar = Path(roundedRect: CGRect(x: -15, y: -18, width: 30, height: 22), cornerRadius: 5)
            StorybookArt.fillAndStroke(lip, collar, fill: Color(hex: 0xFFE07A), stroke: StorybookArt.outline(for: 0xD99A2E), width: 2.8)
            var bullet = Path()
            bullet.move(to: CGPoint(x: -11, y: -16))
            bullet.addLine(to: CGPoint(x: -11, y: -40))
            bullet.addQuadCurve(to: CGPoint(x: 11, y: -50), control: CGPoint(x: -2, y: -54))
            bullet.addLine(to: CGPoint(x: 11, y: -16))
            bullet.closeSubpath()
            StorybookArt.fillAndStroke(lip, bullet, fill: Color(hex: 0xF4508F), stroke: StorybookArt.outline(for: 0xC22D6A), width: 2.8)
            StorybookArt.highlight(lip, in: CGRect(x: -7, y: -42, width: 6, height: 18), opacity: 0.55)
            StorybookArt.highlight(lip, in: CGRect(x: -12, y: 10, width: 7, height: 32), opacity: 0.45)

            // Sparkles
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.14, y: h * 0.24), radius: 10, color: Theme.lemon)
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.87, y: h * 0.22), radius: 11, color: Theme.lemon)
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.60, y: h * 0.20), radius: 7, color: .white)
            StorybookArt.heart(ctx, at: CGPoint(x: w * 0.57, y: h * 0.78), size: 18, color: Color(hex: 0xF45C9A))
        }
    }
}

private struct NailSalonCardArt: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            ctx.fill(
                Path(ellipseIn: CGRect(x: w * 0.08, y: h * 0.14, width: w * 0.84, height: h * 0.74)),
                with: .color(.white.opacity(0.55))
            )

            let skinFill = Color(hex: 0xFFE2CE)
            let skinStroke = Color(hex: 0xB88573)

            // Cute chibi palm base
            let palm = Path(roundedRect: CGRect(x: w * 0.16, y: h * 0.55, width: w * 0.48, height: h * 0.36), cornerRadius: 28)
            StorybookArt.fillAndStroke(ctx, palm, fill: skinFill, stroke: skinStroke, width: 3)

            // Four fingers fanned up with painted pastel nails
            let fingers: [(x: CGFloat, topY: CGFloat, width: CGFloat, nailHex: UInt32, deco: Int)] = [
                (w * 0.21, h * 0.34, 24, 0xFF7EB3, 0),
                (w * 0.33, h * 0.22, 26, 0x7FC8FF, 1),
                (w * 0.45, h * 0.24, 26, 0xFFE066, 2),
                (w * 0.57, h * 0.36, 24, 0x8CE3C2, 1),
            ]
            for f in fingers {
                let fingerRect = CGRect(x: f.x - f.width * 0.5, y: f.topY, width: f.width, height: h * 0.64 - f.topY)
                let fingerPath = Path(roundedRect: fingerRect, cornerRadius: f.width * 0.5)
                StorybookArt.fillAndStroke(ctx, fingerPath, fill: skinFill, stroke: skinStroke, width: 2.8)

                let nailRect = CGRect(x: f.x - f.width * 0.38, y: f.topY + 2, width: f.width * 0.76, height: f.width * 1.05)
                let nailPath = Path(roundedRect: nailRect, cornerRadius: f.width * 0.38)
                StorybookArt.fillAndStroke(ctx, nailPath, fill: Color(hex: f.nailHex), stroke: StorybookArt.outline(for: f.nailHex), width: 2.2)
                StorybookArt.highlight(ctx, in: CGRect(x: nailRect.minX + 3, y: nailRect.minY + 4, width: 4.5, height: 10), opacity: 0.65)

                let mid = CGPoint(x: nailRect.midX, y: nailRect.midY + 2)
                if f.deco == 0 {
                    StorybookArt.heart(ctx, at: mid, size: 9, color: .white)
                } else if f.deco == 1 {
                    StorybookArt.sparkle(ctx, at: mid, radius: 5.5, color: .white)
                } else {
                    StorybookArt.heart(ctx, at: mid, size: 9, color: Color(hex: 0xFF6FA8))
                }
            }

            // Cover finger-to-palm seam softly
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.19, y: h * 0.57, width: w * 0.42, height: h * 0.28), cornerRadius: 20), with: .color(skinFill))

            // Glossy nail polish bottle on the right
            var bot = ctx
            bot.translateBy(x: w * 0.80, y: h * 0.64)
            bot.rotate(by: .degrees(8))
            let cap = Path(roundedRect: CGRect(x: -9, y: -44, width: 18, height: 26), cornerRadius: 5)
            StorybookArt.fillAndStroke(bot, cap, fill: Color(hex: 0x7A5796), stroke: StorybookArt.outline(for: 0x5B3A68), width: 2.4)
            let glass = Path(roundedRect: CGRect(x: -20, y: -20, width: 40, height: 42), cornerRadius: 12)
            StorybookArt.fillAndStroke(bot, glass, fill: Color(hex: 0xFF6CA8), stroke: StorybookArt.outline(for: 0xD63E7F), width: 2.8)
            StorybookArt.highlight(bot, in: CGRect(x: -14, y: -12, width: 7, height: 22), opacity: 0.6)

            // Sparkles
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.14, y: h * 0.24), radius: 9, color: Theme.lemon)
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.72, y: h * 0.22), radius: 11, color: Theme.lemon)
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.89, y: h * 0.34), radius: 7, color: .white)
        }
    }
}

private struct PetCornerCardArt: View {
    let pet: PetLook

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.72))
                .frame(width: 148, height: 148)
                .offset(x: -10, y: 4)

            PetThumb(pet: pet, pose: PetPose(eyes: "happy", mouth: "grin"))
                .frame(width: 158, height: 158)
                .offset(x: -10, y: 4)

            // Cute pastel paw heart badge in the bottom-right corner
            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                let cx = w * 0.80
                let cy = h * 0.74

                let badge = Path(ellipseIn: CGRect(x: cx - 28, y: cy - 28, width: 56, height: 56))
                StorybookArt.fillAndStroke(ctx, badge, fill: .white, stroke: Color(hex: 0xFFA24C), width: 3)

                // Three little toe beans + heart main pad
                let toes: [CGPoint] = [
                    CGPoint(x: cx - 12, y: cy - 9),
                    CGPoint(x: cx, y: cy - 14),
                    CGPoint(x: cx + 12, y: cy - 9),
                ]
                for t in toes {
                    ctx.fill(Path(ellipseIn: CGRect(x: t.x - 4.5, y: t.y - 5.5, width: 9, height: 11)), with: .color(Color(hex: 0xFF8FB8)))
                }
                StorybookArt.heart(ctx, at: CGPoint(x: cx, y: cy + 6), size: 22, color: Color(hex: 0xF45C9A))

                StorybookArt.heart(ctx, at: CGPoint(x: w * 0.84, y: h * 0.24), size: 20, color: Color(hex: 0xFF7CA8))
                StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.14, y: h * 0.24), radius: 9, color: Theme.lemon)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct PlayhouseCardArt: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // Sun in top-left
            let sun = Path(ellipseIn: CGRect(x: w * 0.08, y: h * 0.08, width: 34, height: 34))
            StorybookArt.fillAndStroke(ctx, sun, fill: Color(hex: 0xFFE378), stroke: Color(hex: 0xE6A93B), width: 2.5)

            // Soft cloud in top-right
            let puffs: [(CGFloat, CGFloat, CGFloat)] = [(0.58, 0.18, 16), (0.65, 0.15, 20), (0.73, 0.19, 15)]
            for (dx, dy, r) in puffs {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: w * dx - r, y: h * dy - r, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(0.88))
                )
            }

            // Grassy backyard hill
            let hill = Path(ellipseIn: CGRect(x: -w * 0.15, y: h * 0.72, width: w * 1.3, height: h * 0.52))
            StorybookArt.fillAndStroke(ctx, hill, fill: Color(hex: 0x9BE6AE), stroke: Color(hex: 0x58B478), width: 2.8)

            // Cute pastel playhouse on left-center
            let hx = w * 0.42
            let hy = h * 0.82
            let hw = w * 0.44
            let hh = h * 0.36

            let chimney = Path(roundedRect: CGRect(x: hx + hw * 0.18, y: hy - hh - h * 0.21, width: 16, height: 24), cornerRadius: 4)
            StorybookArt.fillAndStroke(ctx, chimney, fill: Color(hex: 0xFFB085), stroke: StorybookArt.outline(for: 0xE27B52), width: 2.5)

            let body = Path(roundedRect: CGRect(x: hx - hw * 0.5, y: hy - hh, width: hw, height: hh), cornerRadius: 10)
            StorybookArt.fillAndStroke(ctx, body, fill: Color(hex: 0xFFF7E4), stroke: Color(hex: 0xB88766), width: 3)

            var roof = Path()
            roof.move(to: CGPoint(x: hx - hw * 0.62, y: hy - hh + 4))
            roof.addLine(to: CGPoint(x: hx, y: hy - hh - h * 0.26))
            roof.addLine(to: CGPoint(x: hx + hw * 0.62, y: hy - hh + 4))
            roof.closeSubpath()
            StorybookArt.fillAndStroke(ctx, roof, fill: Color(hex: 0xFF8EB8), stroke: StorybookArt.outline(for: 0xDF588E), width: 3)

            // Cute arched door + round window
            let door = Path(roundedRect: CGRect(x: hx - 26, y: hy - hh * 0.68, width: 28, height: hh * 0.68), cornerRadius: 14)
            StorybookArt.fillAndStroke(ctx, door, fill: Color(hex: 0xFFD08A), stroke: Color(hex: 0xB87E43), width: 2.5)
            StorybookArt.heart(ctx, at: CGPoint(x: hx - 12, y: hy - hh * 0.42), size: 10, color: Color(hex: 0xF45C9A))

            let win = Path(ellipseIn: CGRect(x: hx + 10, y: hy - hh * 0.66, width: 26, height: 26))
            StorybookArt.fillAndStroke(ctx, win, fill: Color(hex: 0xB8E6FF), stroke: .white, width: 2.5)

            // Bouncy Keepy Uppy Balloon floating on the right
            let bx = w * 0.80
            let by = h * 0.42
            var stringPath = Path()
            stringPath.move(to: CGPoint(x: bx, y: by + 26))
            stringPath.addCurve(to: CGPoint(x: bx - 4, y: by + 68),
                                control1: CGPoint(x: bx + 12, y: by + 40),
                                control2: CGPoint(x: bx - 14, y: by + 54))
            ctx.stroke(stringPath, with: .color(Color(hex: 0x8F6B88)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            let balloon = Path(ellipseIn: CGRect(x: bx - 22, y: by - 26, width: 44, height: 52))
            StorybookArt.fillAndStroke(ctx, balloon, fill: Color(hex: 0xFF72A8), stroke: StorybookArt.outline(for: 0xD94580), width: 2.8)
            StorybookArt.highlight(ctx, in: CGRect(x: bx - 13, y: by - 16, width: 10, height: 16), opacity: 0.6)

            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.88, y: h * 0.18), radius: 9, color: Theme.lemon)
        }
    }
}

private struct RunwayCardArt: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // Twin glowing spotlight beams
            var beamL = Path()
            beamL.move(to: CGPoint(x: w * 0.10, y: 0))
            beamL.addLine(to: CGPoint(x: w * 0.28, y: 0))
            beamL.addLine(to: CGPoint(x: w * 0.72, y: h))
            beamL.addLine(to: CGPoint(x: w * 0.34, y: h))
            beamL.closeSubpath()
            ctx.fill(beamL, with: .color(.white.opacity(0.36)))

            var beamR = Path()
            beamR.move(to: CGPoint(x: w * 0.72, y: 0))
            beamR.addLine(to: CGPoint(x: w * 0.90, y: 0))
            beamR.addLine(to: CGPoint(x: w * 0.66, y: h))
            beamR.addLine(to: CGPoint(x: w * 0.28, y: h))
            beamR.closeSubpath()
            ctx.fill(beamR, with: .color(.white.opacity(0.36)))

            // Rosy perspective runway carpet
            var carpet = Path()
            carpet.move(to: CGPoint(x: w * 0.36, y: h * 0.56))
            carpet.addLine(to: CGPoint(x: w * 0.64, y: h * 0.56))
            carpet.addLine(to: CGPoint(x: w * 0.86, y: h * 0.96))
            carpet.addLine(to: CGPoint(x: w * 0.14, y: h * 0.96))
            carpet.closeSubpath()
            StorybookArt.fillAndStroke(ctx, carpet, fill: Color(hex: 0xFF79AD), stroke: Color(hex: 0xF2B83E), width: 3.5)

            // Shining runway star on carpet
            let carpetStar = DressUpCulturalOutfits.starPath(center: CGPoint(x: w * 0.50, y: h * 0.78), outer: 18, inner: 8.5)
            StorybookArt.fillAndStroke(ctx, carpetStar, fill: Color(hex: 0xFFE678), stroke: Color(hex: 0xD98B2B), width: 2.2)

            // Big gleaming golden crown floating in the spotlight
            let cx = w * 0.50
            let cy = h * 0.44
            var crown = Path()
            crown.move(to: CGPoint(x: cx - 44, y: cy + 16))
            crown.addLine(to: CGPoint(x: cx - 50, y: cy - 22))
            crown.addLine(to: CGPoint(x: cx - 22, y: cy - 2))
            crown.addLine(to: CGPoint(x: cx, y: cy - 34))
            crown.addLine(to: CGPoint(x: cx + 22, y: cy - 2))
            crown.addLine(to: CGPoint(x: cx + 50, y: cy - 22))
            crown.addLine(to: CGPoint(x: cx + 44, y: cy + 16))
            crown.closeSubpath()
            StorybookArt.fillAndStroke(ctx, crown, fill: Color(hex: 0xFFD95E), stroke: Color(hex: 0xC98824), width: 3.2)

            // Jewels on the crown band
            let jewels: [(CGFloat, UInt32)] = [(-22, 0xFF6CA8), (0, 0x7FC8FF), (22, 0x92E3C4)]
            for (dx, hex) in jewels {
                let gem = Path(ellipseIn: CGRect(x: cx + dx - 6, y: cy - 2, width: 12, height: 12))
                StorybookArt.fillAndStroke(ctx, gem, fill: Color(hex: hex), stroke: .white, width: 2)
            }

            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.18, y: h * 0.30), radius: 11, color: .white)
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.82, y: h * 0.28), radius: 11, color: Theme.lemon)
            StorybookArt.sparkle(ctx, at: CGPoint(x: w * 0.50, y: h * 0.12), radius: 8, color: .white)
        }
    }
}

private struct PhotoAlbumCardArt: View {
    let look: Look

    var body: some View {
        ZStack {
            // Back tilted lilac polaroid
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0xFFF7FC))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(hex: 0xE3D5FF))
                        .padding(.top, 10)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 28)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: 0xC6B2EC), lineWidth: 3)
                )
                .frame(width: 116, height: 136)
                .rotationEffect(.degrees(-12))
                .offset(x: -24, y: 2)

            // Front crisp polaroid with live doll portrait
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xFFEBF4), Color(hex: 0xDFF3FF)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    DollView(look: look, expression: .happy, box: CGRect(x: 118, y: 58, width: 364, height: 364))
                        .padding(3)
                }
                .frame(width: 100, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: 0xF45C9A))
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.lemon)
                }
                .padding(.bottom, 2)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: 0x7DC9C4), lineWidth: 3))
            .shadow(color: Theme.ink.opacity(0.16), radius: 8, y: 4)
            .rotationEffect(.degrees(6))
            .offset(x: 16, y: 2)

            // Floating sparkle accents
            Canvas { ctx, size in
                StorybookArt.sparkle(ctx, at: CGPoint(x: size.width * 0.16, y: size.height * 0.22), radius: 10, color: Theme.lemon)
                StorybookArt.sparkle(ctx, at: CGPoint(x: size.width * 0.86, y: size.height * 0.78), radius: 9, color: .white)
            }
            .allowsHitTesting(false)
        }
    }
}
