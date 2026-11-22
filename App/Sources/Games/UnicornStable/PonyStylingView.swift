import SwiftUI
import WebKit

struct PonyStylingSave: Codable, Equatable {
    static let folder = "UnicornStable"
    static let file = "pony-styling.json"
    private static let pigments: Set<String> = ["", "#db5793", "#ee8763", "#efb943", "#57b68f", "#579fe6", "#a56cd6"]
    private static let motifs: Set<String> = ["", "✦", "♥"]

    var packed = [1.0, 0, 0, 1]
    var brushed = Array(repeating: 0.0, count: 4)
    var soles = Array(repeating: [1.0, 1, 1], count: 4)
    var maneStep = 0
    var maneProgress = 0.0
    var braidStyle = 0
    var crossed = 0
    var maneColors = Array(repeating: "", count: 4)
    var hoofColors = Array(repeating: "", count: 4)
    var hoofGlitter = Array(repeating: false, count: 4)
    var padColor = ""
    var hasSaddle = false
    var girth = 0
    var bow = ""
    var padMarks = Array(repeating: "", count: 3)
    var scratched = false

    var isValid: Bool {
        [packed, brushed].allSatisfy { $0.count == 4 && $0.allSatisfy { (0...1).contains($0) } }
            && soles.count == 4 && soles.allSatisfy { $0.count == 3 && $0.allSatisfy { (0...1).contains($0) } }
            && (0...4).contains(maneStep) && (0...1).contains(maneProgress)
            && (0...2).contains(braidStyle) && (0...(max(0, min(braidStyle, 2)) * 2)).contains(crossed)
            && [maneColors, hoofColors].allSatisfy { $0.count == 4 && $0.allSatisfy(Self.pigments.contains) }
            && hoofGlitter.count == 4
            && ["", "mint", "lilac"].contains(padColor) && (!hasSaddle || !padColor.isEmpty)
            && (0...5).contains(girth) && ["", "lilac", "rose"].contains(bow)
            && padMarks.count == 3 && padMarks.allSatisfy(Self.motifs.contains)
    }

    static func received(_ payload: String) -> Self? {
        guard payload.utf8.count <= 4096,
              let value = try? JSONDecoder().decode(Self.self, from: Data(payload.utf8)), value.isValid else { return nil }
        return value
    }

    static func load() -> Self {
        if let save = GameStorage.load(Self.self, game: folder, file: file), save.isValid { return save }
        struct PlaytestSave: Decodable {
            struct Tack: Decodable {
                var saddle: String
                var ribbons: Bool
            }
            var tack: Tack?
        }
        var save = Self()
        if let old = GameStorage.load(PlaytestSave.self, game: folder, file: "pony-mane.json")?.tack {
            if ["mint", "lilac"].contains(old.saddle) {
                save.padColor = old.saddle
                save.hasSaddle = true
                save.girth = 3
            }
            if old.ribbons { save.bow = "lilac" }
        } else {
            struct ClassicSave: Decodable { var look: UnicornLook }
            if let look = GameStorage.load(ClassicSave.self, game: UnicornGame.id, file: "stable.json")?.look {
                save.braidStyle = look.braided ? 1 : 0
                save.crossed = save.braidStyle * 2
                if look.gear == .bow { save.bow = "lilac" }
                if look.gear == .saddle {
                    save.padColor = "mint"
                    save.hasSaddle = true
                    save.girth = 3
                }
            }
        }
        return save
    }

    func store() { GameStorage.save(self, game: Self.folder, file: Self.file) }
}

enum PonyStylingPage {
    static let url = GameFiles.url("stable", "html", game: "UnicornStyling")

    static func initialScript(for save: PonyStylingSave) -> String {
        var script = ""
        if let data = try? JSONEncoder().encode(save), let json = String(data: data, encoding: .utf8) {
            script += "window.glimmieStableSave = \(json);"
        }
        // Use an origin-clean image for WebGL and Canvas even in a file-based view.
        if let texture = GameFiles.url("pony", "webp", game: "UnicornStyling"), let data = try? Data(contentsOf: texture) {
            script += "window.glimmiePonyTexture = 'data:image/webp;base64,\(data.base64EncodedString())';"
        }
        return script
    }
}

@MainActor struct PonyStylingView: View {
    let exit: () -> Void
    let classic: (@escaping () -> Void) -> AnyView
    @State private var failed = false
    @State private var attempt = 0
    @State private var showsClassic = false

    var body: some View {
        if showsClassic {
            classic { showsClassic = false }
        } else {
            stable
        }
    }

    private var stable: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: 0xFFF4DF).ignoresSafeArea()
            if failed {
                VStack(spacing: 14) {
                    Text("The stable couldn’t open.")
                        .font(.title2.weight(.semibold))
                    Button("Try again") {
                        attempt += 1
                        failed = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.ink)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PonyStylingHost(onFailure: { failed = true }, openClassic: { showsClassic = true })
                    .id(attempt)
            }
            HomeButton(action: exit)
                .scaleEffect(0.72, anchor: .topLeading)
                .frame(width: 52, height: 52, alignment: .topLeading)
                .padding(8)
                .accessibilityLabel("Back to games")
        }
    }
}

@MainActor private struct PonyStylingHost: UIViewRepresentable {
    var onFailure: () -> Void
    var openClassic: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFailure: onFailure, openClassic: openClassic) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: PonyStylingPage.initialScript(for: PonyStylingSave.load()),
                                              injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.add(context.coordinator, name: Coordinator.channel)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController = controller
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.bounces = false
        view.scrollView.pinchGestureRecognizer?.isEnabled = false
        view.allowsLinkPreview = false
        if let url = PonyStylingPage.url {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            DispatchQueue.main.async { context.coordinator.onFailure() }
        }
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.onFailure = onFailure
        context.coordinator.openClassic = openClassic
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.channel)
        view.navigationDelegate = nil
        view.stopLoading()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let channel = "unicornStable"
        var onFailure: () -> Void
        var openClassic: () -> Void
        private var lastSound: TimeInterval = -.infinity

        init(onFailure: @escaping () -> Void, openClassic: @escaping () -> Void) {
            self.onFailure = onFailure
            self.openClassic = openClassic
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.channel, message.frameInfo.isMainFrame,
                  let event = message.body as? [String: String] else { return }
            if event["kind"] == "save", let payload = event["value"], let save = PonyStylingSave.received(payload) {
                save.store()
            } else if event["kind"] == "classicStable" {
                openClassic()
            } else if event["kind"] == "sparkle" {
                let now = ProcessInfo.processInfo.systemUptime
                guard now - lastSound > 0.16 else { return }
                lastSound = now
                Sound.shared.play(.sparkle, volume: 0.37)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.request.url == PonyStylingPage.url ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onFailure()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onFailure()
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { onFailure() }
    }
}
