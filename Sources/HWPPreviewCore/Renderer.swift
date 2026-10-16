import Foundation
import PDFKit
import AppKit
import Darwin
import os

public enum PreviewFailure: Error, LocalizedError, Equatable {
    case unsupported, invalid, oversized, cancelled, timeout, engineMissing, engineFailed, invalidPDF
    public var errorDescription: String? {
        switch self {
        case .unsupported: return "HWP 5.x 또는 HWPX 파일을 선택해 주세요."
        case .invalid: return "문서가 손상되었거나 읽을 수 없는 형식입니다."
        case .oversized: return "미리보기 처리 한도를 초과한 문서입니다."
        case .cancelled: return "미리보기가 취소되었습니다."
        case .timeout: return "문서를 처리하는 데 시간이 너무 오래 걸립니다."
        case .engineMissing: return "문서 렌더링 엔진이 설치되지 않았습니다."
        case .engineFailed: return "문서를 렌더링할 수 없습니다. 보호 문서이거나 지원하지 않는 요소가 있을 수 있습니다."
        case .invalidPDF: return "올바른 페이지 결과를 생성하지 못했습니다."
        }
    }
}

public final class Cancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    public init() {}
    public func cancel() { lock.lock(); value = true; lock.unlock() }
    public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

public struct RenderLimits {
    public var inputBytes: Int = 50 * 1024 * 1024
    public var outputBytes: Int = 100 * 1024 * 1024
    public var seconds: TimeInterval = 20
    public var pages: Int = 500
    public init() {}
}

public struct RenderResult {
    public let pdf: Data
    public let pageCount: Int
    public let elapsed: TimeInterval
    // Always disclose unverified fidelity; successful conversion is not an oracle.
    public let notice = "실험적 미리보기 · 글꼴과 배치가 원본과 다를 수 있습니다"
}

public final class Renderer {
    public let executable: URL
    public let limits: RenderLimits
    public init(executable: URL, limits: RenderLimits = RenderLimits()) {
        self.executable = executable; self.limits = limits
    }
    public static func validate(_ url: URL, maximumBytes: Int) throws {
        guard ["hwp", "hwpx"].contains(url.pathExtension.lowercased()) else { throw PreviewFailure.unsupported }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw PreviewFailure.invalid }
        guard let size = values.fileSize, size > 8 else { throw PreviewFailure.invalid }
        guard size <= maximumBytes else { throw PreviewFailure.oversized }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let magic = try handle.read(upToCount: 8) ?? Data()
        let cfb = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
        if url.pathExtension.lowercased() == "hwp" {
            guard magic == cfb else { throw PreviewFailure.invalid }
        } else {
            guard magic.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]) else { throw PreviewFailure.invalid }
        }
    }

    /// Read once with a hard byte cap, then validate the bytes actually passed to the engine.
    public static func snapshot(_ url: URL, maximumBytes: Int) throws -> Data {
        try validate(url, maximumBytes: maximumBytes)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw PreviewFailure.oversized }
        guard data.count > 8 else { throw PreviewFailure.invalid }
        let signature: [UInt8] = url.pathExtension.lowercased() == "hwp"
            ? [0xD0,0xCF,0x11,0xE0,0xA1,0xB1,0x1A,0xE1] : [0x50,0x4B,0x03,0x04]
        guard data.starts(with: signature) else { throw PreviewFailure.invalid }
        return data
    }

    public func render(_ source: URL, cancellation: Cancellation = Cancellation()) throws -> RenderResult {
        if cancellation.isCancelled { throw PreviewFailure.cancelled }
        try Self.validate(source, maximumBytes: limits.inputBytes)
        guard FileManager.default.fileExists(atPath: executable.path) else { throw PreviewFailure.engineMissing }
        let logger = Logger(subsystem: "org.hwp-preview", category: "renderer")
        logger.notice("phase=validated")
        let started = Date()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("hwp-preview-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        // Snapshot prevents a renamed/replaced original from changing during rendering.
        let input = directory.appendingPathComponent("input." + source.pathExtension.lowercased())
        logger.notice("phase=snapshot")
        try FileManager.default.copyItem(at: source, to: input)
        try Self.validate(input, maximumBytes: limits.inputBytes)
        let output = directory.appendingPathComponent("preview.pdf")
        let task = Process()
        task.executableURL = executable
        task.arguments = ["export-pdf", input.path, "-o", output.path, "--json"]
        task.currentDirectoryURL = directory
        task.standardInput = FileHandle.nullDevice
        // Do not put document text, titles or paths in diagnostic logs.
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        logger.notice("phase=launch")
        try task.run()
        while task.isRunning {
            let size = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let failure: PreviewFailure? = cancellation.isCancelled ? .cancelled :
                (Date().timeIntervalSince(started) > limits.seconds ? .timeout :
                 (size > limits.outputBytes ? .oversized : nil))
            if let failure {
                task.terminate()
                let until = Date().addingTimeInterval(0.25)
                while task.isRunning && Date() < until { Thread.sleep(forTimeInterval: 0.01) }
                if task.isRunning { kill(task.processIdentifier, SIGKILL) }
                task.waitUntilExit()
                throw failure
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        task.waitUntilExit()
        if cancellation.isCancelled { throw PreviewFailure.cancelled }
        logger.notice("phase=exit status=\(task.terminationStatus)")
        guard task.terminationReason == .exit && task.terminationStatus == 0 else { throw PreviewFailure.engineFailed }
        logger.notice("phase=readPDF")
        let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= limits.outputBytes else { throw PreviewFailure.oversized }
        let data = try Data(contentsOf: output)
        guard let document = PDFDocument(data: data), document.pageCount > 0 else { throw PreviewFailure.invalidPDF }
        guard document.pageCount <= limits.pages else { throw PreviewFailure.oversized }
        return RenderResult(pdf: data, pageCount: document.pageCount, elapsed: Date().timeIntervalSince(started))
    }
}
