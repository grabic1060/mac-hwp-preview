// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "HWPPreview", platforms: [.macOS(.v14)], products: [
    .library(name: "HWPPreviewCore", targets: ["HWPPreviewCore"]),
    .executable(name: "preview-probe", targets: ["PreviewProbe"]),
    .executable(name: "web-probe", targets: ["WebProbe"]),
    .executable(name: "lifecycle-probe", targets: ["LifecycleProbe"])
], targets: [
    .systemLibrary(name: "CZlib"),
    .target(name: "HWPPreviewCore", dependencies: ["CZlib"]),
    .executableTarget(name: "PreviewProbe", dependencies: ["HWPPreviewCore"]),
    .executableTarget(name: "WebProbe", dependencies: ["HWPPreviewCore"]),
    .executableTarget(name: "LifecycleProbe", dependencies: ["HWPPreviewCore"]),
    .testTarget(name: "HWPPreviewCoreTests", dependencies: ["HWPPreviewCore"], resources: [.copy("Fixtures")])
])
