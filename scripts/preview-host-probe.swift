import AppKit
import QuickLookUI
// This exercises system extension dispatch. Completion must be confirmed in the extension log.
guard CommandLine.arguments.count == 2 else { exit(2) }
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let window = NSWindow(contentRect: NSRect(x:0,y:0,width:800,height:1000), styleMask:[.titled], backing:.buffered, defer:false)
let preview = QLPreviewView(frame:window.contentView!.bounds, style:.normal)!
window.contentView = preview
preview.previewItem = NSURL(fileURLWithPath:CommandLine.arguments[1])
window.orderBack(nil)
RunLoop.current.run(until:Date().addingTimeInterval(15))
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
print("observedUntil=\(formatter.string(from:Date()))")
preview.close()
window.orderOut(nil)
print("Preview host closed; check org.hwp-preview/preview logs for render completion.")
