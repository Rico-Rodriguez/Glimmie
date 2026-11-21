import SwiftUI

struct UnicornPicture: View {
    let look: UnicornLook
    var stride: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 360, size.height / 310)
            var art = context
            art.translateBy(x: (size.width - 360 * scale) / 2, y: (size.height - 310 * scale) / 2)
            art.scaleBy(x: scale, y: scale)
            Self.paint(look, stride: stride, in: art)
        }
        .accessibilityHidden(true)
    }

    static func sticker(_ look: UnicornLook, in context: GraphicsContext) {
        var art = context
        art.scaleBy(x: 0.26, y: 0.26)
        art.translateBy(x: -180, y: -155)
        paint(look, stride: 0, in: art)
    }

    private static func paint(_ look: UnicornLook, stride: CGFloat, in g: GraphicsContext) {
        let coat = Color(hex: look.coat)
        let mane = Color(hex: look.mane)
        let horn = Color(hex: look.horn)
        let outline = Color(hex: 0x8D5C87)
        let hoof = Color(hex: 0x7B5789)

        func shape(_ path: Path, _ color: Color, line: CGFloat = 4) {
            g.fill(path, with: .color(color))
            g.stroke(path, with: .color(outline), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
        }
        func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h))
        }
        func drawLeg(x: CGFloat, motion: CGFloat, far: Bool) {
            var leg = Path()
            leg.move(to: CGPoint(x: x, y: 224))
            leg.addQuadCurve(to: CGPoint(x: x + motion, y: 281), control: CGPoint(x: x + motion * 0.42, y: 261))
            let style = StrokeStyle(lineWidth: 24, lineCap: .round)
            g.stroke(leg, with: .color(outline), style: StrokeStyle(lineWidth: 31, lineCap: .round))
            g.stroke(leg, with: .color(far ? coat.opacity(0.81) : coat), style: style)
            shape(oval(x + motion - 15, 273, 31, 22), hoof, line: 3)
        }

        // Tail behind the legs and body.
        let tail = Path { p in
            p.move(to: CGPoint(x: 113, y: 174))
            p.addCurve(to: CGPoint(x: 38, y: 214), control1: CGPoint(x: 32, y: 138), control2: CGPoint(x: 54, y: 201))
            p.addQuadCurve(to: CGPoint(x: 18, y: 207), control: CGPoint(x: 27, y: 221))
            p.addCurve(to: CGPoint(x: 116, y: 204), control1: CGPoint(x: 29, y: 270), control2: CGPoint(x: 89, y: 230))
            p.closeSubpath()
        }
        shape(tail, mane)
        drawLeg(x: 141, motion: -stride, far: true)
        drawLeg(x: 227, motion: stride, far: true)
        drawLeg(x: 119, motion: stride, far: false)
        drawLeg(x: 205, motion: -stride, far: false)
        let neck = Path { p in
            p.move(to: CGPoint(x: 157, y: 195))
            p.addQuadCurve(to: CGPoint(x: 208, y: 119), control: CGPoint(x: 205, y: 179))
            p.addLine(to: CGPoint(x: 268, y: 129))
            p.addQuadCurve(to: CGPoint(x: 249, y: 223), control: CGPoint(x: 242, y: 157))
            p.closeSubpath()
        }
        shape(neck, coat)
        shape(oval(87, 162, 173, 91), coat)
        g.fill(oval(113, 172, 76, 23), with: .color(.white.opacity(0.42)))

        if look.gear == .saddle {
            shape(Path(roundedRect: CGRect(x: 117, y: 166, width: 67, height: 53), cornerRadius: 21), Theme.lilac)
            g.fill(PetPainter.heartPath(in: CGRect(x: 135, y: 176, width: 31, height: 29)), with: .color(.white))
        } else if look.gear == .wings {
            let wing = Path { p in
                p.move(to: CGPoint(x: 189, y: 207))
                p.addCurve(to: CGPoint(x: 105, y: 131), control1: CGPoint(x: 146, y: 226), control2: CGPoint(x: 118, y: 172))
                p.addQuadCurve(to: CGPoint(x: 150, y: 155), control: CGPoint(x: 135, y: 130))
                p.addQuadCurve(to: CGPoint(x: 161, y: 124), control: CGPoint(x: 145, y: 138))
                p.addQuadCurve(to: CGPoint(x: 189, y: 207), control: CGPoint(x: 197, y: 149))
                p.closeSubpath()
            }
            shape(wing, Theme.mint)
        }

        for i in (0..<6).reversed() {
            let n = CGFloat(i)
            let x: CGFloat = 181 - n * 4 + (look.braided && i.isMultiple(of: 2) ? 9 : 0)
            let w: CGFloat = look.braided ? 35 : 57 - n * 3
            shape(oval(x, 88 + n * 17, w, look.braided ? 31 : 45), mane, line: 3)
            g.fill(oval(x + 8, 97 + n * 17, 12, 7), with: .color(.white.opacity(0.42)))
        }

        let ear = Path { p in
            p.move(to: CGPoint(x: 233, y: 91))
            p.addQuadCurve(to: CGPoint(x: 230, y: 43), control: CGPoint(x: 213, y: 58))
            p.addQuadCurve(to: CGPoint(x: 256, y: 83), control: CGPoint(x: 253, y: 53))
            p.closeSubpath()
        }
        shape(ear, coat)
        g.fill(oval(228, 57, 12, 20), with: .color(Theme.blush))
        shape(oval(204, 76, 110, 86), coat)
        shape(oval(265, 108, 64, 47), Theme.blush)
        g.fill(oval(308, 123, 7, 5), with: .color(outline))
        g.fill(oval(250, 123, 17, 9), with: .color(Theme.pink.opacity(0.62)))
        g.fill(oval(254, 101, 10, 15), with: .color(Theme.ink))
        g.fill(oval(257, 103, 4, 4), with: .color(.white))
        let cone = Path { p in
            p.move(to: CGPoint(x: 264, y: 81))
            p.addLine(to: CGPoint(x: 290, y: 24))
            p.addLine(to: CGPoint(x: 285, y: 87))
            p.closeSubpath()
        }
        shape(cone, horn)
        for i in 0..<3 {
            let n = CGFloat(i)
            var stripe = Path()
            stripe.move(to: CGPoint(x: 271 + n * 5, y: 69 - n * 11))
            stripe.addLine(to: CGPoint(x: 285 + n, y: 74 - n * 11))
            g.stroke(stripe, with: .color(.white.opacity(0.72)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        shape(oval(209, 71, 58, 28), mane, line: 3)
        if look.gear == .bow {
            shape(oval(182, 152, 26, 21), Theme.lilac, line: 3)
            shape(oval(205, 149, 28, 21), Theme.lilac, line: 3)
            shape(oval(200, 153, 15, 15), Theme.lemon, line: 3)
        } else if look.gear == .crown {
            var crown = Path()
            crown.addLines([CGPoint(x: 229, y: 83), CGPoint(x: 222, y: 60), CGPoint(x: 238, y: 67),
                            CGPoint(x: 247, y: 52), CGPoint(x: 255, y: 68), CGPoint(x: 272, y: 60),
                            CGPoint(x: 266, y: 84)])
            crown.closeSubpath()
            shape(crown, Theme.lemon, line: 3)
        }
    }
}

extension MeadowVisitor {
    var sticker: Sticker {
        Sticker(id: rawValue) { g, _ in
            if let look {
                UnicornPicture.sticker(look, in: g)
            } else if self == .bunny {
                let fur = Color(hex: 0xEDCCB8)
                for x in [-22.0, 4.0] {
                    g.fill(Path(ellipseIn: CGRect(x: x, y: -44, width: 18, height: 44)), with: .color(fur))
                    g.fill(Path(ellipseIn: CGRect(x: x + 5, y: -39, width: 8, height: 31)), with: .color(Theme.pink))
                }
                g.fill(Path(ellipseIn: CGRect(x: -30, y: -16, width: 60, height: 51)), with: .color(fur))
                for x in [-15.0, 8.0] {
                    g.fill(Path(ellipseIn: CGRect(x: x, y: 3, width: 7, height: 10)), with: .color(Theme.ink))
                }
                g.fill(Path(ellipseIn: CGRect(x: -4, y: 13, width: 8, height: 7)), with: .color(Theme.pink))
            } else {
                for x in [-35.0, 2.0] {
                    g.fill(Path(ellipseIn: CGRect(x: x, y: -25, width: 33, height: 39)), with: .color(Theme.lilac))
                    g.fill(Path(ellipseIn: CGRect(x: x + 4, y: 1, width: 25, height: 27)), with: .color(Theme.pink))
                    g.fill(Path(ellipseIn: CGRect(x: x + 11, y: -16, width: 11, height: 13)), with: .color(.white))
                }
                g.fill(Path(roundedRect: CGRect(x: -4, y: -18, width: 8, height: 44), cornerRadius: 4), with: .color(Theme.ink))
            }
        }
    }
}
