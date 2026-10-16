import AppKit
import WebKit

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
    public init(assets: URL) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(AssetHandler(directory: assets), forURLScheme: "hwp-preview")
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1100), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        configuration.userContentController.add(self, name: "ready")
    }
    public func render(_ url: URL, thumbnail: Bool = false, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        cancel()
        self.completion = completion
        self.thumbnail = thumbnail
        do {
            try Renderer.validate(url, maximumBytes: 50 * 1024 * 1024)
            input = try Data(contentsOf: url)
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
                self?.finish(.failure(PreviewFailure.timeout)); self?.webView.stopLoading()
            }
            webView.load(URLRequest(url: URL(string: "hwp-preview://assets/index.html")!))
        } catch { finish(.failure(error)) }
    }
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard completion != nil, let input else { return }
        guard message.body as? String == "ready" else { print("Engine initialization: \(message.body)"); finish(.failure(PreviewFailure.engineFailed)); return }
        self.input = nil
        webView.callAsyncJavaScript("return await window.renderDocument(data, thumbnail)", arguments: ["data":input.base64EncodedString(), "thumbnail":thumbnail], in: nil, in: .page, completionHandler: { [weak self] result in
            switch result {
            case .success(let value):
                guard let value = value as? [String:Any] else { self?.finish(.failure(PreviewFailure.engineFailed)); return }
                self?.finish(.success(value))
            case .failure(let error): print("Web renderer failure domain=\((error as NSError).domain) code=\((error as NSError).code)"); self?.finish(.failure(PreviewFailure.engineFailed))
            }
        })
    }
    private func finish(_ result: Result<[String:Any], Error>) {
        timer?.invalidate(); timer = nil; input = nil
        let callback = completion; completion = nil; callback?(result)
    }
    public func cancel() { finish(.failure(PreviewFailure.cancelled)); webView.stopLoading() }
    public func dispose() { cancel(); webView.configuration.userContentController.removeScriptMessageHandler(forName: "ready") }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(.failure(PreviewFailure.engineFailed)) }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(PreviewFailure.engineFailed)) }
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.absoluteString == "hwp-preview://assets/index.html" ? .allow : .cancel)
    }
}
