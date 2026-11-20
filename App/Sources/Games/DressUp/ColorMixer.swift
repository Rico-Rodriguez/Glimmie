import SwiftUI

// MARK: - Mix your own color
//
// Two paint pots: tap a color to fill a pot, tap a pot to add another drop of it. The bowl in the
// middle stirs them together like real paint (blue and yellow make green, red and white make pink):
// colors are mixed as pigments (Kubelka-Munk, one coat), not averaged like light.

enum PaintMix {
    /// Mixes colors as paint, weighted by drops.
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
            }
            HStack(alignment: .center, spacing: 12) {
                pot(0)
                bowl.frame(width: 170, height: 170)
                pot(1)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(palette.indices, id: \.self) { i in
                    Button { pick(palette[i]) } label: {
                        Circle()
                            .fill(palette[i].color)
                            .frame(width: 52, height: 52)
                            .overlay(Circle().stroke(Shades.outline(palette[i]).color.opacity(0.5), lineWidth: 2))
                    }
                    .buttonStyle(Squish())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Color(hex: 0xFFF7FA)))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(.white, lineWidth: 5))
    }

    private func pick(_ c: RGB) {
        Sound.shared.play(.bubble)
        Sound.shared.tap()
        pots[next] = c
        drops[next] = 1
        next = (next + 1) % 2
        stirStart = Date()
    }

    /// One pot: its color and how many drops; tap it for one more drop.
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

    /// The mixing bowl: the two paints swirl together, then settle into the mixed color.
    private var bowl: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let since = tl.date.timeIntervalSince(stirStart)
                let blend = min(1, max(0, since / 1.4))
                let r = min(size.width, size.height) / 2 - 6
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let rim = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                ctx.fill(rim, with: .color(.white))
                var g = ctx
                g.clip(to: Path(ellipseIn: CGRect(x: c.x - r + 10, y: c.y - r + 10, width: r * 2 - 20, height: r * 2 - 20)))
                if let mixed = result {
                    g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(mixed.color))
                    // swirls of the two paints, fading as they're stirred in
                    if blend < 1 {
                        for (k, p) in pots.enumerated() {
                            guard let col = p else { continue }
                            var s = Path()
                            for j in 0...40 {
                                let u = Double(j) / 40
                                let a = u * 4 * .pi + t * 5 + Double(k) * .pi
                                let rr = Double(r - 12) * u
                                let q = CGPoint(x: c.x + CGFloat(cos(a) * rr), y: c.y + CGFloat(sin(a) * rr))
                                if j == 0 { s.move(to: q) } else { s.addLine(to: q) }
                            }
                            var sg = g
                            sg.opacity = 1 - blend
                            sg.stroke(s, with: .color(col.color), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                        }
                    }
                    g.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.5, y: c.y - r * 0.62, width: r * 0.5, height: r * 0.22)),
                           with: .color(.white.opacity(0.45)))
                } else {
                    g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xF3EEF8)))
                }
                ctx.stroke(rim, with: .color(Theme.blush), lineWidth: 8)
                // the spoon goes round while it stirs
                if blend < 1, result != nil {
                    let a = t * 5
                    let tip = CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.45, y: c.y + CGFloat(sin(a)) * r * 0.45)
                    var sp = Path()
                    sp.move(to: tip)
                    sp.addLine(to: CGPoint(x: tip.x + r * 0.6, y: tip.y - r * 0.9))
                    ctx.stroke(sp, with: .color(Color(hex: 0xC98A55)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                }
            }
        }
    }
}
