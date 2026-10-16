import Foundation
import CZlib

private extension Data {
    func integer(_ offset: Int, _ width: Int = 4) throws -> Int {
        guard offset >= 0, width > 0, offset <= count - width else { throw PreviewFailure.invalid }
        return (0..<width).reduce(0) { $0 | (Int(self[offset + $1]) << ($1 * 8)) }
    }
    func bytes(_ offset: Int, _ length: Int) throws -> Data {
        guard offset >= 0, length >= 0, offset <= count - length else { throw PreviewFailure.invalid }
        return subdata(in: offset..<(offset + length))
    }
}

/// Read-only container checks before handing any document to the rendering worker.
public enum Preflight {
    public static func check(_ data: Data, extension ext: String, cancellation: Cancellation = Cancellation()) throws {
        if cancellation.isCancelled { throw PreviewFailure.cancelled }
        if ext.lowercased() == "hwpx" { try zip(data, cancellation) }
        else if ext.lowercased() == "hwp" { try cfb(data, cancellation) }
        else { throw PreviewFailure.unsupported }
    }
    private static func inflateRaw(_ data: Data, expected: Int) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw PreviewFailure.invalid }
        defer { inflateEnd(&stream) }
        var output = Data(count: expected + 1)
        let result = output.withUnsafeMutableBytes { out in
            data.withUnsafeBytes { input in
                stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(data.count)
                stream.next_out = out.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(expected + 1)
                return inflate(&stream, Z_FINISH)
            }
        }
        guard result == Z_STREAM_END, stream.total_out == expected, stream.total_in == data.count else { throw PreviewFailure.invalid }
        output.count = expected
        return output
    }
    private static func inflateBounded(_ data: Data, limit: Int, cancellation: Cancellation) throws -> Data? {
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw PreviewFailure.invalid }
        defer { inflateEnd(&stream) }
        return try data.withUnsafeBytes { input in
            stream.next_in = UnsafeMutablePointer(mutating:input.bindMemory(to:Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)
            var result = Data(), chunk = [UInt8](repeating:0,count:65536)
            while true {
                if cancellation.isCancelled { throw PreviewFailure.cancelled }
                let status = chunk.withUnsafeMutableBufferPointer { buffer in
                    stream.next_out = buffer.baseAddress; stream.avail_out = uInt(buffer.count)
                    return inflate(&stream,Z_NO_FLUSH)
                }
                let produced = chunk.count - Int(stream.avail_out)
                guard result.count + produced <= limit else { throw PreviewFailure.oversized }
                result.append(contentsOf:chunk.prefix(produced))
                if status == Z_STREAM_END {
                    let tail = Int(stream.total_in)
                    if tail == data.count { return result }
                    // Some HWP streams retain a gzip CRC32/ISIZE trailer after raw DEFLATE.
                    if data.count - tail == 8 {
                        let checksum = result.withUnsafeBytes { crc32(0,$0.bindMemory(to:Bytef.self).baseAddress,uInt(result.count)) }
                        if try data.integer(tail) == checksum, try data.integer(tail + 4) == result.count { return result }
                    }
                    return nil
                }
                if status != Z_OK || produced == 0 && stream.avail_in == 0 { return nil }
            }
        }
    }
    private static func records(_ data: Data) throws {
        var offset = 0, count = 0
        while offset < data.count {
            let header = try data.integer(offset); offset += 4; count += 1
            guard count <= 200_000, (header >> 10) & 0x3ff <= 128 else { throw PreviewFailure.oversized }
            var size = header >> 20
            if size == 0xfff { size = try data.integer(offset); offset += 4 }
            guard size <= data.count - offset else { throw PreviewFailure.invalid }
            offset += size
        }
    }
    private static func zip(_ data: Data, _ cancellation: Cancellation) throws {
        guard data.count >= 22 else { throw PreviewFailure.invalid }
        var end: Int?
        for index in stride(from:data.count - 22, through:max(0,data.count - 65557), by:-1) {
            if try data.integer(index) == 0x06054b50, try index + 22 + data.integer(index + 20,2) == data.count { end = index; break }
        }
        guard let end else { throw PreviewFailure.invalid }
        guard try data.integer(end + 4,2) == 0, try data.integer(end + 6,2) == 0 else { throw PreviewFailure.unsupported }
        let count = try data.integer(end + 10,2)
        guard count > 0, count <= 4096 else { throw PreviewFailure.oversized }
        guard try data.integer(end + 8,2) == count else { throw PreviewFailure.invalid }
        let start = try data.integer(end + 16), directorySize = try data.integer(end + 12)
        guard start + directorySize == end else { throw PreviewFailure.invalid }
        var cursor = start, total = 0, names = Set<String>(), ranges = [Range<Int>]()
        for _ in 0..<count {
            if cancellation.isCancelled { throw PreviewFailure.cancelled }
            guard try data.integer(cursor) == 0x02014b50 else { throw PreviewFailure.invalid }
            let flags = try data.integer(cursor + 8,2), method = try data.integer(cursor + 10,2)
            guard flags & 0x41 == 0 else { throw PreviewFailure.protectedDocument }
            guard method == 0 || method == 8 else { throw PreviewFailure.unsupported }
            let compressed = try data.integer(cursor + 20), size = try data.integer(cursor + 24)
            total += size
            guard size <= 40 * 1024 * 1024, total <= 100 * 1024 * 1024 else { throw PreviewFailure.oversized }
            let nameLength = try data.integer(cursor + 28,2), extra = try data.integer(cursor + 30,2), comment = try data.integer(cursor + 32,2)
            let rawName = try data.bytes(cursor + 46,nameLength)
            guard let name = String(data:rawName,encoding:.utf8), !name.isEmpty, !name.hasPrefix("/"),
                  !name.contains("\\"), !name.contains("\0"), !name.contains(":"),
                  !name.split(separator:"/",omittingEmptySubsequences:false).contains(".."),
                  names.insert(name).inserted else { throw PreviewFailure.invalid }
            let local = try data.integer(cursor + 42)
            guard try data.integer(cursor + 34,2) == 0, try data.integer(local) == 0x04034b50,
                  try data.integer(local + 6,2) == flags, try data.integer(local + 8,2) == method else { throw PreviewFailure.invalid }
            let localNameLength = try data.integer(local + 26,2), localExtra = try data.integer(local + 28,2)
            guard try data.bytes(local + 30,localNameLength) == rawName else { throw PreviewFailure.invalid }
            let payloadStart = local + 30 + localNameLength + localExtra
            guard payloadStart + compressed <= start else { throw PreviewFailure.invalid }
            var payloadEnd = payloadStart + compressed
            if flags & 8 == 0 {
                guard try data.integer(local + 14) == data.integer(cursor + 16),
                      try data.integer(local + 18) == compressed, try data.integer(local + 22) == size else { throw PreviewFailure.invalid }
            } else {
                if try data.integer(payloadEnd) == 0x08074b50 { payloadEnd += 4 }
                guard try data.integer(payloadEnd) == data.integer(cursor + 16),
                      try data.integer(payloadEnd + 4) == compressed, try data.integer(payloadEnd + 8) == size else { throw PreviewFailure.invalid }
                payloadEnd += 12
            }
            let range = local..<payloadEnd
            guard payloadEnd <= start, !ranges.contains(where: { $0.overlaps(range) }) else { throw PreviewFailure.invalid }
            ranges.append(range)
            let compressedData = try data.bytes(payloadStart,compressed)
            let contents = try method == 0 ? compressedData : inflateRaw(compressedData,expected:size)
            guard contents.count == size else { throw PreviewFailure.invalid }
            let checksum = contents.withUnsafeBytes { crc32(0,$0.bindMemory(to:Bytef.self).baseAddress,uInt(contents.count)) }
            guard try checksum == data.integer(cursor + 16) else { throw PreviewFailure.invalid }
            if name.lowercased().hasSuffix(".xml") || name.lowercased().hasSuffix(".hpf") {
                try xml(contents, cancellation: cancellation)
            }
            if name == "mimetype", contents != Data("application/hwp+zip".utf8) { throw PreviewFailure.invalid }
            cursor += 46 + nameLength + extra + comment
            guard cursor <= end else { throw PreviewFailure.invalid }
        }
        guard cursor == end, names.contains("Contents/content.hpf"), names.contains("META-INF/manifest.xml") else { throw PreviewFailure.invalid }
    }
    private static func xml(_ data: Data, cancellation: Cancellation) throws {
        // Reject declarations before XMLParser, including UTF-16/32 ASCII declarations.
        let ascii = String(decoding:data.filter { $0 != 0 },as:UTF8.self).uppercased()
        guard !ascii.contains("<!DOCTYPE"), !ascii.contains("<!ENTITY") else { throw PreviewFailure.invalid }
        let parser = XMLParser(data:data)
        let delegate = XMLGuard(cancellation)
        parser.shouldResolveExternalEntities = false
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        let parsed = parser.parse()
        if let failure = delegate.failure { throw failure }
        guard parsed else { throw PreviewFailure.invalid }
    }
    private static func cfb(_ data: Data, _ cancellation: Cancellation) throws {
        guard data.count >= 512, data.starts(with:[0xd0,0xcf,0x11,0xe0,0xa1,0xb1,0x1a,0xe1]) else { throw PreviewFailure.invalid }
        let major = try data.integer(26,2), shift = try data.integer(30,2)
        guard (major == 3 && shift == 9) || (major == 4 && shift == 12),
              try data.integer(28,2) == 0xfffe, try data.integer(32,2) == 6, try data.integer(56) == 4096 else { throw PreviewFailure.invalid }
        let size = 1 << shift, sectors = data.count / size - 1
        guard sectors > 0, data.count % size == 0 else { throw PreviewFailure.invalid }
        func sector(_ id: Int) throws -> Data {
            if cancellation.isCancelled { throw PreviewFailure.cancelled }
            guard id >= 0, id < sectors else { throw PreviewFailure.invalid }
            return try data.bytes((id + 1) * size,size)
        }
        var fatIDs = [Int]()
        for i in 0..<109 { let id = try data.integer(76 + i * 4); if id != 0xffffffff { fatIDs.append(id) } }
        var difat = try data.integer(68), visited = Set<Int>()
        let difatCount = try data.integer(72), fatCount = try data.integer(44)
        guard difatCount <= sectors, fatCount <= sectors else { throw PreviewFailure.invalid }
        for _ in 0..<difatCount {
            guard visited.insert(difat).inserted else { throw PreviewFailure.invalid }
            let block = try sector(difat)
            for i in 0..<(size / 4 - 1) { let id = try block.integer(i * 4); if id != 0xffffffff { fatIDs.append(id) } }
            difat = try block.integer(size - 4)
        }
        guard fatIDs.count == fatCount, Set(fatIDs).count == fatCount else { throw PreviewFailure.invalid }
        var fat = [Int]()
        for id in fatIDs { let block = try sector(id); for i in stride(from:0,to:size,by:4) { fat.append(try block.integer(i)) } }
        func chain(_ first: Int) throws -> Data {
            var id = first, seen = Set<Int>(), result = Data()
            while id != 0xfffffffe {
                guard id < fat.count, seen.insert(id).inserted, seen.count <= sectors else { throw PreviewFailure.invalid }
                result.append(try sector(id)); id = fat[id]
            }
            return result
        }
        let directory = try chain(data.integer(48))
        var root: (Int,Int)?, header: (Int,Int)?
        var streams = [(String,Int,Int)](), declared = 0
        for offset in stride(from:0,to:directory.count,by:128) {
            let length = try directory.integer(offset + 64,2), type = try directory.integer(offset + 66,1)
            if type == 0 { continue }
            guard length >= 2, length <= 64, length % 2 == 0 else { throw PreviewFailure.invalid }
            let name = String(data:try directory.bytes(offset,length - 2),encoding:.utf16LittleEndian)
            let start = try directory.integer(offset + 116), lengthLow = try directory.integer(offset + 120)
            guard try directory.integer(offset + 124) == 0 else { throw PreviewFailure.oversized }
            if type == 2 {
                declared += lengthLow
                guard declared <= 100 * 1024 * 1024, lengthLow <= 40 * 1024 * 1024 else { throw PreviewFailure.oversized }
                streams.append((name ?? "",start,lengthLow))
            }
            if type == 5 { guard root == nil else { throw PreviewFailure.invalid }; root = (start,lengthLow) }
            if type == 2 && name == "FileHeader" { guard header == nil else { throw PreviewFailure.invalid }; header = (start,lengthLow) }
        }
        guard let root, let header, header.1 >= 40, header.1 <= 4096 else { throw PreviewFailure.invalid }
        var miniFAT: Data?, miniStream: Data?
        func readStream(_ start: Int, _ length: Int) throws -> Data {
            if length == 0 { return Data() }
            if length >= 4096 {
                let bytes = try chain(start)
                guard bytes.count >= length, bytes.count - length < size else { throw PreviewFailure.invalid }
                return Data(bytes.prefix(length))
            }
            if miniFAT == nil { miniFAT = try chain(data.integer(60)); miniStream = try chain(root.0) }
            var id = start, result = Data(), seen = Set<Int>()
            while result.count < length {
                guard seen.insert(id).inserted else { throw PreviewFailure.invalid }
                result.append(try miniStream!.bytes(id * 64,64)); id = try miniFAT!.integer(id * 4)
            }
            guard id == 0xfffffffe else { throw PreviewFailure.invalid }
            return Data(result.prefix(length))
        }
        let bytes = try readStream(header.0,header.1)
        guard bytes.starts(with:Array("HWP Document File".utf8)), try bytes.integer(35,1) == 5 else { throw PreviewFailure.unsupported }
        let flags = try bytes.integer(36)
        // Password, distribution, DRM, certificate encryption/DRM and privacy protection: do not ask the engine to unlock them.
        guard flags & 0x2516 == 0 else { throw PreviewFailure.protectedDocument }
        var expanded = 0
        for (name,start,length) in streams {
            let raw = try readStream(start,length)
            let isRecords = name == "DocInfo" || name.range(of:"^Section[0-9]+$",options:.regularExpression) != nil
            let candidate = flags & 1 != 0 && (isRecords || name.uppercased().hasPrefix("BIN"))
            let inflated = try candidate ? inflateBounded(raw,limit:min(40 * 1024 * 1024,100 * 1024 * 1024 - expanded),cancellation:cancellation) : nil
            if isRecords && flags & 1 != 0 && inflated == nil { throw PreviewFailure.invalid }
            let contents = inflated ?? raw
            expanded += contents.count
            guard expanded <= 100 * 1024 * 1024 else { throw PreviewFailure.oversized }
            if isRecords { try records(contents) }
        }
    }
}

private final class XMLGuard: NSObject, XMLParserDelegate {
    var failure: PreviewFailure?
    private var depth = 0, elements = 0
    private let cancellation: Cancellation
    init(_ cancellation: Cancellation) { self.cancellation = cancellation }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String:String]) {
        depth += 1; elements += 1
        if cancellation.isCancelled { failure = .cancelled }
        else if depth > 128 || elements > 200_000 { failure = .oversized }
        else if ["encryption-data","encryption","encrypted-key"].contains(elementName.lowercased()) { failure = .protectedDocument }
        if failure != nil { parser.abortParsing() }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { depth -= 1 }
}
