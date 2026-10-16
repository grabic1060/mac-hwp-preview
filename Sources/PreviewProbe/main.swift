import Foundation
import PDFKit
import AppKit
import HWPPreviewCore

let args = CommandLine.arguments
if args.count != 4 {
    fputs("Usage: preview-probe ENGINE INPUT OUTPUT.pdf\n", stderr)
    exit(2)
}
do {
    let result = try Renderer(executable: URL(fileURLWithPath: args[1])).render(URL(fileURLWithPath: args[2]))
    let out = URL(fileURLWithPath: args[3])
    try result.pdf.write(to: out, options: .atomic)
    let document = PDFDocument(data: result.pdf)!
    let page = document.page(at: 0)!
    let image = page.thumbnail(of: NSSize(width: 800, height: 1100), for: .mediaBox)
    if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        try png.write(to: out.deletingPathExtension().appendingPathExtension("png"))
    }
    let json: [String: Any] = ["pages": result.pageCount, "seconds": result.elapsed,
                              "textCharacters": document.string?.count ?? 0, "fidelityVerified": false]
    print(String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8)!)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
