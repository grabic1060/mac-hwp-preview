import XCTest
@testable import HWPPreviewCore

final class PreflightTests: XCTestCase {
    func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Fixtures/" + name))
    }
    func check(_ name: String) throws { try Preflight.check(fixture(name), extension: (name as NSString).pathExtension) }
    func testPlainContainersPass() throws {
        for name in ["stored.hwpx","deflate.hwpx","header.hwp","compressed-raw.hwp","compressed-trailer.hwp"] { XCTAssertNoThrow(try check(name),name) }
    }
    func testProtectedDocumentsRejectedBeforeEngine() throws {
        for name in ["protected.hwpx","encrypted.hwpx","password.hwp","distribution.hwp","drm.hwp","certificate.hwp","certificate-drm.hwp","privacy.hwp"] {
            XCTAssertThrowsError(try check(name),name) { XCTAssertEqual($0 as? PreviewFailure,.protectedDocument,name) }
        }
    }
    func testMalformedContainersRejected() throws {
        for name in ["doctype.hwpx","traversal.hwpx","crc.hwpx","truncated.hwpx","cycle.hwp","mini-cycle.hwp","compressed-bad-trailer.hwp"] {
            XCTAssertThrowsError(try check(name),name) { XCTAssertEqual($0 as? PreviewFailure,.invalid,name) }
        }
    }
    func testExpansionAndDepthLimits() throws {
        for name in ["bomb.hwpx","deep.hwpx","expansion.hwp"] {
            XCTAssertThrowsError(try check(name),name) { XCTAssertEqual($0 as? PreviewFailure,.oversized,name) }
        }
    }
    func testTruncationAtEveryCFBBoundaryDoesNotCrash() throws {
        let data = try fixture("header.hwp")
        for end in stride(from:0,to:data.count,by:127) {
            XCTAssertThrowsError(try Preflight.check(Data(data.prefix(end)),extension:"hwp"))
        }
    }
    func testTruncationAtEveryZIPBoundaryDoesNotCrash() throws {
        let data = try fixture("deflate.hwpx")
        for end in stride(from:0,to:data.count,by:13) {
            XCTAssertThrowsError(try Preflight.check(Data(data.prefix(end)),extension:"hwpx"))
        }
    }
    func testCancellationBeforeContainerRead() throws {
        let token = Cancellation(); token.cancel()
        XCTAssertThrowsError(try Preflight.check(Data(),extension:"hwp",cancellation:token)) {
            XCTAssertEqual($0 as? PreviewFailure,.cancelled)
        }
    }
}
