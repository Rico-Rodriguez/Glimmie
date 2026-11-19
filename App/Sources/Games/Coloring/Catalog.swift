import SwiftUI
import UIKit

/// The coloring book: categories and pages from App/Resources/Games/Coloring/pages.json
/// (written by tools/make_coloring.py).
struct ColoringCategory: Identifiable, Decodable {
    let id: String
    let icon: String
    let color: [Double]
    let pages: [String]

    var tint: Color {
        color.count == 3 ? Color(.sRGB, red: color[0], green: color[1], blue: color[2]) : Theme.lilac
    }
}

enum ColoringCatalog {
    static let game = "Coloring"
    /// Page id for a blank sheet with no line art.
    static let blank = "blank"

    static let categories: [ColoringCategory] = {
        struct File: Decodable { let categories: [ColoringCategory] }
        guard let url = GameFiles.url("pages", "json", game: game),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.categories
    }()

    private static let thumbs = NSCache<NSString, UIImage>()

    static func thumbnail(_ page: String) -> UIImage? {
        if let t = thumbs.object(forKey: page as NSString) { return t }
        guard let url = GameFiles.url(page + "_t", "png", game: game), let img = UIImage(contentsOfFile: url.path) else { return nil }
        thumbs.setObject(img, forKey: page as NSString)
        return img
    }

    static func lineArt(_ page: String) -> CGImage? {
        guard page != blank, let url = GameFiles.url(page, "png", game: game) else { return nil }
        return UIImage(contentsOfFile: url.path)?.cgImage
    }
}

// MARK: - Palette and stickers

enum ColoringPalette {
    static let colors: [PaintColor] = [
        0xFF4D4D, 0xFF8A3D, 0xFFC93D, 0xFFF06B, 0xB6E85A, 0x4CCB6B,
        0x2FB8A6, 0x5CD3FF, 0x3C8DFF, 0x6C63FF, 0xA66BFF, 0xE07BFF,
        0xFF6FB5, 0xFF9EC9, 0xFFC7DE, 0xFFE2C4, 0xF2B48C, 0xC98A5B,
        0x8B5A3C, 0x5B3A2E, 0x111111, 0x7A7A86, 0xC9C9D1, 0xFFFFFF,
    ].map(PaintColor.hex)
}

enum ColoringStickers {
    static let all: [String] = [
        "🦄", "🌈", "⭐️", "💖", "✨", "🌟", "🎀", "👑", "💎", "🔮", "🪄", "🫧",
        "🐱", "🐶", "🐰", "🐻", "🐼", "🦊", "🐸", "🐥", "🦋", "🐞", "🐝", "🐢",
        "🐠", "🐬", "🐙", "🦀", "🐳", "🦖", "🦕", "🐉", "🐧", "🦉", "🐷", "🐮",
        "🌸", "🌷", "🌻", "🍄", "🍀", "🌲", "☀️", "🌙", "☁️", "❄️", "⚡️", "🔥",
        "🍓", "🍰", "🧁", "🍦", "🍭", "🍩", "🍪", "🍉", "🍒", "🍕", "🎂", "🍬",
        "🎈", "🎁", "🎉", "🚗", "🚀", "🚂", "✈️", "⛵️", "🏰", "🎠", "🪐", "👽",
    ]
}
