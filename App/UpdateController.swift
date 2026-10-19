import AppKit
import Sparkle

final class UpdateController {
    private var controller: SPUStandardUpdaterController?
    private var observation: NSKeyValueObservation?
    private(set) var status = "업데이트 배포 주소가 아직 설정되지 않았습니다."

    func start(button: NSButton) {
        button.isEnabled = false
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https", url.host != nil,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        do {
            try controller.updater.start()
            button.target = controller
            button.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
            observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { updater, _ in
                button.isEnabled = updater.canCheckForUpdates
            }
            status = "앱 실행 중에만 업데이트를 확인합니다."
            // Respect Sparkle's persisted user preference; no launch agent or login item.
            if controller.updater.automaticallyChecksForUpdates {
                controller.updater.checkForUpdatesInBackground()
            }
        } catch {
            status = "업데이트 확인을 시작하지 못했습니다. 앱을 다시 실행해 주세요."
        }
    }
}
