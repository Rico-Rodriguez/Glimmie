import SwiftUI

enum PotionFind {
    static let unicornStickers = ["rainbowUnicorn", "floatingUnicorn"]

    static var stickers: [Sticker] {
        PotionKind.allCases.map { k in Sticker(id: k.rawValue) { g, _ in drawPotion(g, k) } }
            + unicornStickers.map { id in Sticker(id: id) { g, _ in drawUnicorn(g, id) } }
    }

    static func drawPotion(_ g: GraphicsContext, _ k: PotionKind) {
        let b = PotionBottle(
            id: 3,
            r: k.color.r,
            g: k.color.g,
            b: k.color.b,
            fill: 0.84,
            shape: k.shape.rawValue,
            kind: k.rawValue,
            magic: [:],
            glow: 0,
            sparkle: Double(k.sparkle)
        )
        PotionBottlePainter.draw(g, bottle: b, center: CGPoint(x: 0, y: 4), angle: 0, scale: 0.74, time: 0.6)
    }

    static func drawUnicorn(_ g: GraphicsContext, _ id: String) {
        var pg = g
        let k: CGFloat = 0.15
        pg.translateBy(x: 0, y: 40)
        pg.scaleBy(x: k, y: k)
        pg.translateBy(x: -300, y: -PetArt.feetY)
        var pose = PetPose()
        pose.eyes = "sparkle"
        pose.mouth = "grin"
        var shading: GraphicsContext.Shading?
        if id == "rainbowUnicorn" {
            let rainbow = ["#FF8FB8", "#FFB27A", "#FFE27A", "#8FE0A4", "#7FC8FF", "#B89CFF"].map { RGB(hex: $0).c() }
            shading = .linearGradient(Gradient(colors: rainbow), startPoint: CGPoint(x: 120, y: 60), endPoint: CGPoint(x: 480, y: 620))
        }
        if id == "floatingUnicorn" {
            let c = CGPoint(x: 0, y: -2)
            let r: CGFloat = 46
            let bub = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            g.fill(bub, with: .radialGradient(Gradient(colors: [.clear, RGB(hex: "#BFEFFF").c(0.3), RGB(hex: "#FFC2EC").c(0.5)]), center: c, startRadius: 20, endRadius: r))
        }
        PetPainter.draw(LabCreature.unicorn.petLook, pose: pose, furShading: shading, in: pg)
        if id == "floatingUnicorn" {
            let c = CGPoint(x: 0, y: -2)
            let r: CGFloat = 46
            let bub = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            g.stroke(
                bub,
                with: .linearGradient(
                    Gradient(colors: [RGB(hex: "#9FE8FF").c(), RGB(hex: "#FFB8E8").c(), RGB(hex: "#FFE38A").c()]),
                    startPoint: CGPoint(x: -r, y: -r),
                    endPoint: CGPoint(x: r, y: r)
                ),
                lineWidth: 3
            )
            g.fill(Path(ellipseIn: CGRect(x: -28, y: -38, width: 18, height: 11)), with: .color(.white.opacity(0.8)))
        } else {
            Twinkles.draw(g, around: CGPoint(x: 0, y: -4), radius: 40, time: 0.6, count: 3, alpha: 1)
        }
    }
}
