import AppKit
import WebKit

private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

public final class AssetHandler: NSObject, WKURLSchemeHandler {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let names = ["index.html":"text/html", "viewer.js":"text/javascript", "rhwp.js":"text/javascript", "rhwp_bg.wasm":"application/wasm"]
        guard let url = urlSchemeTask.request.url, url.host == "assets",
              let mime = names[String(url.path.dropFirst())] else {
            urlSchemeTask.didFailWithError(PreviewFailure.invalid); return
        }
        do {
            let data = try Data(contentsOf: directory.appendingPathComponent(String(url.path.dropFirst())))
            urlSchemeTask.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Content-Length": String(data.count)])!)
            urlSchemeTask.didReceive(data); urlSchemeTask.didFinish()
        } catch { urlSchemeTask.didFailWithError(error) }
    }
    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

public final class WebRenderer: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    public let webView: WKWebView
    private var completion: ((Result<[String: Any], Error>) -> Void)?
    private var input: Data?
    private var thumbnail = false
    private var timer: Timer?
    private var generation = UUID().uuidString
    public init(assets: URL) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(AssetHandler(directory: assets), forURLScheme: "hwp-preview")
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1100), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        let handler = WeakMessageHandler(); handler.target = self
        configuration.userContentController.add(handler, name: "ready")
    }
    public func render(_ url: URL, thumbnail: Bool = false, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        cancel()
        generation = UUID().uuidString
        self.completion = completion
        self.thumbnail = thumbnail
        do {
            input = try Renderer.snapshot(url, maximumBytes: 50 * 1024 * 1024)
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
                self?.finish(.failure(PreviewFailure.timeout)); self?.webView.stopLoading()
            }
            webView.load(URLRequest(url: URL(string: "hwp-preview://assets/index.html?request=\(generation)")!))
        } catch { finish(.failure(error)) }
    }
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard completion != nil, let input else { return }
        guard message.frameInfo.isMainFrame,
              let body = message.body as? [String: Any], body["request"] as? String == generation else { return }
        guard body["ready"] as? Bool == true else { finish(.failure(PreviewFailure.engineFailed)); return }
        self.input = nil
        let request = generation
        webView.callAsyncJavaScript("return await window.renderDocument(data, thumbnail)", arguments: ["data":input.base64EncodedString(), "thumbnail":thumbnail], in: nil, in: .page, completionHandler: { [weak self] result in
            guard let self, self.generation == request else { return }
            switch result {
            case .success(let value):
                guard let value = value as? [String:Any] else { self.finish(.failure(PreviewFailure.engineFailed)); return }
                self.finish(.success(value))
            case .failure: self.finish(.failure(PreviewFailure.engineFailed))
            }
        })
    }
    private func finish(_ result: Result<[String:Any], Error>) {
        timer?.invalidate(); timer = nil; input = nil
        let callback = completion; completion = nil; callback?(result)
    }
    public func cancel() { generation = UUID().uuidString; finish(.failure(PreviewFailure.cancelled)); webView.stopLoading() }
    public func dispose() { cancel(); webView.configuration.userContentController.removeScriptMessageHandler(forName: "ready") }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(.failure(PreviewFailure.engineFailed)) }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(PreviewFailure.engineFailed)) }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(PreviewFailure.engineFailed)) }
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        decisionHandler(url?.scheme == "hwp-preview" && url?.host == "assets" && url?.path == "/index.html" ? .allow : .cancel)
    }
    deinit { timer?.invalidate() }
}
