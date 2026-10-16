import Foundation
import AppKit
import QuickLookThumbnailing
let args = CommandLine.arguments
if args.count != 3 { exit(2) }
let request = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: args[1]),
    size: NSSize(width: 800, height: 1100), scale: 1, representationTypes: .thumbnail)
var done = false
var succeeded = false
QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
    defer { done = true }
    if let error { fputs("\(error)\n", stderr); return }
    guard let representation else { return }
    let bitmap = NSBitmapImageRep(cgImage: representation.cgImage)
    do {
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
        print("representationType=\(representation.type.rawValue)")
        succeeded = representation.type == .thumbnail
    } catch { fputs("\(error)\n", stderr) }
}
let deadline = Date().addingTimeInterval(40)
while !done && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
if !done { QLThumbnailGenerator.shared.cancel(request); fputs("thumbnail timeout\n", stderr) }
exit(succeeded ? 0 : 1)
