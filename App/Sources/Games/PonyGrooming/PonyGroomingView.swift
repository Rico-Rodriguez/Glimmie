import SceneKit
import SwiftUI
import simd

@MainActor struct PonyGroomingView: View {
    let exit: () -> Void
    @State private var brushing = true
    @State private var close = false
    @State private var tangled = PonyScene.savedGrooming().tangled
    @State private var outfit = PonyScene.savedGrooming().outfit
    @State private var spotsLeft = PonyScene.savedGrooming().spotsLeft
    @State private var groomingRound = 0
    @State private var tackTray = false
    @State private var brushPoint: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 550
            ZStack {
                if PonySceneHost.assetPresent {
                    PonySceneHost(brushing: brushing && !tackTray, close: close, tangled: tangled, outfit: outfit,
                                  groomingRound: groomingRound, reduceMotion: reduceMotion,
                                  brushPoint: $brushPoint, spotsLeft: $spotsLeft)
                    if let brushPoint {
                        PonyToolArt.brush.icon(fallback: "paintbrush")
                            .frame(width: 68, height: 68)
                            .shadow(color: Theme.ink.opacity(0.26), radius: 4, y: 3)
                            .position(x: brushPoint.x + 15, y: brushPoint.y + 7)
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
                        if !tackTray { coatStatus }
                        Spacer()
                        control(close ? "minus.magnifyingglass" : "plus.magnifyingglass",
                                label: close ? "Show the whole pony" : "Zoom in",
                                size: compact ? 45 : 56, selected: close, showLabel: false) {
                            close.toggle()
                            Sound.shared.play(.whoosh, volume: 0.45)
                        }
                        .padding(.trailing, 19)
                    }
                    .padding(.top, compact ? 0 : 9)
                    Spacer()
                    tray(size: compact ? 42 : 60)
                        .padding(.bottom, compact ? 10 : 23)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func tray(size: CGFloat) -> some View {
        HStack(spacing: size * 0.37) {
            if tackTray {
                control("chevron.left", label: "Groom", size: size, selected: false) { toggleTray() }
                control("link", label: "Halter", size: size, selected: outfit.halter, art: .halter, tint: Theme.mint) {
                    outfit.halter.toggle()
                    Sound.shared.play(.pop, volume: 0.49)
                }
                control("square.stack", label: "Saddle", size: size, selected: outfit.saddle != .bareback,
                        art: .saddle, tint: outfit.saddle == .lilac ? Theme.lilac : Theme.mint) {
                    switch outfit.saddle {
                    case .bareback: outfit.saddle = .mint
                    case .mint: outfit.saddle = .lilac
                    case .lilac: outfit.saddle = .bareback
                    }
                    Sound.shared.play(.pop, volume: 0.49)
                }
                .accessibilityValue(outfit.saddle.label)
                control("gift.fill", label: "Ribbon", size: size, selected: outfit.ribbons, art: .ribbon, tint: Theme.lilac) {
                    outfit.ribbons.toggle()
                    Sound.shared.play(.pop, volume: 0.49)
                }
            } else {
                tool(label: "Brush", size: size, selected: brushing) {
                    selectBrush(true)
                } icon: {
                    PonyToolArt.brush.icon(fallback: "paintbrush").frame(width: size * 0.88, height: size * 0.88)
                }
                .accessibilityHint("Brush the coat, mane, or tail")
                control("arrow.triangle.2.circlepath", label: "Turn", size: size, selected: !brushing) { selectBrush(false) }
                control("scribble.variable", label: "Tangles", size: size, selected: tangled) {
                    tangled.toggle()
                    Sound.shared.play(.pop, volume: 0.49)
                }
                control("suitcase.fill", label: "Tack", size: size, selected: false) { toggleTray() }
            }
        }
        .padding(.horizontal, size * 0.55)
        .padding(.vertical, size * 0.15)
        .background(Color(hex: 0xFFF3DC), in: Capsule())
        .overlay(Capsule().strokeBorder(Color(hex: 0xB8D9C4), lineWidth: 3))
        .shadow(color: Theme.ink.opacity(0.24), radius: 9, y: 4)
    }

    @ViewBuilder private var coatStatus: some View {
        if spotsLeft == 0 {
            Button {
                groomingRound += 1
                spotsLeft = PonyDustSite.all.count
                Sound.shared.play(.pop, volume: 0.45)
            } label: {
                badge("Coat clean · Brush again", symbol: "sparkles")
            }
            .buttonStyle(Squish())
        } else if outfit.saddle != .bareback {
            badge("Unsaddle to brush underneath", symbol: "sparkle")
        } else {
            badge(spotsLeft == 1 ? "1 dusty spot" : "\(spotsLeft) dusty spots", symbol: "sparkle")
        }
    }

    private func badge(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color(hex: 0xFFF3DC), in: Capsule())
    }

    private func toggleTray() {
        tackTray.toggle()
        brushPoint = nil
        Sound.shared.play(.pop, volume: 0.45)
    }

    private func selectBrush(_ selected: Bool) {
        brushing = selected
        brushPoint = nil
        Sound.shared.play(.pop, volume: 0.45)
    }

    private func control(_ symbol: String, label: String, size: CGFloat, selected: Bool,
                         art: PonyToolArt? = nil, tint: Color = Theme.mint, showLabel: Bool = true,
                         action: @escaping () -> Void) -> some View {
        tool(label: label, size: size, selected: selected, tint: tint, showLabel: showLabel, action: action) {
            if let art {
                art.icon(fallback: symbol).frame(width: size * 0.88, height: size * 0.88)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    private func tool<Icon: View>(label: String, size: CGFloat, selected: Bool, tint: Color = Theme.mint,
                                  showLabel: Bool = true, action: @escaping () -> Void,
                                  @ViewBuilder icon: () -> Icon) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                icon()
                    .frame(width: size, height: size)
                    .background(selected ? tint.opacity(0.7) : Color(hex: 0xFFFCF4), in: Circle())
                    .overlay(Circle().strokeBorder(selected ? Color(hex: 0x6E9E8B) : Color(hex: 0xE7CEAA),
                                                   lineWidth: selected ? 2.5 : 1.5))
                if showLabel {
                    Text(label)
                        .font(.system(size: size < 50 ? 11 : 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(Squish())
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

@MainActor private enum PonyToolArt: String, CaseIterable {
    case brush, halter, saddle, ribbon

    private static let images = Dictionary(uniqueKeysWithValues: allCases.compactMap { item -> (PonyToolArt, UIImage)? in
        guard let url = GameFiles.url("tool-\(item.rawValue)", "png", game: "PonyGrooming"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        return (item, image)
    })

    @ViewBuilder func icon(fallback: String) -> some View {
        if let image = Self.images[self] {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: fallback).foregroundStyle(Theme.ink)
        }
    }
}

@MainActor private struct PonySceneHost: UIViewRepresentable {
    let brushing: Bool
    let close: Bool
    let tangled: Bool
    let outfit: PonyTack
    let groomingRound: Int
    let reduceMotion: Bool
    @Binding var brushPoint: CGPoint?
    @Binding var spotsLeft: Int

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
        driver.coatStatus = { if spotsLeft != $0 { spotsLeft = $0 } }
        driver.model?.detail(close)
        driver.model?.setTangled(tangled)
        driver.model?.setTack(outfit)
        if driver.groomingRound != groomingRound {
            driver.groomingRound = groomingRound
            driver.model?.dustCoat()
        }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor final class Coordinator: NSObject {
        fileprivate let model = PonyScene()
        fileprivate var brushing = true
        fileprivate var reducedMotion = false
        fileprivate var cursor: ((CGPoint?) -> Void)?
        fileprivate var coatStatus: ((Int) -> Void)?
        fileprivate var groomingRound = 0
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
            view.accessibilityLabel = "Standing pony. Brush the coat, mane, and tail. Drag the stable to turn."
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
                isStroke = brushing && (model.canBrush(hit(start, in: view)) || model.canBrush(hit(p, in: view)))
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
            guard let model, let result = hit(point, in: view), model.canBrush(result) else {
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
            let spotsBefore = model.spotsLeft
            model.brush(hit: result, delta: simd_length(movement) < 0.3 ? movement : inferred)
            let spotsAfter = model.spotsLeft
            if spotsAfter < spotsBefore {
                coatStatus?(spotsAfter)
                if spotsAfter == 0 { Sound.shared.play(.sparkle, volume: 0.62) }
            }
            let now = CACurrentMediaTime()
            if now - lastSound > 0.33 {
                lastSound = now
                Sound.shared.play(.whoosh, volume: 0.25)
            }
        }
    }
}
