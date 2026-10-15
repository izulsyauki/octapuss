import AppKit
import ImageIO

enum CursorImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let reason): return reason }
    }
}

/// A normalized, local copy: no dependency on the original Downloads file.
struct ImportedCursor: Codable, Identifiable {
    let id: UUID
    let name: String
    let png: Data
    let width: Int
    let height: Int
    let hotspotX: Int
    let hotspotY: Int
    let firstFrameOnly: Bool
    var collectionID: UUID? = nil
    var collectionName: String? = nil

    var setID: UUID { collectionID ?? id }

    func image(longestSide: CGFloat) -> NSImage {
        let scale = longestSide / CGFloat(max(width, height))
        let image = NSImage(data: png)!
        image.size = NSSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
        return image
    }

    func cursor(longestSide: CGFloat) -> NSCursor {
        let scale = longestSide / CGFloat(max(width, height))
        return NSCursor(image: image(longestSide: longestSide),
                        hotSpot: NSPoint(x: CGFloat(hotspotX) * scale, y: CGFloat(hotspotY) * scale))
    }

    func snapshot(name: String, longestSide: CGFloat) throws -> CursorSnapshot {
        let factor = longestSide / CGFloat(max(width, height))
        let logicalSize = CGSize(width: CGFloat(width) * factor, height: CGFloat(height) * factor)
        let images = try [1.0, 2.0, 5.0, 10.0].map { scale -> Data in
            guard let original = NSBitmapImageRep(data: png)?.cgImage,
                  let context = CGContext(data: nil, width: max(1, Int((logicalSize.width * scale).rounded())),
                    height: max(1, Int((logicalSize.height * scale).rounded())), bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw CursorImportError.invalid("The imported image could not be rendered. Import it again.")
            }
            context.interpolationQuality = .none
            context.draw(original, in: CGRect(x: 0, y: 0, width: context.width, height: context.height))
            guard let image = context.makeImage(),
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw CursorImportError.invalid("The imported image could not be rendered. Import it again.")
            }
            return data
        }
        return CursorSnapshot(name: name, width: logicalSize.width, height: logicalSize.height,
                              x: CGFloat(hotspotX) * factor, y: CGFloat(hotspotY) * factor,
                              frames: 1, duration: 0, images: images)
    }
}

struct CursorCollection: Identifiable {
    let id: UUID
    let name: String
    let cursors: [ImportedCursor]
}

enum CursorFileDecoder {
    static let maximumFileSize = 4 * 1024 * 1024

    static func decode(url: URL) throws -> ImportedCursor {
        guard ["cur", "ani"].contains(url.pathExtension.lowercased()) else {
            throw CursorImportError.invalid("Choose a .cur or .ani file. Unzip cursor sets first.")
        }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumFileSize else {
            throw CursorImportError.invalid("Choose a cursor file smaller than 4 MB.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumFileSize + 1) ?? Data()
        return try decode(data: data, name: url.deletingPathExtension().lastPathComponent)
    }

    static func decode(data: Data, name: String) throws -> ImportedCursor {
        guard !data.isEmpty, data.count <= maximumFileSize else { throw malformed() }
        let animated = data.starts(with: Array("RIFF".utf8))
        let bytes = [UInt8](try animated ? firstANIFrame(data) : data)
        func u16(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
        func u32(_ offset: Int) -> Int { (0..<4).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) } }
        guard bytes.count >= 6, u16(0) == 0, u16(2) == 2 else { throw malformed() }
        let count = u16(4)
        guard count > 0, count <= 64, bytes.count >= 6 + count * 16 else { throw malformed() }
        var candidates: [(Int, Int, Int, Int, Data)] = []
        for index in 0..<count {
            let entry = 6 + index * 16
            let width = bytes[entry] == 0 ? 256 : Int(bytes[entry])
            let height = bytes[entry + 1] == 0 ? 256 : Int(bytes[entry + 1])
            let x = u16(entry + 4), y = u16(entry + 6)
            let length = u32(entry + 8), offset = u32(entry + 12)
            guard x < width, y < height, length > 0, offset >= 6 + count * 16,
                  offset <= bytes.count, length <= bytes.count - offset else { throw malformed() }
            // ImageIO decodes ICO payloads, including palette/DIB masks and PNG images.
            // Rebuild a single-entry ICO; CUR's hotspot fields are not ICO planes/depth.
            var ico: [UInt8] = [0, 0, 1, 0, 1, 0]
            ico += Array(bytes[entry..<(entry + 16)])
            ico[10] = 1; ico[11] = 0; ico[12] = 32; ico[13] = 0
            if length >= 16, bytes[offset] == 40 || bytes[offset] == 108 || bytes[offset] == 124 {
                ico[12] = bytes[offset + 14]; ico[13] = bytes[offset + 15]
                if ico[12] < 8 { ico[8] = UInt8(1 << Int(ico[12])) }
            }
            ico[18] = 22; ico[19] = 0; ico[20] = 0; ico[21] = 0
            ico += bytes[offset..<(offset + length)]
            candidates.append((width, height, x, y, Data(ico)))
        }
        for candidate in candidates.sorted(by: { $0.0 * $0.1 > $1.0 * $1.1 }) {
            guard let source = CGImageSourceCreateWithData(candidate.4 as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let w = properties[kCGImagePropertyPixelWidth] as? Int,
                  let h = properties[kCGImagePropertyPixelHeight] as? Int,
                  w == candidate.0, h == candidate.1,
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  image.width == w, image.height == h,
                  let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                    bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let normalized = context.makeImage(),
                  let png = NSBitmapImageRep(cgImage: normalized).representation(using: .png, properties: [:]) else { continue }
            return ImportedCursor(id: UUID(), name: String(name.prefix(100)), png: png, width: w, height: h,
                                  hotspotX: candidate.2, hotspotY: candidate.3, firstFrameOnly: animated)
        }
        throw CursorImportError.invalid("This cursor's image encoding is unsupported. Try another .cur file from the set.")
    }

    private static func firstANIFrame(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        func u32(_ offset: Int) -> Int { (0..<4).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) } }
        func tag(_ offset: Int) -> String { String(bytes: bytes[offset..<(offset + 4)], encoding: .ascii) ?? "" }
        guard bytes.count >= 12, tag(8) == "ACON", u32(4) == bytes.count - 8 else { throw malformed() }
        var frames: [Data] = []
        var firstStep = 0
        func walk(_ start: Int, _ end: Int, depth: Int) throws {
            guard depth <= 2 else { throw malformed() }
            var position = start
            while position < end {
                guard end - position >= 8 else { throw malformed() }
                let size = u32(position + 4), body = position + 8
                guard size <= end - body else { throw malformed() }
                switch tag(position) {
                case "LIST":
                    guard size >= 4 else { throw malformed() }
                    if tag(body) == "fram" { try walk(body + 4, body + size, depth: depth + 1) }
                case "icon":
                    guard frames.count < 256 else { throw malformed() }
                    frames.append(Data(bytes[body..<(body + size)]))
                case "seq ":
                    guard size >= 4, size % 4 == 0 else { throw malformed() }
                    firstStep = u32(body)
                default: break
                }
                position = body + size + size % 2
                guard position <= end else { throw malformed() }
            }
        }
        try walk(12, bytes.count, depth: 0)
        guard firstStep < frames.count else { throw malformed() }
        return frames[firstStep]
    }

    private static func malformed() -> CursorImportError {
        .invalid("This cursor file is damaged or unsupported. Download the .cur or .ani file again.")
    }
}

struct CursorLibrary {
    let url: URL
    static var defaultURL: URL {
        SystemCursorSession.defaultJournalURL.deletingLastPathComponent().appendingPathComponent("imported-cursors.json")
    }

    func load() throws -> [ImportedCursor] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 64 * 1024 * 1024 else { throw CursorImportError.invalid("The cursor library is too large to open.") }
        let items = try JSONDecoder().decode([ImportedCursor].self, from: Data(contentsOf: url))
        guard items.count <= 128, Set(items.map(\.id)).count == items.count else { throw invalidLibrary() }
        for item in items {
            guard item.width > 0, item.width <= 256, item.height > 0, item.height <= 256,
                  item.hotspotX >= 0, item.hotspotX < item.width, item.hotspotY >= 0, item.hotspotY < item.height,
                  let source = CGImageSourceCreateWithData(item.png as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  properties[kCGImagePropertyPixelWidth] as? Int == item.width,
                  properties[kCGImagePropertyPixelHeight] as? Int == item.height,
                  NSImage(data: item.png) != nil else { throw invalidLibrary() }
        }
        return items
    }

    func save(_ items: [ImportedCursor]) throws {
        guard items.count <= 128 else { throw CursorImportError.invalid("Your library holds up to 128 cursors. Remove one before importing more.") }
        let data = try JSONEncoder().encode(items)
        guard data.count <= 64 * 1024 * 1024 else { throw invalidLibrary() }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func invalidLibrary() -> CursorImportError {
        .invalid("The saved cursor library could not be read safely. Your original downloads are unchanged.")
    }
}
