import SwiftUI
import UIKit

// MARK: - Grown-up pages (added on the device)
//
// Pages a grown-up adds from Photos, Files or the page finder live only on this device, in
// GameStorage.folder("coloring")/custom/:
//   tabs.json        [ColoringCustomTab], in the order they show in the book (before the built-in ones)
//   <id>.png         2048x1536 line art, black with the lines in the alpha channel (same as built-in pages)
//   <id>_t.png       400x300 thumbnail on white
// Page ids start with "custom-" so they never clash with built-in ids. Nothing here is ever
// committed to the repo.

struct ColoringCustomTab: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var pages: [String] = []
}

final class ColoringCustom: ObservableObject {
    static let shared = ColoringCustom()
    static let prefix = "custom-"

    @Published private(set) var tabs: [ColoringCustomTab]
    /// How many pictures are still being turned into pages.
    @Published private(set) var working = 0

    let folder: URL
    private let thumbs = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "coloring.custom", qos: .userInitiated)

    init(folder: URL = GameStorage.folder(ColoringGallery.gameID).appendingPathComponent("custom", isDirectory: true)) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("tabs.json")
        tabs = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([ColoringCustomTab].self, from: $0) } ?? []
    }

    static func isCustom(_ page: String) -> Bool { page.hasPrefix(prefix) }

    private func url(_ page: String, thumb: Bool = false) -> URL {
        folder.appendingPathComponent(page + (thumb ? "_t.png" : ".png"))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(tabs) {
            try? data.write(to: folder.appendingPathComponent("tabs.json"), options: .atomic)
        }
    }

    // MARK: Tabs

    @discardableResult
    func addTab(name: String) -> String {
        let id = Self.prefix + "tab-" + UUID().uuidString.prefix(8).lowercased()
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tabs.append(ColoringCustomTab(id: id, name: clean.isEmpty ? "My pages" : clean))
        persist()
        return id
    }

    func rename(tab: String, to name: String) {
        guard let i = tabs.firstIndex(where: { $0.id == tab }) else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        tabs[i].name = clean
        persist()
    }

    func deleteTab(_ tab: String) {
        guard let t = tabs.first(where: { $0.id == tab }) else { return }
        for p in t.pages { removeFiles(p) }
        tabs.removeAll { $0.id == tab }
        persist()
    }

    func move(tab: String, by offset: Int) {
        guard let i = tabs.firstIndex(where: { $0.id == tab }) else { return }
        let j = i + offset
        guard j >= 0, j < tabs.count else { return }
        tabs.swapAt(i, j)
        persist()
    }

    // MARK: Pages

    /// Turns a picture into a page in the background and adds it to the end of `tab`.
    /// `done` gets the new page id, or nil if the picture had no lines in it.
    func addPage(_ image: CGImage, to tab: String, done: ((String?) -> Void)? = nil) {
        working += 1
        queue.async { [weak self] in
            guard let self else { return }
            let id = Self.prefix + UUID().uuidString.prefix(12).lowercased()
            var ok = false
            if let page = ColoringConvert.page(from: image),
               let png = UIImage(cgImage: page.art).pngData(),
               let tpng = page.thumb.pngData() {
                ok = (try? png.write(to: self.url(id), options: .atomic)) != nil
                    && (try? tpng.write(to: self.url(id, thumb: true), options: .atomic)) != nil
            }
            DispatchQueue.main.async {
                self.working -= 1
                if ok, let i = self.tabs.firstIndex(where: { $0.id == tab }) {
                    self.tabs[i].pages.append(id)
                    self.persist()
                    done?(id)
                } else {
                    if ok { self.removeFiles(id) }
                    done?(nil)
                }
            }
        }
    }

    func deletePage(_ page: String) {
        removeFiles(page)
        for i in tabs.indices { tabs[i].pages.removeAll { $0 == page } }
        persist()
    }

    private func removeFiles(_ page: String) {
        try? FileManager.default.removeItem(at: url(page))
        try? FileManager.default.removeItem(at: url(page, thumb: true))
        thumbs.removeObject(forKey: page as NSString)
    }

    func lineArt(_ page: String) -> CGImage? {
        UIImage(contentsOfFile: url(page).path)?.cgImage
    }

    func thumbnail(_ page: String) -> UIImage? {
        if let t = thumbs.object(forKey: page as NSString) { return t }
        guard let img = UIImage(contentsOfFile: url(page, thumb: true).path) else { return nil }
        thumbs.setObject(img, forKey: page as NSString)
        return img
    }

    // MARK: In the book

    static let tints: [[Double]] = [
        [1.0, 0.55, 0.78], [0.62, 0.55, 1.0], [0.38, 0.72, 1.0], [0.4, 0.78, 0.6],
        [1.0, 0.62, 0.45], [0.95, 0.4, 0.5], [1.0, 0.75, 0.3], [0.5, 0.8, 0.85],
    ]

    /// The grown-up tabs as book categories: each shows its first page as its icon.
    var categories: [ColoringCategory] {
        tabs.enumerated().map { i, t in
            ColoringCategory(id: t.id, icon: "heart.fill", color: Self.tints[i % Self.tints.count], pages: t.pages, cover: t.pages.first)
        }
    }
}

// MARK: - Picture -> line art

enum ColoringConvert {
    static let width = 2048, height = 1536
    static let margin = 0.05

    struct Page { let art: CGImage; let thumb: UIImage }

    /// Cleans a printable coloring page (a web image, a screenshot, a photo of a printout) into line art:
    /// crops to the drawing, fits it on a 4:3 page, keeps only the dark lines (an adaptive threshold
    /// ignores paper shading), drops specks, and thickens the lines a little so small gaps close
    /// and the fill can't leak through thin lines. Nil if the picture has no lines.
    static func page(from image: CGImage) -> Page? {
        guard image.width > 8, image.height > 8, let crop = inkBounds(image) else { return nil }
        guard let cropped = image.cropping(to: crop) else { return nil }

        // Fit the drawing on the page.
        let W = width, H = height
        let boxW = Double(W) * (1 - 2 * margin), boxH = Double(H) * (1 - 2 * margin)
        let s = min(boxW / Double(cropped.width), boxH / Double(cropped.height))
        let dw = Double(cropped.width) * s, dh = Double(cropped.height) * s
        let rect = CGRect(x: (Double(W) - dw) / 2, y: (Double(H) - dh) / 2, width: dw, height: dh)
        var gray = render(cropped, width: W, height: H, in: rect)

        var ink = threshold(&gray, W, H)
        removeSpecks(&ink, W, H, minSize: 60)
        dilate(&ink, W, H, radius: 2)
        guard ink.contains(1) else { return nil }

        // Soften the edges a touch (the app treats alpha >= 145 as line).
        var alpha = [UInt8](repeating: 0, count: W * H)
        blur3(ink, into: &alpha, W, H)

        guard let art = lineImage(alpha, W, H) else { return nil }
        let thumb = thumbnail(art)
        return Page(art: art, thumb: thumb)
    }

    /// The drawing's bounding box in the image's pixel coordinates (top-left origin), padded a little.
    static func inkBounds(_ image: CGImage) -> CGRect? {
        let long = 800.0
        let k = min(1, long / Double(max(image.width, image.height)))
        let w = max(1, Int(Double(image.width) * k)), h = max(1, Int(Double(image.height) * k))
        let g = render(image, width: w, height: h, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where g[row + x] < 150 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let pad = 0.02 * Double(max(w, h))
        let x0 = max(0, (Double(minX) - pad) / k), y0 = max(0, (Double(minY) - pad) / k)
        let x1 = min(Double(image.width), (Double(maxX + 1) + pad) / k)
        let y1 = min(Double(image.height), (Double(maxY + 1) + pad) / k)
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0).integral
    }

    /// Draws `image` into `rect` of a white w x h grayscale canvas (row 0 at the top).
    static func render(_ image: CGImage, width w: Int, height h: Int, in rect: CGRect) -> [UInt8] {
        var buf = [UInt8](repeating: 255, count: w * h)
        buf.withUnsafeMutableBytes { raw in
            guard let c = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            c.setFillColor(gray: 1, alpha: 1)
            c.fill(CGRect(x: 0, y: 0, width: w, height: h))
            c.interpolationQuality = .high
            // CG's origin is bottom-left; flip `rect` so it is measured from the top like the buffer.
            c.draw(image, in: CGRect(x: rect.minX, y: CGFloat(h) - rect.maxY, width: rect.width, height: rect.height))
        }
        return buf
    }

    /// 1 where a pixel is a line: clearly darker than its surroundings, or just dark.
    static func threshold(_ g: inout [UInt8], _ w: Int, _ h: Int) -> [UInt8] {
        // Integral image for local means.
        let iw = w + 1
        var sum = [Int](repeating: 0, count: iw * (h + 1))
        for y in 0..<h {
            var run = 0
            let row = y * w
            for x in 0..<w {
                run += Int(g[row + x])
                sum[(y + 1) * iw + x + 1] = sum[y * iw + x + 1] + run
            }
        }
        let r = 28
        var out = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            let y0 = max(0, y - r), y1 = min(h, y + r + 1)
            for x in 0..<w {
                let v = Int(g[y * w + x])
                if v < 90 { out[y * w + x] = 1; continue }
                if v > 215 { continue }
                let x0 = max(0, x - r), x1 = min(w, x + r + 1)
                let total = sum[y1 * iw + x1] - sum[y0 * iw + x1] - sum[y1 * iw + x0] + sum[y0 * iw + x0]
                let mean = total / ((x1 - x0) * (y1 - y0))
                if v < mean - 25 { out[y * w + x] = 1 }
            }
        }
        return out
    }

    /// Clears blobs of ink smaller than `minSize` pixels (dust, noise, JPEG speckle).
    static func removeSpecks(_ m: inout [UInt8], _ w: Int, _ h: Int, minSize: Int) {
        var seen = [Bool](repeating: false, count: w * h)
        var stack = [Int](), blob = [Int]()
        stack.reserveCapacity(4096)
        for start in 0..<(w * h) where m[start] == 1 && !seen[start] {
            blob.removeAll(keepingCapacity: true)
            seen[start] = true
            stack.append(start)
            while let i = stack.popLast() {
                blob.append(i)
                let x = i % w, y = i / w
                if x > 0, m[i - 1] == 1, !seen[i - 1] { seen[i - 1] = true; stack.append(i - 1) }
                if x < w - 1, m[i + 1] == 1, !seen[i + 1] { seen[i + 1] = true; stack.append(i + 1) }
                if y > 0, m[i - w] == 1, !seen[i - w] { seen[i - w] = true; stack.append(i - w) }
                if y < h - 1, m[i + w] == 1, !seen[i + w] { seen[i + w] = true; stack.append(i + w) }
            }
            if blob.count < minSize { for i in blob { m[i] = 0 } }
        }
    }

    /// Grows ink by `radius` pixels (a square), in two passes.
    static func dilate(_ m: inout [UInt8], _ w: Int, _ h: Int, radius r: Int) {
        guard r > 0 else { return }
        var tmp = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            let row = y * w
            var last = -100_000
            // left-to-right then right-to-left: distance to nearest ink along the row
            for x in 0..<w {
                if m[row + x] == 1 { last = x }
                if x - last <= r { tmp[row + x] = 1 }
            }
            last = 100_000
            for x in stride(from: w - 1, through: 0, by: -1) {
                if m[row + x] == 1 { last = x }
                if last - x <= r { tmp[row + x] = 1 }
            }
        }
        for x in 0..<w {
            var last = -100_000
            for y in 0..<h {
                if tmp[y * w + x] == 1 { last = y }
                m[y * w + x] = y - last <= r ? 1 : 0
            }
            last = 100_000
            for y in stride(from: h - 1, through: 0, by: -1) {
                if tmp[y * w + x] == 1 { last = y }
                if last - y <= r { m[y * w + x] = 1 }
            }
        }
    }

    /// 3x3 box blur of a 0/1 mask into 0...255.
    static func blur3(_ m: [UInt8], into out: inout [UInt8], _ w: Int, _ h: Int) {
        for y in 0..<h {
            for x in 0..<w {
                var n = 0
                for dy in -1...1 {
                    let yy = y + dy
                    guard yy >= 0, yy < h else { continue }
                    for dx in -1...1 {
                        let xx = x + dx
                        guard xx >= 0, xx < w else { continue }
                        n += Int(m[yy * w + xx])
                    }
                }
                out[y * w + x] = UInt8(min(255, n * 255 / 6))
            }
        }
    }

    /// Black line art with `alpha` as its alpha channel (row 0 at the top).
    static func lineImage(_ alpha: [UInt8], _ w: Int, _ h: Int) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) { rgba[i * 4 + 3] = alpha[i] }   // premultiplied black: rgb stay 0
        return rgba.withUnsafeMutableBytes { raw -> CGImage? in
            guard let c = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
            return c.makeImage()
        }
    }

    static func thumbnail(_ art: CGImage) -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: art).draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Every page of a PDF as an image about 2048 px wide.
    static func images(fromPDF data: Data) -> [CGImage] {
        guard let provider = CGDataProvider(data: data as CFData), let doc = CGPDFDocument(provider) else { return [] }
        var out: [CGImage] = []
        let count = min(doc.numberOfPages, 40)
        guard count > 0 else { return [] }
        for n in 1...count {
            guard let page = doc.page(at: n) else { continue }
            let box = page.getBoxRect(.mediaBox)
            guard box.width > 0, box.height > 0 else { continue }
            let k = 2048 / max(box.width, box.height)
            let w = Int(box.width * k), h = Int(box.height * k)
            guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { continue }
            c.setFillColor(gray: 1, alpha: 1)
            c.fill(CGRect(x: 0, y: 0, width: w, height: h))
            c.scaleBy(x: k, y: k)
            c.translateBy(x: -box.minX, y: -box.minY)
            c.drawPDFPage(page)
            if let img = c.makeImage() { out.append(img) }
        }
        return out
    }

    /// Pictures in downloaded or picked data: an image, or each page of a PDF.
    static func images(from data: Data) -> [CGImage] {
        if data.starts(with: [0x25, 0x50, 0x44, 0x46]) { return images(fromPDF: data) }   // "%PDF"
        if let img = UIImage(data: data) { return [normalized(img)].compactMap { $0 } }
        return []
    }

    /// The image upright (applies EXIF orientation from camera photos).
    static func normalized(_ img: UIImage) -> CGImage? {
        if img.imageOrientation == .up, let cg = img.cgImage { return cg }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        let r = UIGraphicsImageRenderer(size: img.size, format: fmt)
        return r.image { _ in img.draw(in: CGRect(origin: .zero, size: img.size)) }.cgImage
    }
}
