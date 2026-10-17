import AppKit
import QuickLookUI
import os

@objc(PreviewController)
final class PreviewController: NSViewController, QLPreviewingController {
    private var renderer: WebRenderer?
    override func loadView() {
        view = NSView(frame: NSRect(x:0,y:0,width:800,height:900))
        preferredContentSize = NSSize(width:800,height:900)
    }
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        _ = view // Quick Look retains this root for the lifetime of its remote view.
        renderer?.dispose()
        renderer?.webView.removeFromSuperview()
        guard let assets = Bundle(for: Self.self).resourceURL?.appendingPathComponent("Web") else {
            handler(PreviewFailure.engineMissing); return
        }
        let renderer = WebRenderer(assets: assets)
        self.renderer = renderer
        let webView = renderer.webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            webView.topAnchor.constraint(equalTo:view.topAnchor),
            webView.bottomAnchor.constraint(equalTo:view.bottomAnchor)
        ])
        renderer.render(url) { result in
            switch result {
            case .success:
                Logger(subsystem: "org.hwp-preview", category: "preview").notice("WASM preview complete")
                handler(nil)
            case .failure(let error):
                Logger(subsystem: "org.hwp-preview", category: "preview").error("WASM preview failed")
                handler(error)
            }
        }
    }
    // Visibility changes are not request cancellation: Quick Look reparents/hides
    // remote views while preparing, resizing and switching presentation modes.
    // Release on the next request or controller destruction instead.
    deinit { renderer?.dispose() }
}
