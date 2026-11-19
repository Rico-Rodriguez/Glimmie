import SwiftUI
import UIKit

// MARK: - Saved artwork
//
// Everything lives in GameStorage.folder("coloring"):
//   gallery.json        [ColoringArtwork], newest first
//   <id>.png            the color layer (1600x1200), so she can keep coloring later
//   <id>.stickers.json  [ColorSticker]
//   <id>.glitter        the glitter flakes that twinkle (GlitterFlake.encode), if any
//   <id>.jpg            a small picture of the finished page for the gallery
// New fields must be optional or have defaults so older saves still load.

struct ColorSticker: Codable, Identifiable, Equatable {
    var id = UUID()
    var emoji: String
    var x: Double       // centre, paper pixels
    var y: Double
    var scale: Double = 1
    var angle: Double = 0   // radians

    /// Font size in paper pixels at scale 1.
    static let baseSize: Double = 150
}

struct ColoringArtwork: Codable, Identifiable, Equatable {
    var id: String
    var page: String
    var updated: Date
}

final class ColoringGallery: ObservableObject {
    static let shared = ColoringGallery()
    static let gameID = "coloring"

    @Published private(set) var items: [ColoringArtwork]

    private var folder: URL { GameStorage.folder(Self.gameID) }

    private init() {
        items = GameStorage.load([ColoringArtwork].self, game: Self.gameID, file: "gallery.json") ?? []
        // Drop entries whose color layer is missing (for example a save cut short).
        items.removeAll { !FileManager.default.fileExists(atPath: folder.appendingPathComponent("\($0.id).png").path) }
    }

    private func url(_ id: String, _ ext: String) -> URL { folder.appendingPathComponent("\(id).\(ext)") }

    func save(id: String, page: String, paper: ColoringPaper, stickers: [ColorSticker]) {
        guard let png = paper.pngData() else { return }
        try? png.write(to: url(id, "png"), options: .atomic)
        if let data = try? JSONEncoder().encode(stickers) { try? data.write(to: url(id, "stickers.json"), options: .atomic) }
        if paper.flakes.isEmpty {
            try? FileManager.default.removeItem(at: url(id, "glitter"))
        } else {
            try? GlitterFlake.encode(paper.flakes).write(to: url(id, "glitter"), options: .atomic)
        }
        if let img = paper.makeImage(),
           let thumb = ColoringRender.picture(color: img, page: page, stickers: stickers, width: 480).jpegData(compressionQuality: 0.85) {
            try? thumb.write(to: url(id, "jpg"), options: .atomic)
            thumbs.removeObject(forKey: id as NSString)
        }
        items.removeAll { $0.id == id }
        items.insert(ColoringArtwork(id: id, page: page, updated: Date()), at: 0)
        persist()
    }

    func delete(_ art: ColoringArtwork) {
        for ext in ["png", "stickers.json", "jpg", "glitter"] { try? FileManager.default.removeItem(at: url(art.id, ext)) }
        items.removeAll { $0.id == art.id }
        thumbs.removeObject(forKey: art.id as NSString)
        persist()
    }

    private func persist() { GameStorage.save(items, game: Self.gameID, file: "gallery.json") }

    func colorLayer(_ id: String) -> CGImage? { UIImage(contentsOfFile: url(id, "png").path)?.cgImage }

    func stickers(_ id: String) -> [ColorSticker] {
        guard let d = try? Data(contentsOf: url(id, "stickers.json")) else { return [] }
        return (try? JSONDecoder().decode([ColorSticker].self, from: d)) ?? []
    }

    func glitter(_ id: String) -> [GlitterFlake] {
        guard let d = try? Data(contentsOf: url(id, "glitter")) else { return [] }
        return GlitterFlake.decode(d)
    }

    private let thumbs = NSCache<NSString, UIImage>()

    func thumbnail(_ id: String) -> UIImage? {
        if let t = thumbs.object(forKey: id as NSString) { return t }
        guard let img = UIImage(contentsOfFile: url(id, "jpg").path) else { return nil }
        thumbs.setObject(img, forKey: id as NSString)
        return img
    }

    /// The finished picture at full size, for saving to Photos.
    func fullPicture(_ art: ColoringArtwork) -> UIImage? {
        guard let color = colorLayer(art.id) else { return nil }
        return ColoringRender.picture(color: color, page: art.page, stickers: stickers(art.id), width: 2048)
    }
}

enum ColoringRender {
    /// Color layer + line art + stickers, flattened into one picture `width` pixels wide.
    static func picture(color: CGImage, page: String, stickers: [ColorSticker], width: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: width * CGFloat(ColoringPaper.height) / CGFloat(ColoringPaper.width))
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIImage(cgImage: color).draw(in: rect)
            if let line = ColoringCatalog.lineArt(page) { UIImage(cgImage: line).draw(in: rect) }
            let k = width / CGFloat(ColoringPaper.width)
            for s in stickers {
                let font = UIFont.systemFont(ofSize: CGFloat(ColorSticker.baseSize * s.scale) * k)
                let str = NSAttributedString(string: s.emoji, attributes: [.font: font])
                let b = str.size()
                let g = ctx.cgContext
                g.saveGState()
                g.translateBy(x: CGFloat(s.x) * k, y: CGFloat(s.y) * k)
                g.rotate(by: CGFloat(s.angle))
                str.draw(at: CGPoint(x: -b.width / 2, y: -b.height / 2))
                g.restoreGState()
            }
        }
    }
}

// MARK: - Gallery screen

struct ColoringGalleryView: View {
    @ObservedObject var gallery = ColoringGallery.shared
    let onBack: () -> Void
    let onOpen: (ColoringArtwork) -> Void
    @State private var viewing: ColoringArtwork?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                ColoringButton(icon: "chevron.backward", tint: Theme.lilac, action: onBack)
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Color.clear.frame(width: 72, height: 72)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            if gallery.items.isEmpty {
                Spacer()
                VStack(spacing: 18) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 90, weight: .bold))
                        .foregroundStyle(Theme.pink)
                    Image(systemName: "sparkles")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(Theme.lemon)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 22)], spacing: 22) {
                        ForEach(gallery.items) { art in
                            Button {
                                Sound.shared.play(.tap, volume: 0.5)
                                viewing = art
                            } label: {
                                ColoringArtThumb(image: gallery.thumbnail(art.id))
                            }
                            .buttonStyle(Squish())
                        }
                    }
                    .padding(24)
                }
            }
        }
        .overlay {
            if let art = viewing {
                ColoringArtViewer(art: art, onClose: { viewing = nil }, onContinue: { viewing = nil; onOpen(art) })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewing)
    }
}

private struct ColoringArtThumb: View {
    let image: UIImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(.white)
            if let image {
                Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16)).padding(8)
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .shadow(color: Theme.ink.opacity(0.18), radius: 6, y: 4)
    }
}

private struct ColoringArtViewer: View {
    let art: ColoringArtwork
    let onClose: () -> Void
    let onContinue: () -> Void
    @State private var askDelete = false
    @State private var savedToPhotos = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 20) {
                if let img = ColoringGallery.shared.thumbnail(art.id) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white, lineWidth: 8))
                        .frame(maxWidth: 760, maxHeight: 560)
                }
                HStack(spacing: 28) {
                    ColoringButton(icon: "xmark", tint: Theme.lilac, action: onClose)
                    ColoringButton(icon: "paintbrush.pointed.fill", tint: Theme.pink, size: 96, action: onContinue)
                    ColoringButton(icon: savedToPhotos ? "checkmark" : "square.and.arrow.down.fill", tint: Theme.sky) {
                        guard !savedToPhotos, let pic = ColoringGallery.shared.fullPicture(art) else { return }
                        UIImageWriteToSavedPhotosAlbum(pic, nil, nil, nil)
                        Sound.shared.play(.ding)
                        savedToPhotos = true
                    }
                    ColoringButton(icon: "trash.fill", tint: Theme.peach) { askDelete = true }
                }
            }
            if askDelete {
                Color.black.opacity(0.3).ignoresSafeArea()
                VStack(spacing: 24) {
                    Image(systemName: "trash.fill").font(.system(size: 60, weight: .bold)).foregroundStyle(Theme.ink)
                    HStack(spacing: 40) {
                        ColoringButton(icon: "xmark", tint: Theme.mint, size: 96) { askDelete = false }
                        ColoringButton(icon: "checkmark", tint: Theme.peach, size: 96) {
                            Sound.shared.play(.whoosh, volume: 0.6)
                            ColoringGallery.shared.delete(art)
                            onClose()
                        }
                    }
                }
                .padding(40)
                .background(RoundedRectangle(cornerRadius: 36).fill(Theme.cream))
            }
        }
    }
}

/// A big round icon button, matching the drawer's HomeButton.
struct ColoringButton: View {
    let icon: String
    var tint: Color = Theme.pink
    var size: CGFloat = 72
    var selected = false
    let action: () -> Void

    var body: some View {
        Button {
            Sound.shared.play(.tap, volume: 0.5)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(tint))
                .overlay(Circle().stroke(selected ? Theme.ink : .white, lineWidth: selected ? 6 : 5))
                .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 4)
        }
        .buttonStyle(Squish())
    }
}
