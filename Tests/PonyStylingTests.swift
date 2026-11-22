import WebKit
import XCTest
@testable import Glimmie

final class PonyStylingTests: XCTestCase {
    func testOnlyValidLooksAreAccepted() throws {
        var save = PonyStylingSave()
        save.maneColors[1] = "#57b68f"
        save.hoofColors[2] = "#db5793"
        save.hoofGlitter[2] = true
        save.braidStyle = 2
        save.crossed = 3
        save.padMarks = ["♥", "", "✦"]
        func serialize(_ value: PonyStylingSave) throws -> String {
            String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        }
        XCTAssertEqual(PonyStylingSave.received(try serialize(save)), save)
        save.maneColors[1] = "invalid"
        XCTAssertNil(PonyStylingSave.received(try serialize(save)))
        save.maneColors[1] = ""
        save.soles[0].append(0)
        XCTAssertNil(PonyStylingSave.received(try serialize(save)))
        XCTAssertNil(PonyStylingSave.received(String(repeating: " ", count: 4097)))
    }

    @MainActor
    func testBundledStableRestoresAndSavesColorsThroughWebKit() async throws {
        let page = try XCTUnwrap(PonyStylingPage.url)
        var save = PonyStylingSave()
        save.maneColors[1] = "#57b68f"
        let loaded = expectation(description: "Offline stable loaded")
        let painted = expectation(description: "Stable sent updated paint")
        let observer = Observer(loaded: loaded, painted: painted)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.addUserScript(WKUserScript(
            source: PonyStylingPage.initialScript(for: save), injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        config.userContentController.add(observer, name: "unicornStable")
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 812, height: 375), configuration: config)
        view.navigationDelegate = observer
        defer { config.userContentController.removeScriptMessageHandler(forName: "unicornStable") }
        view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        await fulfillment(of: [loaded], timeout: 18)
        let color = try await view.evaluateJavaScript("""
            document.querySelector('button[aria-label="Color Middle mane"]').style.getPropertyValue('--mark-color')
            """) as? String
        XCTAssertEqual(color, "#57b68f")
        _ = try await view.evaluateJavaScript("""
            document.querySelector('button[aria-label="Color Mane ends"]').click()
            """)
        await fulfillment(of: [painted], timeout: 6)
        XCTAssertEqual(observer.save?.maneColors, ["#db5793", "#57b68f", "", ""])
    }

    private final class Observer: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let loaded: XCTestExpectation
        let painted: XCTestExpectation
        private(set) var save: PonyStylingSave?

        init(loaded: XCTestExpectation, painted: XCTestExpectation) {
            self.loaded = loaded
            self.painted = painted
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded.fulfill() }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let event = message.body as? [String: String], event["kind"] == "save",
                  let value = event["value"], let save = PonyStylingSave.received(value), self.save == nil else { return }
            self.save = save
            painted.fulfill()
        }
    }
}
