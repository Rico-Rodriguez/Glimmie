import SwiftUI

/// A sheet of paper and a tray of reusable stamps made from the player's own harvest.
struct GardenPrintView: View {
    let sim: GardenSim
    let close: () -> Void
    @State private var stamps: [GardenStamp]
    @State private var selected: String?
    @State private var moving: Int?
    @State private var preview: CGPoint?
    private let choices: [String]

    init(sim: GardenSim, close: @escaping () -> Void) {
        self.sim = sim
        self.close = close
        var seen = Set<String>()
        let choices = sim.basket.reversed().filter { seen.insert($0).inserted && Self.specimen($0) != nil }
        self.choices = choices
        _selected = State(initialValue: choices.first)
        _stamps = State(initialValue: sim.stamps)
    }

    private static func specimen(_ name: String) -> (PlantKind, Int)? {
        let parts = name.split(separator: ":")
        guard let first = parts.first, let kind = PlantKind(rawValue: String(first)) else { return nil }
        return (kind, parts.count > 1 ? Int(parts[1]) ?? 0 : 0)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Garden prints").font(.system(.title2, design: .serif).bold())
                Spacer()
                Button {
                    if !stamps.isEmpty { stamps.removeLast() }
                } label: {
                    Image(systemName: "delete.backward").frame(width: 44, height: 44)
                }
                .disabled(stamps.isEmpty)
                .accessibilityLabel("Remove last stamp")
                Button("Done", action: close).buttonStyle(.borderedProminent).tint(Color(hex: 0x3C7256))
            }
            GeometryReader { geo in
                let area = CGRect(origin: .zero, size: geo.size).insetBy(dx: 30, dy: 30)
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFFFAE9))
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: 0xC1B989), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                        .padding(8)
                    Canvas { ctx, _ in
                        for (i, stamp) in stamps.enumerated() {
                            let point = moving == i ? preview ?? position(stamp, area) : position(stamp, area)
                            GardenPlants.drawCrop(ctx, kind: stamp.kind, variant: stamp.variant, at: point, size: 0.95, rot: (gdRand(i, 13) - 0.5) * 0.55)
                        }
                    }
                    if stamps.isEmpty {
                        Text(choices.isEmpty ? "Pick a ripe flower or crop to make your first stamp." : "Tap the paper to stamp. Drag a print to move it.")
                            .font(.callout).multilineTextAlignment(.center).padding(20)
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if preview == nil {
                            moving = stamps.indices.reversed().first { i in
                                let p = position(stamps[i], area)
                                return hypot(p.x - value.startLocation.x, p.y - value.startLocation.y) <= 25
                            }
                        }
                        preview = clamped(value.location, area)
                    }
                    .onEnded { value in
                        let p = clamped(value.location, area)
                        let x = Double((p.x - area.minX) / max(1, area.width))
                        let y = Double((p.y - area.minY) / max(1, area.height))
                        if let moving, stamps.indices.contains(moving) {
                            stamps[moving].x = x
                            stamps[moving].y = y
                        } else if let selected, let (kind, variant) = Self.specimen(selected) {
                            stamps.append(GardenStamp(kind: kind, variant: variant, x: x, y: y))
                            GardenSound.shared.play(.pat, volume: 0.5)
                        }
                        moving = nil
                        preview = nil
                    })
            }
            if !choices.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(choices, id: \.self) { name in
                            if let (kind, variant) = Self.specimen(name) {
                                Button {
                                    selected = name
                                } label: {
                                    Canvas { ctx, size in
                                        GardenPlants.drawCrop(ctx, kind: kind, variant: variant,
                                                              at: CGPoint(x: size.width / 2, y: size.height / 2 + 3), size: 0.66, rot: 0)
                                    }
                                    .frame(width: 52, height: 48)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected == name ? Color(hex: 0x387756) : .clear, lineWidth: 3))
                                }
                                .accessibilityLabel(kind.rawValue.capitalized)
                            }
                        }
                    }.padding(3)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .foregroundStyle(Color(hex: 0x354E39))
        .background(Color(hex: 0xDAE4C9).ignoresSafeArea())
        .onChange(of: stamps) { value in
            sim.stamps = value
            sim.save()
        }
    }

    private func position(_ stamp: GardenStamp, _ area: CGRect) -> CGPoint {
        CGPoint(x: area.minX + CGFloat(stamp.x) * area.width, y: area.minY + CGFloat(stamp.y) * area.height)
    }

    private func clamped(_ p: CGPoint, _ area: CGRect) -> CGPoint {
        CGPoint(x: min(area.maxX, max(area.minX, p.x)), y: min(area.maxY, max(area.minY, p.y)))
    }
}
