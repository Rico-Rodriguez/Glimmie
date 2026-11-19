import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import WebKit

// MARK: - Grown-up pages screen
//
// Behind the held gear in the book. Grown-ups make tabs (Teenieping, Bluey, ...), fill them from
// Photos, Files or the page finder, rename, reorder and delete. This screen uses words: it is for
// grown-ups, not for her.

struct ColoringGrownUpView: View {
    /// Called with the tab to show in the book (or nil).
    let onDone: (String?) -> Void
    @ObservedObject private var store = ColoringCustom.shared
    @State private var selected: String?
    @State private var naming = false
    @State private var newName = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var finding = false
    @State private var askDeleteTab = false
    @State private var askDeletePage: String?
    @State private var note: String?

    private var tab: ColoringCustomTab? { store.tabs.first { $0.id == selected } ?? store.tabs.first }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                ColoringButton(icon: "checkmark", tint: Theme.mint) { onDone(tab?.id) }
                Text("Grown-up pages").font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                Spacer()
                if store.working > 0 {
                    ProgressView().scaleEffect(1.3)
                    Text("Adding \(store.working) page\(store.working == 1 ? "" : "s")…")
                        .font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(Theme.ink)
                } else if let note {
                    Text(note).font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(Theme.ink)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            HStack(alignment: .top, spacing: 18) {
                tabList.frame(width: 280)
                if let tab {
                    tabDetail(tab)
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        Text("Make a tab for each kind of page,\nlike Teenieping, Bluey or Princesses.")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundStyle(Theme.ink)
                        bigButton("New tab", icon: "plus", tint: Theme.pink) { newName = ""; naming = true }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .alert("New tab", isPresented: $naming) {
            TextField("Name", text: $newName)
            Button("Add") { selected = store.addTab(name: newName) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this tab and all its pages?", isPresented: $askDeleteTab, titleVisibility: .visible) {
            Button("Delete tab", role: .destructive) {
                if let id = tab?.id { store.deleteTab(id) }
                selected = store.tabs.first?.id
            }
        }
        .confirmationDialog("Delete this page?", isPresented: Binding(get: { askDeletePage != nil }, set: { if !$0 { askDeletePage = nil } }),
                            titleVisibility: .visible) {
            Button("Delete page", role: .destructive) { if let p = askDeletePage { store.deletePage(p) }; askDeletePage = nil }
        }
        .onChange(of: photoItems) { items in
            guard !items.isEmpty, let target = tab?.id else { return }
            photoItems = []
            for item in items {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run { add(data, to: target) }
                    }
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image, .pdf], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result, let target = tab?.id else { return }
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                let data = try? Data(contentsOf: url)
                if scoped { url.stopAccessingSecurityScopedResource() }
                if let data { add(data, to: target) }
            }
        }
        .fullScreenCover(isPresented: $finding) {
            if let tab {
                ColoringPageFinder(tabName: tab.name, onAdd: { data in add(data, to: tab.id) }, onClose: { finding = false })
            }
        }
    }

    private func add(_ data: Data, to target: String) {
        let images = ColoringConvert.images(from: data)
        if images.isEmpty { note = "That file isn't a picture."; return }
        for img in images {
            store.addPage(img, to: target) { id in note = id == nil ? "One picture had no lines to color." : nil }
        }
    }

    private var tabList: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(store.tabs.enumerated()), id: \.element.id) { i, t in
                        Button { selected = t.id } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12).fill(.white)
                                    if let c = t.pages.first, let img = store.thumbnail(c) {
                                        Image(uiImage: img).resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "heart.fill").foregroundStyle(Theme.pink)
                                    }
                                }
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.name).font(.system(size: 20, weight: .bold, design: .rounded)).lineLimit(1)
                                    Text("\(t.pages.count) page\(t.pages.count == 1 ? "" : "s")").font(.system(size: 15, design: .rounded))
                                }
                                .foregroundStyle(Theme.ink)
                                Spacer()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 18).fill(t.id == tab?.id ? Theme.blush : .white.opacity(0.7)))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(t.id == tab?.id ? Theme.pink : .clear, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tab-\(i)")
                    }
                }
            }
            bigButton("New tab", icon: "plus", tint: Theme.pink) { newName = ""; naming = true }
        }
    }

    @ViewBuilder
    private func tabDetail(_ t: ColoringCustomTab) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TextField("Tab name", text: Binding(get: { t.name }, set: { store.rename(tab: t.id, to: $0) }))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white))
                    .frame(maxWidth: 360)
                smallButton("arrow.up") { store.move(tab: t.id, by: -1) }
                smallButton("arrow.down") { store.move(tab: t.id, by: 1) }
                Spacer()
                smallButton("trash.fill", tint: Theme.peach) { askDeleteTab = true }
            }
            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 50, matching: .images) {
                    label("Photos", icon: "photo.on.rectangle", tint: Theme.sky)
                }
                bigButton("Files", icon: "folder.fill", tint: Theme.lilac) { importing = true }
                bigButton("Find pages online", icon: "safari.fill", tint: Theme.pink) { finding = true }
            }
            if t.pages.isEmpty {
                Text("Add coloring pages from Photos, Files (pictures or PDFs) or the web.\nEach one becomes a tap-to-fill page in this tab.")
                    .font(.system(size: 20, design: .rounded)).foregroundStyle(Theme.ink)
                    .padding(.top, 20)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 16)], spacing: 16) {
                        ForEach(t.pages, id: \.self) { p in
                            ZStack(alignment: .topTrailing) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16).fill(.white)
                                    if let img = store.thumbnail(p) { Image(uiImage: img).resizable().scaledToFit().padding(6) }
                                }
                                .aspectRatio(4 / 3, contentMode: .fit)
                                Button { askDeletePage = p } label: {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 30)).foregroundStyle(.white, Theme.peach)
                                }
                                .padding(4)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Capsule().fill(tint))
    }

    private func bigButton(_ text: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { label(text, icon: icon, tint: tint) }.buttonStyle(Squish())
    }

    private func smallButton(_ icon: String, tint: Color = Theme.lilac, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                .frame(width: 46, height: 46).background(Circle().fill(tint))
        }
        .buttonStyle(Squish())
    }
}

// MARK: - Page finder (a small browser)
//
// Search or open any coloring site, turn on "Tap a picture", and tap the page you want: the
// biggest version of that picture (the image itself, or the file its link points to) is
// downloaded and added to the tab. A page that is itself a picture or a PDF can be added whole.

struct ColoringPageFinder: View {
    let tabName: String
    let onAdd: (Data) -> Void
    let onClose: () -> Void
    @StateObject private var web = FinderWeb()
    @State private var query = ""
    @State private var added = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button("Done", action: onClose).font(.system(size: 18, weight: .bold))
                Button { web.view.goBack() } label: { Image(systemName: "chevron.backward") }.disabled(!web.canGoBack)
                Button { web.view.goForward() } label: { Image(systemName: "chevron.forward") }.disabled(!web.canGoForward)
                TextField("Search, e.g. \(tabName) coloring page", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit { web.open(query) }
                Toggle(isOn: $web.picking) { Text("Tap a picture").font(.system(size: 16, weight: .semibold)) }
                    .toggleStyle(.button)
                    .tint(Theme.pink)
                if web.isPictureOrPDF {
                    Button("Add this page") { web.downloadCurrent() }.buttonStyle(.borderedProminent).tint(Theme.pink)
                }
                if added > 0 { Text("Added \(added)").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink) }
            }
            .padding(10)
            .background(Theme.cream)
            if web.loading { ProgressView().frame(maxWidth: .infinity) }
            FinderWebView(web: web)
        }
        .onAppear {
            web.onData = { data in added += 1; onAdd(data) }
            if query.isEmpty { query = "\(tabName) coloring page"; web.open(query) }
        }
    }
}

final class FinderWeb: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    let view: WKWebView
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var loading = false
    @Published var isPictureOrPDF = false
    @Published var picking = false { didSet { setPicking() } }
    var onData: (Data) -> Void = { _ in }

    private static let script = """
    (function() {
      function big(img) {
        var best = img.currentSrc || img.src, bestW = img.naturalWidth || 0;
        if (img.srcset) img.srcset.split(',').forEach(function(s) {
          var p = s.trim().split(/\\s+/), w = parseInt(p[1]) || 0;
          if (w > bestW) { bestW = w; best = p[0]; }
        });
        return best;
      }
      document.addEventListener('click', function(e) {
        if (!window.__glimmiePick) return;
        var el = e.target, img = el.closest ? el.closest('img') : null;
        if (!img && el.querySelector) img = el.querySelector('img');
        var a = el.closest ? el.closest('a') : null;
        var href = a && a.href && /\\.(png|jpe?g|gif|webp|pdf)(\\?|$)/i.test(a.href) ? a.href : null;
        if (!img && !href) return;
        e.preventDefault(); e.stopPropagation();
        window.webkit.messageHandlers.pick.postMessage({ src: img ? big(img) : null, href: href, page: location.href });
      }, true);
    })();
    """

    override init() {
        let config = WKWebViewConfiguration()
        let ctl = WKUserContentController()
        ctl.addUserScript(WKUserScript(source: Self.script, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        config.userContentController = ctl
        view = WKWebView(frame: .zero, configuration: config)
        super.init()
        ctl.add(WeakHandler(self), name: "pick")
        view.navigationDelegate = self
        view.allowsBackForwardNavigationGestures = true
    }

    func open(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var url: URL?
        if t.contains("."), !t.contains(" ") {
            url = URL(string: t.hasPrefix("http") ? t : "https://" + t)
        }
        if url == nil {
            var c = URLComponents(string: "https://www.google.com/search")!
            c.queryItems = [URLQueryItem(name: "q", value: t)]
            url = c.url
        }
        if let url { view.load(URLRequest(url: url)) }
    }

    private func setPicking() {
        view.evaluateJavaScript("window.__glimmiePick = \(picking ? "true" : "false");", completionHandler: nil)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        let page = (body["page"] as? String).flatMap(URL.init(string:))
        // Prefer the linked file (usually the full-size printable), then the picture itself.
        let candidates = [body["href"] as? String, body["src"] as? String].compactMap { $0 }
        fetch(candidates, referer: page)
    }

    func downloadCurrent() {
        guard let url = view.url else { return }
        fetch([url.absoluteString], referer: nil)
    }

    private func fetch(_ candidates: [String], referer: URL?) {
        guard let first = candidates.first else { return }
        let rest = Array(candidates.dropFirst())
        if first.hasPrefix("data:"), let comma = first.firstIndex(of: ",") {
            let payload = String(first[first.index(after: comma)...])
            if first[..<comma].contains("base64"), let data = Data(base64Encoded: payload) { deliver(data) } else { fetch(rest, referer: referer) }
            return
        }
        guard let url = URL(string: first) else { fetch(rest, referer: referer); return }
        var req = URLRequest(url: url)
        if let referer { req.setValue(referer.absoluteString, forHTTPHeaderField: "Referer") }
        req.setValue("Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                if let data, !ColoringConvert.images(from: data).isEmpty { self?.deliver(data) } else { self?.fetch(rest, referer: referer) }
            }
        }.resume()
    }

    private func deliver(_ data: Data) {
        Sound.shared.play(.ding, volume: 0.5)
        onData(data)
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame {
            let mime = navigationResponse.response.mimeType ?? ""
            isPictureOrPDF = mime.hasPrefix("image/") || mime == "application/pdf"
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { update(loading: true) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { update(loading: false); setPicking() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { update(loading: false) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { update(loading: false) }

    private func update(loading: Bool) {
        self.loading = loading
        canGoBack = view.canGoBack
        canGoForward = view.canGoForward
    }
}

/// WKUserContentController keeps its handlers alive; this keeps it from keeping FinderWeb alive.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}

private struct FinderWebView: UIViewRepresentable {
    let web: FinderWeb
    func makeUIView(context: Context) -> WKWebView { web.view }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
