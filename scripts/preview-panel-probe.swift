import AppKit
import QuickLookUI

final class PreviewHost: NSWindow, QLPreviewPanelDataSource {
    var item: NSURL!
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) { panel.dataSource = self }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) { panel.dataSource = nil }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { item }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let host = PreviewHost(contentRect:NSRect(x:0,y:0,width:400,height:200),styleMask:[.titled],backing:.buffered,defer:false)
host.item = NSURL(fileURLWithPath:CommandLine.arguments[1])
host.makeKeyAndOrderFront(nil)
let panel = QLPreviewPanel.shared()!
panel.updateController()
panel.dataSource = host
panel.makeKeyAndOrderFront(nil)
panel.reloadData()
RunLoop.current.run(until:Date().addingTimeInterval(12))
panel.setContentSize(NSSize(width:650,height:850))
RunLoop.current.run(until:Date().addingTimeInterval(3))
let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
print("observedUntil=\(formatter.string(from:Date()))")
panel.orderOut(nil);host.orderOut(nil)
