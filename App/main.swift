import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 290),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "HWP Preview — 개발 미리보기"
        let text = NSTextField(wrappingLabelWithString: "HWP · HWPX Quick Look\n\nFinder에서 문서를 선택하고 스페이스바를 눌러 주세요.\n시스템 설정의 확장 프로그램에서 Quick Look 확장을 활성화해야 할 수 있습니다.\n\n이 빌드는 실험 버전입니다. 페이지·표·이미지를 렌더링하지만 원본 충실도와 전체 문서군 검증은 진행 중입니다.\n\n문서는 로컬에서 처리하며 외부로 전송하지 않습니다.")
        text.frame = NSRect(x: 28, y: 28, width: 504, height: 230)
        text.font = .systemFont(ofSize: 15)
        window.contentView?.addSubview(text)
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
