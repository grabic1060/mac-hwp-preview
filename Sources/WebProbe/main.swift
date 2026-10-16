import Foundation
import AppKit
import WebKit
import HWPPreviewCore
let args = CommandLine.arguments
if args.count != 4 { fputs("Usage: web-probe ASSETS INPUT OUTPUT.png\n", stderr); exit(2) }
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let renderer = WebRenderer(assets: URL(fileURLWithPath: args[1]))
let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 800,height: 1100),styleMask: .borderless,backing: .buffered,defer: false)
window.contentView = renderer.webView
window.orderBack(nil)
var done = false
var success = false
let start = Date()
renderer.render(URL(fileURLWithPath: args[2])) { result in
    switch result {
    case .success(var info):
        info["seconds"] = Date().timeIntervalSince(start)
        print(String(data: try! JSONSerialization.data(withJSONObject: info,options: .sortedKeys),encoding: .utf8)!)
        renderer.webView.takeSnapshot(with: nil) { image,error in
            defer { done = true }
            guard let image, let tiff = image.tiffRepresentation,let bitmap = NSBitmapImageRep(data:tiff),let data = bitmap.representation(using:.png,properties:[:]) else { return }
            do { try data.write(to: URL(fileURLWithPath:args[3])); success = true } catch { fputs("snapshot write failed\n",stderr) }
        }
    case .failure(let error): fputs("\(error.localizedDescription)\n",stderr); done = true
    }
}
let deadline = Date().addingTimeInterval(40)
while !done && Date() < deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.05)) }
renderer.dispose()
exit(success ? 0 : 1)
