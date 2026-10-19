import AppKit
import Sparkle
final class Probe: NSObject, SPUUpdaterDelegate {
    var outcome: String?
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) { outcome = "found:" + item.versionString }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) { outcome = "current" }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) { if outcome == nil { outcome = "error" } }
}
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let probe = Probe()
let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: probe, userDriverDelegate: nil)
do { try controller.updater.start() } catch { fatalError("Sparkle initialization failed: \(error)") }
controller.updater.checkForUpdateInformation()
let end = Date().addingTimeInterval(15)
while probe.outcome == nil && Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
guard let outcome = probe.outcome else { fatalError("Update check timed out") }
print(outcome)
exit(outcome == CommandLine.arguments[1] ? 0 : 1)
