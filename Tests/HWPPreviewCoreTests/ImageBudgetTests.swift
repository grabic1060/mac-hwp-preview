import XCTest
@testable import HWPPreviewCore

final class ImageBudgetTests: XCTestCase {
    func testTinyPNGMetadataAccepted() {
        let png = Data(base64Encoded:"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=")!
        XCTAssertEqual(ImageBudget.pixels(png),1)
    }
    func testInvalidImageRejected() { XCTAssertNil(ImageBudget.pixels(Data("invalid".utf8))) }
    func testCompressedImageByteLimit() { XCTAssertNil(ImageBudget.pixels(Data(count:20 * 1024 * 1024 + 1))) }
    func testHugeGIFDimensionsRejectedBeforeDecode() {
        var gif = Data("GIF89a".utf8)
        gif.append(contentsOf:[255,255,255,255,0,0,0,0x3b])
        XCTAssertNil(ImageBudget.pixels(gif))
    }
}
