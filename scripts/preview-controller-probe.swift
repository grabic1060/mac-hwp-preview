import AppKit
import WebKit

final class MouseSink: NSResponder {
    var clicks = 0
    override func mouseDown(with event: NSEvent) { clicks += 1 }
    override func mouseUp(with event: NSEvent) { clicks += 1 }
}

@main
struct ControllerProbe {
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let controller = PreviewController()
        let root = controller.view
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:800,height:900),styleMask:[.titled,.resizable],backing:.buffered,defer:false)
        window.contentViewController = controller
        window.orderBack(nil)
        let sink = MouseSink()
        let next = controller.nextResponder
        controller.nextResponder = sink
        for count in [1, 2] {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = NSEvent.mouseEvent(with:type, location:.zero, modifierFlags:[], timestamp:0,
                    windowNumber:window.windowNumber, context:nil, eventNumber:0, clickCount:count, pressure:0)!
                if type == .leftMouseDown { root.mouseDown(with:event) }
                else { root.mouseUp(with:event) }
            }
        }
        controller.nextResponder = next
        guard sink.clicks == 0 else { fputs("FAIL: preview clicks forwarded to host responder\n",stderr); exit(1) }
        var done = false, error: Error?
        controller.preparePreviewOfFile(at:URL(fileURLWithPath:CommandLine.arguments[1])) { error = $0; done = true }
        guard controller.view === root else { fputs("FAIL: hosted root view replaced during prepare\n",stderr); exit(1) }
        // Quick Look can hide/reparent the view before preparation completes.
        controller.viewDidDisappear()
        controller.viewWillAppear(); controller.viewDidAppear()
        let deadline = Date().addingTimeInterval(35)
        while !done && Date() < deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.02)) }
        guard done, error == nil else { fputs("FAIL: render cancelled or failed across visibility transition\n",stderr); exit(1) }
        guard let web = root.subviews.first as? WKWebView else { exit(1) }
        window.setContentSize(NSSize(width:620,height:760)); root.layoutSubtreeIfNeeded()
        guard abs(web.frame.width-root.bounds.width)<1, abs(web.frame.height-root.bounds.height)<1 else { exit(1) }
        controller.viewDidDisappear(); controller.viewWillAppear(); controller.viewDidAppear()
        var checked = false, pages = 0
        web.evaluateJavaScript("document.querySelectorAll('.page').length") { value,_ in pages = value as? Int ?? 0; checked = true }
        while !checked && Date() < deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.02)) }
        guard pages > 1, controller.view === root else { exit(1) }
        print("PASS: clicks contained, stable hosted root, visibility transitions, resize, retained multipage content")
        window.orderOut(nil)
    }
}
