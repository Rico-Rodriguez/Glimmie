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
    @discardableResult
    static func save(_ look: Look) -> Bool {
        guard let img = image(for: look) else { return false }
        SaveTarget(completion: nil).start(image: img)
        return true
    }

    @MainActor
    static func save(_ look: Look, completion: @escaping (Bool) -> Void) {
        guard let img = image(for: look) else {
            completion(false)
            return
        }
        SaveTarget(completion: completion).start(image: img)
    }

    @MainActor
    @discardableResult
    static func save(image: UIImage, completion: ((Bool) -> Void)? = nil) -> Bool {
        SaveTarget(completion: completion).start(image: image)
        return true
    }
}

private final class SaveTarget: NSObject {
    private static var active: [ObjectIdentifier: SaveTarget] = [:]
    private let completion: ((Bool) -> Void)?

    init(completion: ((Bool) -> Void)?) {
        self.completion = completion
        super.init()
    }

    func start(image: UIImage) {
        let key = ObjectIdentifier(self)
        Self.active[key] = self
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinish(_:error:contextInfo:)), nil)
    }

    @objc private func didFinish(_ image: UIImage, error: NSError?, contextInfo: UnsafeRawPointer?) {
        let key = ObjectIdentifier(self)
        Self.active.removeValue(forKey: key)
        let ok = (error == nil)
        DispatchQueue.main.async {
            self.completion?(ok)
        }
    }
}
