import SwiftUI

/// How far the page is zoomed in. A point p on the page (in the canvas's own points) shows on screen at
/// `offset + p * scale`, so the page's top left corner sits at `offset`.
struct PageZoom: Equatable {
    var scale: CGFloat = 1
    var offset: CGPoint = .zero

    static let maxScale: CGFloat = 4

    var isZoomed: Bool { scale > 1.001 }

    /// The page point under a point on the screen.
    func toPage(_ v: CGPoint) -> CGPoint {
        CGPoint(x: (v.x - offset.x) / scale, y: (v.y - offset.y) / scale)
    }

    /// Keeps the scale between 1 and `maxScale` and the page covering the whole canvas (no gaps at the edges).
    func clamped(to size: CGSize) -> PageZoom {
        let s = min(PageZoom.maxScale, max(1, scale))
        return PageZoom(scale: s, offset: CGPoint(x: min(0, max(size.width - size.width * s, offset.x)),
                                                  y: min(0, max(size.height - size.height * s, offset.y))))
    }

    /// A two-finger pinch: the page point that was under the fingers' middle at the start stays under it,
    /// and the page grows or shrinks with the distance between the fingers.
    static func pinch(from start: PageZoom, startCenter c0: CGPoint, startDistance d0: CGFloat,
                      center c: CGPoint, distance d: CGFloat, in size: CGSize) -> PageZoom {
        let s = min(maxScale, max(1, start.scale * d / max(1, d0)))
        let anchor = start.toPage(c0)
        return PageZoom(scale: s, offset: CGPoint(x: c.x - anchor.x * s, y: c.y - anchor.y * s)).clamped(to: size)
    }
}

/// The zoom of one page. The canvas sets it while she pinches; the stickers and the reset button follow it.
final class ColoringZoom: ObservableObject {
    @Published private(set) var zoom = PageZoom()

    /// Set by the canvas view: moves the paper's layers (animated or not).
    var apply: (PageZoom, Bool) -> Void = { _, _ in }

    func set(_ z: PageZoom) {
        guard z != zoom else { return }
        zoom = z
        apply(z, false)
    }

    /// Back to the whole page, with a short glide.
    func reset() {
        guard zoom != PageZoom() else { return }
        withAnimation(.easeOut(duration: ColoringZoom.glide)) { zoom = PageZoom() }
        apply(zoom, true)
    }

    static let glide = 0.25
}

/// Shows its content zoomed like the page, so stickers and fill sparkles stay on the right spot.
struct ColoringZoomed<Content: View>: View {
    @ObservedObject var zoom: ColoringZoom
    let content: Content

    init(zoom: ColoringZoom, @ViewBuilder content: () -> Content) {
        self.zoom = zoom
        self.content = content()
    }

    var body: some View {
        ZStack { content }
            .scaleEffect(zoom.zoom.scale, anchor: .topLeading)
            .offset(x: zoom.zoom.offset.x, y: zoom.zoom.offset.y)
    }
}

/// A big "see the whole page" button that appears while the page is zoomed in.
struct ColoringZoomResetButton: View {
    @ObservedObject var zoom: ColoringZoom

    var body: some View {
        ZStack {
            if zoom.zoom.isZoomed {
                ColoringButton(icon: "arrow.down.right.and.arrow.up.left", tint: Theme.pink) { zoom.reset() }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 72, height: 72)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: zoom.zoom.isZoomed)
    }
}
