import XCTest
@testable import HWPPreviewCore

final class RendererTests: XCTestCase {
    func temporary(_ suffix: String, _ data: Data) throws -> URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + suffix)
        try data.write(to: path)
        addTeardownBlock { try? FileManager.default.removeItem(at: path) }
        return path
    }
    func testRejectsRenamedText() throws {
        let file = try temporary(".hwp", Data("not an hwp document".utf8))
        XCTAssertThrowsError(try Renderer.validate(file, maximumBytes: 100)) { XCTAssertEqual($0 as? PreviewFailure, .invalid) }
    }
    func testRejectsOversizedBeforeParsing() throws {
        let file = try temporary(".hwpx", Data(repeating: 0, count: 100))
        XCTAssertThrowsError(try Renderer.validate(file, maximumBytes: 50)) { XCTAssertEqual($0 as? PreviewFailure, .oversized) }
    }
    func testRejectsWrongContainerForExtension() throws {
        let file = try temporary(".hwpx", Data([0xD0,0xCF,0x11,0xE0,0xA1,0xB1,0x1A,0xE1,0]))
        XCTAssertThrowsError(try Renderer.validate(file, maximumBytes: 100))
    }
    func testCancelledRequestDoesNotOpenFile() {
        let token = Cancellation(); token.cancel()
        XCTAssertThrowsError(try Renderer(executable: URL(fileURLWithPath: "/missing")).render(URL(fileURLWithPath: "/missing.hwp"), cancellation: token)) {
            XCTAssertEqual($0 as? PreviewFailure, .cancelled)
        }
    }
}
