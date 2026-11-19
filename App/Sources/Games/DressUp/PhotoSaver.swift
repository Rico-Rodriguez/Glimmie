import SwiftUI
import UIKit

/// Saves a look as a portrait picture (good as a wallpaper) to the Photos library.
enum PhotoSaver {
    static let size = CGSize(width: 1080, height: 1620)

    @MainActor
    static func image(for look: Look) -> UIImage? {
        let view = ZStack(alignment: .bottom) {
            SceneView(bg: look.bg)
            DollView(look: look, box: DressUpView.stageBox)
                .frame(width: size.width * 0.92, height: size.width * 0.92 * DressUpView.stageBox.height / DressUpView.stageBox.width)
                .padding(.bottom, size.height * 0.04)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
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
