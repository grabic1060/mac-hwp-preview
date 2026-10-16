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
        let names = ["index.html":"text/html", "viewer.js":"text/javascript", "svg.js":"text/javascript", "engine-worker.js":"text/javascript", "rhwp.js":"text/javascript", "rhwp_bg.wasm":"application/wasm"]
        guard let url = urlSchemeTask.request.url, url.host == "assets",
              let mime = names[String(url.path.dropFirst())] else {
            urlSchemeTask.didFailWithError(PreviewFailure.invalid); return
        }
        do {
            let data = try Data(contentsOf: directory.appendingPathComponent(String(url.path.dropFirst())))
            let policy = "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'unsafe-inline'; img-src data:; connect-src 'self'; font-src data:; worker-src 'self'; base-uri 'none'; form-action 'none'"
            urlSchemeTask.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Content-Length": String(data.count), "Content-Security-Policy":policy])!)
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
    private var cancellation = Cancellation()
    private let timeout: TimeInterval
    private var generation = UUID().uuidString
    public init(assets: URL, timeout: TimeInterval = 30) {
        self.timeout = timeout
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
        cancellation = Cancellation()
        let token = cancellation, request = generation
        timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.cancellation.cancel(); self?.stopEngine(); self?.finish(.failure(PreviewFailure.timeout))
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { () -> Data in
                let data = try Renderer.snapshot(url, maximumBytes: 50 * 1024 * 1024)
                try Preflight.check(data, extension: url.pathExtension, cancellation: token)
                return data
            }
            DispatchQueue.main.async {
                guard let self, self.generation == request, self.completion != nil else { return }
                switch result {
                case .success(let data):
                    self.input = data
                    self.webView.load(URLRequest(url: URL(string: "hwp-preview://assets/index.html?request=\(request)")!))
                case .failure(let error): self.finish(.failure(error))
                }
            }
        }
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
    private func stopEngine() {
        webView.evaluateJavaScript("window.cancelRendering?.()", completionHandler: nil)
        webView.stopLoading()
    }
    public func cancel() { cancellation.cancel(); generation = UUID().uuidString; stopEngine(); finish(.failure(PreviewFailure.cancelled)) }
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
