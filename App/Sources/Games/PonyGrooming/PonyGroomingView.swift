import SceneKit
import SwiftUI
import simd

@MainActor struct PonyGroomingView: View {
    let exit: () -> Void
    @State private var brushing = true
    @State private var close = false
    @State private var tangled = PonyScene.savedMane().tangled
    @State private var halter = false
    @State private var brushPoint: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 550
            ZStack {
                if PonySceneHost.assetPresent {
                    PonySceneHost(brushing: brushing, close: close, tangled: tangled, halter: halter,
                                  reduceMotion: reduceMotion, brushPoint: $brushPoint)
                    if let brushPoint {
                        ZStack(alignment: .bottomTrailing) {
                            PetPropThumb(name: "brush")
                                .frame(width: 57, height: 57)
                                .rotationEffect(.degrees(-19))
                                .shadow(color: Theme.ink.opacity(0.26), radius: 4, y: 3)
                        }
                        .position(x: brushPoint.x - 19, y: brushPoint.y - 21)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                } else {
                    Color(hex: 0xE0C7E7)
                    Text("The pony model couldn’t load.")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                VStack(spacing: 0) {
                    HStack {
                        HomeButton(action: exit)
                            .scaleEffect(compact ? 0.68 : 0.84)
                            .accessibilityLabel("Back to games")
                        Spacer()
                        control(close ? "minus.magnifyingglass" : "plus.magnifyingglass",
                                label: close ? "Show the whole pony" : "Zoom in on the mane",
                                size: compact ? 48 : 62, selected: close) {
                            close.toggle()
                            Sound.shared.play(.whoosh, volume: 0.45)
                        }
                        .padding(.trailing, 19)
                    }
                    .padding(.top, compact ? 0 : 9)
                    Spacer()
                    tray(size: compact ? 48 : 68)
                        .padding(.bottom, compact ? 9 : 19)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func tray(size: CGFloat) -> some View {
        HStack(spacing: size * 0.26) {
            Button { selectBrush(true) } label: {
                PetPropThumb(name: "brush")
                    .frame(width: size * 0.75, height: size * 0.75)
                    .frame(width: size, height: size)
                    .background(.white, in: Circle())
                    .overlay(Circle().strokeBorder(brushing ? Theme.pink : Theme.blush, lineWidth: brushing ? 4 : 2))
            }
            .buttonStyle(Squish())
            .accessibilityLabel("Brush the mane or tail")
            .accessibilityAddTraits(brushing ? .isSelected : [])
            control("arrow.trianglehead.clockwise.rotate.90", label: "Turn the camera", size: size, selected: !brushing,
                    fallback: "arrow.triangle.2.circlepath") { selectBrush(false) }
            control("scribble.variable", label: "Optional tangles", size: size, selected: tangled) {
                tangled.toggle()
                Sound.shared.play(.pop, volume: 0.49)
            }
            control("link", label: "Mint halter", size: size, selected: halter) {
                halter.toggle()
                Sound.shared.play(.pop, volume: 0.49)
            }
        }
        .padding(.horizontal, size * 0.30)
        .padding(.vertical, size * 0.14)
        .background(Color(hex: 0xFFF3DC), in: Capsule())
        .overlay(Capsule().strokeBorder(Color(hex: 0xB8D9C4), lineWidth: 3))
        .shadow(color: Theme.ink.opacity(0.24), radius: 9, y: 4)
    }

    private func selectBrush(_ selected: Bool) {
        brushing = selected
        brushPoint = nil
        Sound.shared.play(.pop, volume: 0.45)
    }

    private func control(_ symbol: String, label: String, size: CGFloat, selected: Bool,
                         fallback: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: fallback.flatMap { UIImage(systemName: symbol) == nil ? $0 : nil } ?? symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: size, height: size)
                .background(.white, in: Circle())
                .overlay(Circle().strokeBorder(selected ? Theme.pink : Theme.blush, lineWidth: selected ? 4 : 2))
        }
        .buttonStyle(Squish())
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

@MainActor private struct PonySceneHost: UIViewRepresentable {
    let brushing: Bool
    let close: Bool
    let tangled: Bool
    let halter: Bool
    let reduceMotion: Bool
    @Binding var brushPoint: CGPoint?

    static var assetPresent: Bool { GameFiles.url("pony", "mesh", game: "PonyGrooming") != nil }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.88, green: 0.78, blue: 0.91, alpha: 1)
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling2X
        view.allowsCameraControl = false
        view.rendersContinuously = true
        context.coordinator.install(on: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let driver = context.coordinator
        driver.brushing = brushing
        driver.reducedMotion = reduceMotion
        driver.cursor = { brushPoint = $0 }
        driver.model?.detail(close)
        driver.model?.setTangled(tangled)
        driver.model?.setTack(halter)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor final class Coordinator: NSObject {
        fileprivate let model = PonyScene()
        fileprivate var brushing = true
        fileprivate var reducedMotion = false
        fileprivate var cursor: ((CGPoint?) -> Void)?
        private weak var view: SCNView?
        private var link: CADisplayLink?
        private var timestamp: CFTimeInterval?
        private var startTime: CFTimeInterval?
        private var previousPoint: CGPoint?
        private var previousWorld: SIMD3<Float>?
        private var isStroke = false
        private var lastSound: CFTimeInterval = 0

        fileprivate func install(on view: SCNView) {
            self.view = view
            guard let model else { return }
            view.scene = model.scene
            view.pointOfView = model.camera
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            pan.maximumNumberOfTouches = 1
            view.addGestureRecognizer(pan)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
            tap.require(toFail: pan)
            view.addGestureRecognizer(tap)
            view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
            view.isAccessibilityElement = true
            view.accessibilityLabel = "Standing pony. Drag the brush through the mane and tail or turn the camera."
            let display = CADisplayLink(target: self, selector: #selector(frame(_:)))
            display.preferredFramesPerSecond = 30
            display.add(to: .main, forMode: .common)
            link = display
        }

        fileprivate func stop() {
            model?.flush()
            link?.invalidate()
            link = nil
        }

        @objc private func frame(_ link: CADisplayLink) {
            let dt = Float(link.timestamp - (timestamp ?? link.timestamp - 1 / 30))
            timestamp = link.timestamp
            if startTime == nil { startTime = link.timestamp }
            model?.frame(time: link.timestamp - (startTime ?? link.timestamp) + 0.9, dt: min(dt, 1 / 30), reducedMotion: reducedMotion)
        }

        @objc private func pan(_ incoming: UIPanGestureRecognizer) {
            guard let view, let model else { return }
            let p = incoming.location(in: view)
            switch incoming.state {
            case .began:
                let native = incoming.translation(in: view)
                let start = CGPoint(x: p.x - native.x, y: p.y - native.y)
                isStroke = brushing && (hit(start, in: view) != nil || hit(p, in: view) != nil)
                previousPoint = start
                previousWorld = nil
                fallthrough
            case .changed:
                guard let from = previousPoint else { return }
                if isStroke {
                    let dx = p.x - from.x, dy = p.y - from.y
                    let count = min(8, max(1, Int(hypot(dx, dy) / 10)))
                    for i in 1...count {
                        let t = CGFloat(i) / CGFloat(count)
                        stroke(at: CGPoint(x: from.x + dx * t, y: from.y + dy * t), in: view,
                               screenDelta: CGPoint(x: dx / CGFloat(count), y: dy / CGFloat(count)))
                    }
                    cursor?(p)
                } else {
                    model.turn(p.x - from.x)
                }
                previousPoint = p
            default:
                previousPoint = nil
                previousWorld = nil
                cursor?(nil)
                model.flush()
            }
        }

        @objc private func tap(_ tap: UITapGestureRecognizer) {
            guard brushing, let view else { return }
            stroke(at: tap.location(in: view), in: view, screenDelta: CGPoint(x: 0, y: 12))
            previousWorld = nil
            model?.flush()
        }

        @objc private func pinch(_ pinch: UIPinchGestureRecognizer) {
            if pinch.state == .changed { model?.zoom(pinch.scale); pinch.scale = 1 }
        }

        private func hit(_ point: CGPoint, in view: SCNView) -> SCNHitTestResult? {
            view.hitTest(point, options: [SCNHitTestOption.categoryBitMask: 3,
                                         SCNHitTestOption.ignoreHiddenNodes: true,
                                         SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue]).first
        }

        private func stroke(at point: CGPoint, in view: SCNView, screenDelta: CGPoint) {
            guard let result = hit(point, in: view), let name = result.node.name, name.hasPrefix("lock-"),
                  let index = Int(name.dropFirst(5)), let model else {
                previousWorld = nil
                return
            }
            let w = result.worldCoordinates
            let world = SIMD3<Float>(w.x, w.y, w.z)
            let basis = model.camera.simdWorldTransform
            let right = SIMD3<Float>(basis.columns.0.x, basis.columns.0.y, basis.columns.0.z)
            let up = SIMD3<Float>(basis.columns.1.x, basis.columns.1.y, basis.columns.1.z)
            let inferred = right * (Float(screenDelta.x) * 0.005) - up * (Float(screenDelta.y) * 0.005)
            let movement = previousWorld.map { world - $0 } ?? inferred
            previousWorld = world
            guard simd_length_squared(movement) > 0.000001 else { return }
            model.brush(hit: result, index: index, delta: simd_length(movement) < 0.3 ? movement : inferred)
            let now = CACurrentMediaTime()
            if now - lastSound > 0.33 {
                lastSound = now
                Sound.shared.play(.whoosh, volume: 0.25)
            }
        }
    }
}
