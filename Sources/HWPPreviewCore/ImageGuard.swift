import Foundation
import ImageIO
import WebKit

public enum ImageBudget {
    public static func pixels(_ data: Data) -> Int? {
        guard data.count <= 20 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
              CGImageSourceGetCount(source) > 0, CGImageSourceGetCount(source) <= 100 else { return nil }
        var pixels = 0
        for index in 0..<CGImageSourceGetCount(source) {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source,index,nil) as? [CFString:Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 20000, height <= 20000 else { return nil }
            pixels += width * height
            guard pixels <= 40_000_000 else { return nil }
        }
        return pixels
    }
}

final class ImageGuard: NSObject, WKScriptMessageHandlerWithReply {
    var total = 0
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.isMainFrame, let source = message.body as? String,
              source.utf8.count <= 28 * 1024 * 1024, let comma = source.firstIndex(of:","),
              let data = Data(base64Encoded:String(source[source.index(after:comma)...]),options:.ignoreUnknownCharacters),
              let pixels = ImageBudget.pixels(data), total + pixels <= 80_000_000 else { replyHandler(false,nil); return }
        total += pixels; replyHandler(true,nil)
    }
}
