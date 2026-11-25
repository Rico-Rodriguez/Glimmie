import SwiftUI

enum PaintMix {
    /// Mixes colors as paint, weighted by drops (Kubelka-Munk pigment mixing).
    static func mix(_ parts: [(RGB, Double)]) -> RGB {
        let total = parts.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return Shades.white }
        func ks(_ r: Double) -> Double { let r = max(0.004, min(1, r)); return (1 - r) * (1 - r) / (2 * r) }
        func back(_ k: Double) -> Double { 1 + k - sqrt(k * k + 2 * k) }
        var k = (0.0, 0.0, 0.0)
        for (c, w) in parts {
            k.0 += ks(c.r) * w / total
            k.1 += ks(c.g) * w / total
            k.2 += ks(c.b) * w / total
        }
        return RGB(back(k.0), back(k.1), back(k.2))
    }

    static func hex(_ c: RGB) -> String {
        func h(_ v: Double) -> String {
            let n = Int((max(0, min(1, v)) * 255).rounded())
            let s = String(n, radix: 16, uppercase: true)
            return s.count == 1 ? "0" + s : s
        }
        return "#" + h(c.r) + h(c.g) + h(c.b)
    }
}

struct ColorMixer: View {
    let palette: [RGB]
    let close: () -> Void
    let done: (String) -> Void

    @State private var pots: [RGB?] = [nil, nil]
    @State private var drops = [1, 1]
    @State private var next = 0
    @State private var stirStart = Date.distantPast

    static func palette(forCategory cat: String, art: DressUpArt = .shared) -> [RGB] {
        switch art.category(cat)?.palette {
        case "hair": return art.hair
        case "eye": return art.eye
        default: return art.cloth
        }
    }

    private var result: RGB? {
        let parts = pots.indices.compactMap { i in pots[i].map { ($0, Double(drops[i])) } }
        return parts.isEmpty ? nil : PaintMix.mix(parts)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                RoundButton(symbol: "xmark", tint: Theme.pink, size: 60) {
                    Sound.shared.play(.whoosh, volume: 0.6)
                    close()
                }
                Spacer()
                RoundButton(symbol: "checkmark", tint: Color(hex: 0x6CCB8B), size: 60) {
                    guard let r = result else { return }
                    Sound.shared.play(.sparkle)
                    done(PaintMix.hex(r))
                }
                .opacity(result == nil ? 0.4 : 1)
                .disabled(result == nil)
            }
            HStack(alignment: .center, spacing: 12) {
                pot(0)
                bowl.frame(width: 174, height: 174)
                pot(1)
            }
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(palette.indices, id: \.self) { i in
                        Button { pick(palette[i]) } label: {
                            Circle()
                                .fill(palette[i].color)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Circle()
                                        .fill(.white.opacity(0.32))
                                        .frame(width: 16, height: 9)
                                        .offset(x: -8, y: -12)
                                )
                                .overlay(Circle().stroke(Shades.outline(palette[i]).color.opacity(0.6), lineWidth: 2.5))
                        }
                        .buttonStyle(Squish())
                    }
                }
                .padding(.vertical, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Theme.cream.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(Theme.blush, lineWidth: 4))
    }

    private func pick(_ c: RGB) {
        Sound.shared.play(.bubble)
        Sound.shared.tap()
        pots[next] = c
        drops[next] = 1
        next = (next + 1) % 2
        stirStart = Date()
    }

    private func pot(_ i: Int) -> some View {
        Button {
            guard pots[i] != nil else { return }
            Sound.shared.play(.pop)
            drops[i] = drops[i] >= 5 ? 1 : drops[i] + 1
            stirStart = Date()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white)
                        .frame(width: 84, height: 96)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.blush, lineWidth: 4))
                    if let c = pots[i] {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(c.color)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Shades.outline(c).color.opacity(0.5), lineWidth: 2)
                            )
                            .overlay(alignment: .topLeading) {
                                Capsule()
                                    .fill(.white.opacity(0.45))
                                    .frame(width: 10, height: 24)
                                    .padding(.leading, 8)
                                    .padding(.top, 8)
                            }
                            .frame(width: 66, height: 70)
                            .offset(y: 6)
                    } else {
                        Image(systemName: "drop")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.pink.opacity(0.5))
                    }
                }
                .overlay(alignment: .top) {
                    if next == i {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.pink)
                            .offset(y: -20)
                    }
                }
                HStack(spacing: 3) {
                    ForEach(0..<drops[i], id: \.self) { _ in
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(pots[i]?.color ?? Theme.blush)
                    }
                }
                .frame(height: 18)
            }
        }
        .buttonStyle(Squish())
    }

    private var bowl: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let since = tl.date.timeIntervalSince(stirStart)
                let blend = min(1, max(0, since / 1.4))
                let r = min(size.width, size.height) / 2 - 10
                let c = CGPoint(x: size.width / 2, y: size.height / 2 + 4)
                let rim = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                StorybookArt.fillAndStroke(
                    ctx,
                    rim,
                    fill: StorybookArt.color(0xFFFDFB),
                    stroke: StorybookArt.outline(for: 0xF5B8D0),
                    width: 4
                )
                let innerRect = CGRect(x: c.x - r + 10, y: c.y - r + 10, width: r * 2 - 20, height: r * 2 - 20)
                let innerCircle = Path(ellipseIn: innerRect)
                var g = ctx
                g.clip(to: innerCircle)
                if let mixed = result {
                    g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(mixed.color))
                    if blend < 1 {
                        for (k, p) in pots.enumerated() {
                            guard let col = p else { continue }
                            var s = Path()
                            for j in 0...40 {
                                let u = Double(j) / 40
                                let a = u * 4 * .pi + t * 5 + Double(k) * .pi
                                let rr = Double(r - 14) * u
                                let q = CGPoint(x: c.x + CGFloat(cos(a) * rr), y: c.y + CGFloat(sin(a) * rr))
                                if j == 0 { s.move(to: q) } else { s.addLine(to: q) }
                            }
                            var sg = g
                            sg.opacity = 1 - blend
                            sg.stroke(s, with: .color(col.color), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                        }
                    }
                    StorybookArt.highlight(
                        g,
                        in: CGRect(x: c.x - r * 0.52, y: c.y - r * 0.62, width: r * 0.52, height: r * 0.22),
                        opacity: 0.48
                    )
                } else {
                    g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xF4EEF9)))
                }
                ctx.stroke(innerCircle, with: .color(Theme.blush), lineWidth: 5)

                if blend < 1, result != nil {
                    drawWoodenSpoon(in: ctx, center: c, radius: r, angle: t * 5)
                }
            }
        }
    }

    private func drawWoodenSpoon(in ctx: GraphicsContext, center c: CGPoint, radius r: CGFloat, angle a: Double) {
        let tip = CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.36, y: c.y + CGFloat(sin(a)) * r * 0.36)
        let woodBase: UInt32 = 0xD89B65
        let woodOutline = StorybookArt.outline(for: woodBase)
        let woodLight = StorybookArt.tint(for: woodBase, amount: 0.35)

        var sg = ctx
        sg.translateBy(x: tip.x, y: tip.y)
        sg.rotate(by: .degrees(32 + sin(a) * 8))

        let head = Path(ellipseIn: CGRect(x: -11, y: -15, width: 22, height: 28))
        StorybookArt.fillAndStroke(sg, head, fill: StorybookArt.color(0xC6844C), stroke: woodOutline, width: 2.6)
        let scoop = Path(ellipseIn: CGRect(x: -6, y: -10, width: 12, height: 18))
        sg.fill(scoop, with: .color(StorybookArt.shade(for: woodBase, factor: 0.84).opacity(0.65)))

        var handle = Path()
        handle.move(to: CGPoint(x: -4.5, y: -12))
        handle.addQuadCurve(to: CGPoint(x: -6.5, y: -r * 0.96), control: CGPoint(x: -4, y: -r * 0.55))
        handle.addQuadCurve(to: CGPoint(x: 6.5, y: -r * 0.96), control: CGPoint(x: 0, y: -r * 1.06))
        handle.addQuadCurve(to: CGPoint(x: 4.5, y: -12), control: CGPoint(x: 4, y: -r * 0.55))
        handle.closeSubpath()
        StorybookArt.fillAndStroke(sg, handle, fill: StorybookArt.color(woodBase), stroke: woodOutline, width: 2.8)

        var shine = Path()
        shine.move(to: CGPoint(x: -1.8, y: -22))
        shine.addLine(to: CGPoint(x: -2.4, y: -r * 0.86))
        sg.stroke(shine, with: .color(woodLight.opacity(0.8)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    }
}
