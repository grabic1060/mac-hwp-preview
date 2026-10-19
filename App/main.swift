import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private let updates = UpdateController()
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 424),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "HWP Preview — 개발 미리보기"
        let text = NSTextField(wrappingLabelWithString: "HWP · HWPX Quick Look\n\nFinder에서 문서를 선택하고 스페이스바를 눌러 주세요.\n아래 버튼으로 시스템 설정을 열고 Quick Look 항목에서 HWP Preview 확장을 켜 주세요.\n\n이 빌드는 실험 버전입니다. 페이지·표·이미지를 렌더링하지만 원본 충실도와 전체 문서군 검증은 진행 중입니다.\n\n문서는 로컬에서 처리하며 외부로 전송하지 않습니다.")
        text.frame = NSRect(x: 28, y: 126, width: 544, height: 270)
        text.font = .systemFont(ofSize: 15)
        window.contentView?.addSubview(text)
        let button = NSButton(title: "Quick Look 확장 설정 열기", target: self, action: #selector(openExtensionSettings))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 28, y: 48, width: 250, height: 32)
        window.contentView?.addSubview(button)
        let path = NSTextField(wrappingLabelWithString: settingsPath)
        path.font = .systemFont(ofSize: 12)
        path.textColor = .secondaryLabelColor
        path.frame = NSRect(x: 28, y: 12, width: 544, height: 32)
        window.contentView?.addSubview(path)
        let updateButton = NSButton(title: "업데이트 확인…", target: nil, action: nil)
        updateButton.bezelStyle = .rounded
        updateButton.frame = NSRect(x: 300, y: 48, width: 220, height: 32)
        window.contentView?.addSubview(updateButton)
        updates.start(button: updateButton)
        let updateStatus = NSTextField(wrappingLabelWithString: updates.status)
        updateStatus.font = .systemFont(ofSize: 12)
        updateStatus.textColor = .secondaryLabelColor
        updateStatus.frame = NSRect(x: 28, y: 86, width: 544, height: 32)
        window.contentView?.addSubview(updateStatus)
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private var settingsPath: String {
        if #available(macOS 15, *) {
            return "시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → Quick Look"
        }
        return "시스템 설정 → 개인정보 보호 및 보안 → 확장 프로그램 → Quick Look"
    }
    @objc private func openExtensionSettings() {
        // These System Settings routes are best-effort; keep the manual path visible.
        let route: String
        if #available(macOS 15, *) {
            route = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        } else {
            route = "x-apple.systempreferences:com.apple.ExtensionsPreferences"
        }
        if NSWorkspace.shared.open(URL(string: route)!) { return }
        if NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!) { return }
        let alert = NSAlert()
        alert.messageText = "시스템 설정을 열지 못했습니다"
        alert.informativeText = "Apple 메뉴에서 시스템 설정을 연 뒤 다음 경로로 이동해 주세요.\n\n" + settingsPath
        alert.beginSheetModal(for: window)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
