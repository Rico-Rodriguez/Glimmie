import SwiftUI

struct UnicornBackdrop: View {
    let meadow: Bool

    var body: some View {
        Group {
            if meadow {
                SceneView(bg: "bg_park")
            } else {
                ZStack {
                    Canvas { g, _ in drawStable(g) }
                    SceneView(bg: "bg_garden")
                        .frame(width: 280, height: 262)
                        .clipShape(RoundedRectangle(cornerRadius: 96))
                        .overlay(RoundedRectangle(cornerRadius: 96).strokeBorder(.white, lineWidth: 11))
                        .shadow(color: Theme.ink.opacity(0.14), radius: 5, y: 5)
                        .position(x: 253, y: 248)
                    PetPropThumb(name: "brush").frame(width: 93, height: 93).position(x: 881, y: 260)
                    PetPropThumb(name: "sponge").frame(width: 86, height: 86).position(x: 939, y: 271)
                }
            }
        }
        .frame(width: 1024, height: 834)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawStable(_ g: GraphicsContext) {
        func panel(_ rect: CGRect, _ color: Color, radius: CGFloat = 0) {
            let path = Path(roundedRect: rect, cornerRadius: radius)
            g.fill(path, with: .color(color))
        }
        panel(CGRect(x: 0, y: 0, width: 1024, height: 834), Color(hex: 0xFFF1ED))
        for x in stride(from: 84, to: 1024, by: 98) {
            panel(CGRect(x: x, y: 0, width: 5, height: 490), Theme.blush.opacity(0.52), radius: 2.5)
        }
        panel(CGRect(x: 0, y: 482, width: 1024, height: 352), Color(hex: 0xF8D9C3))
        panel(CGRect(x: 0, y: 477, width: 1024, height: 22), Color(hex: 0xE8B0AE), radius: 7)
        panel(CGRect(x: 0, y: 482, width: 1024, height: 6), Color(hex: 0xF9D4C0), radius: 3)
        for y in [552, 640, 747] {
            panel(CGRect(x: 0, y: y, width: 1024, height: 3), Color(hex: 0xE6BDAE), radius: 1.5)
        }

        // Stall, hardware, and a fitted shelf use the same rounded shapes and pastel shadows as Pet Vet.
        let stall = CGRect(x: 744, y: 321, width: 258, height: 170)
        panel(stall, Color(hex: 0x76BFAA), radius: 24)
        panel(stall.insetBy(dx: 7, dy: 7), Theme.mint, radius: 18)
        for x in [800, 852, 904, 956] {
            panel(CGRect(x: x, y: 331, width: 4, height: 150), Color(hex: 0x8ACFBA), radius: 2)
        }
        var brace = Path()
        brace.move(to: CGPoint(x: 768, y: 466))
        brace.addLine(to: CGPoint(x: 974, y: 349))
        g.stroke(brace, with: .color(Color(hex: 0xC4EEDE)), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        panel(CGRect(x: 768, y: 333, width: 48, height: 15), Color(hex: 0x69AA9F), radius: 7)
        panel(CGRect(x: 838, y: 296, width: 148, height: 17), Color(hex: 0xD9AFD8), radius: 8)
        panel(CGRect(x: 847, y: 294, width: 130, height: 6), Theme.lilac, radius: 3)
    }
}
