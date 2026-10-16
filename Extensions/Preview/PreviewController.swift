import AppKit
import QuickLookUI
import os

@objc(PreviewController)
final class PreviewController: NSViewController, QLPreviewingController {
    private var renderer: WebRenderer?
    override func loadView() { view = NSView(frame: NSRect(x:0,y:0,width:800,height:900)) }
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        renderer?.dispose()
        guard let assets = Bundle(for: Self.self).resourceURL?.appendingPathComponent("Web") else {
            handler(PreviewFailure.engineMissing); return
        }
        let renderer = WebRenderer(assets: assets)
        self.renderer = renderer
        view = renderer.webView
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
    override func viewDidDisappear() { super.viewDidDisappear(); renderer?.dispose(); renderer = nil }
    deinit { renderer?.dispose() }
}
