import Foundation
import AppKit
import HWPPreviewCore

guard CommandLine.arguments.count == 3 else { exit(2) }
NSApplication.shared.setActivationPolicy(.prohibited)
let assets = URL(fileURLWithPath:CommandLine.arguments[1])
let input = URL(fileURLWithPath:CommandLine.arguments[2])
func wait(_ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(40)
    while !condition() && Date() < deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.01)) }
    return condition()
}
var cancelled = 0, completed = 0, failures = 0
let renderer = WebRenderer(assets:assets)
renderer.render(input) { result in
    if case .failure(let error) = result, error as? PreviewFailure == .cancelled { cancelled += 1 }
    else { failures += 1 }
}
// Replacing an in-flight request must complete the first callback exactly once.
renderer.render(input) { result in
    if case .success = result { completed += 1 } else { failures += 1 }
}
guard wait({ completed + failures > 0 }), cancelled == 1, completed == 1, failures == 0 else { exit(1) }
renderer.dispose()
var timedOut = false
let slow = WebRenderer(assets:assets,timeout:0.001)
slow.render(input) { result in
    if case .failure(let error) = result, error as? PreviewFailure == .timeout { timedOut = true }
}
guard wait({ timedOut }) else { exit(1) }
slow.dispose()
weak var weakRenderer: WebRenderer?
autoreleasepool {
    let temporary = WebRenderer(assets:assets)
    weakRenderer = temporary
    temporary.dispose()
}
guard wait({ weakRenderer == nil }) else { exit(1) }
print("replacement=passed timeout=passed release=passed")
