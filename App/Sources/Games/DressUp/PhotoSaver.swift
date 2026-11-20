import SwiftUI
import UIKit

/// Saves a look as a portrait picture (good as a wallpaper), with its stickers and frame, to the Photos library.
enum PhotoSaver {
    static let size = CGSize(width: 1080, height: 1620)

    @MainActor
    static func image(for look: Look) -> UIImage? {
        let view = PhotoView(look: look)
            .frame(width: size.width, height: size.height)
        let r = ImageRenderer(content: view)
        r.scale = 1
        return r.uiImage
    }

    @MainActor
    static func save(_ look: Look) -> Bool {
        guard let img = image(for: look) else { return false }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        return true
    }
}
