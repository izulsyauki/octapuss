import AppKit
import ImageIO

struct CursorAnimation: Codable {
    let frames: [Data]
    let durations: [Double]
}

enum CursorImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let reason): return reason }
    }
}

/// A normalized, local copy: no dependency on the original Downloads file.
struct ImportedCursor: Codable, Identifiable {
    var id: UUID
    let name: String
    let png: Data
    let width: Int
    let height: Int
    let hotspotX: Int
    let hotspotY: Int
    let firstFrameOnly: Bool
    var collectionID: UUID? = nil
    var collectionName: String? = nil
    var roleOverride: String? = nil
    var animation: CursorAnimation? = nil
    var animationDecoded: Bool? = nil

    var setID: UUID { collectionID ?? id }
    var needsAnimationUpgrade: Bool { firstFrameOnly && animationDecoded != true }

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
        let timeline = systemTimeline
        let sourceFrames = try timeline.frames.map { data -> CGImage in
            guard let image = NSBitmapImageRep(data: data)?.cgImage else {
                throw CursorImportError.invalid("An animation frame could not be read. Reimport this cursor.")
            }
            return image
        }
        let images = try [1.0, 2.0, 5.0, 10.0].map { scale -> Data in
            let w = max(1, Int((logicalSize.width * scale).rounded()))
            let h = max(1, Int((logicalSize.height * scale).rounded()))
            guard let context = CGContext(data: nil, width: w,
                    height: h * sourceFrames.count, bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw CursorImportError.invalid("The imported image could not be rendered. Import it again.")
            }
            context.interpolationQuality = .none
            for (index, frame) in sourceFrames.enumerated() {
                context.draw(frame, in: CGRect(x: 0, y: (sourceFrames.count - index - 1) * h, width: w, height: h))
            }
            guard let image = context.makeImage(),
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw CursorImportError.invalid("The imported image could not be rendered. Import it again.")
            }
            return data
        }
        return CursorSnapshot(name: name, width: logicalSize.width, height: logicalSize.height,
                              x: CGFloat(hotspotX) * factor, y: CGFloat(hotspotY) * factor,
                              frames: sourceFrames.count, duration: timeline.duration, images: images)
    }

    /// The native backend has a uniform frame interval and a 24-frame limit.
    /// Constant-rate ANI up to 24 steps is exact; other timelines are time-sampled.
    var systemTimeline: (frames: [Data], duration: Double) {
        guard let animation, animation.frames.count > 1 else { return ([png], 0) }
        let total = animation.durations.reduce(0, +)
        let equal = animation.durations.allSatisfy { abs($0 - animation.durations[0]) < 0.000001 }
        if animation.frames.count <= 24 && equal { return (animation.frames, animation.durations[0]) }
        let count = min(24, max(2, animation.frames.count))
        let interval = total / Double(count)
        var output: [Data] = []
        var index = 0
        var end = animation.durations[0]
        for step in 0..<count {
            let time = Double(step) * interval
            while index + 1 < animation.frames.count && time >= end {
                index += 1
                end += animation.durations[index]
            }
            output.append(animation.frames[index])
        }
        return (output, interval)
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
        if data.starts(with: Array("RIFF".utf8)) { return try decodeANI(data, name: name) }
        return try decodeCUR(data, name: name)
    }

    private static func decodeCUR(_ data: Data, name: String) throws -> ImportedCursor {
        let bytes = [UInt8](data)
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
                                  hotspotX: candidate.2, hotspotY: candidate.3, firstFrameOnly: false)
        }
        throw CursorImportError.invalid("This cursor's image encoding is unsupported. Try another .cur file from the set.")
    }

    private static func decodeANI(_ data: Data, name: String) throws -> ImportedCursor {
        let bytes = [UInt8](data)
        func u32(_ offset: Int) -> Int { (0..<4).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) } }
        func tag(_ offset: Int) -> String { String(bytes: bytes[offset..<(offset + 4)], encoding: .ascii) ?? "" }
        guard bytes.count >= 12, tag(8) == "ACON", u32(4) == bytes.count - 8 else { throw malformed() }
        var frames: [Data] = []
        var sequence: [Int] = []
        var rates: [Int] = []
        var header: [Int] = []
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
                    guard size >= 4, size % 4 == 0, size <= 256 * 4 else { throw malformed() }
                    sequence = stride(from: body, to: body + size, by: 4).map(u32)
                case "rate":
                    guard size >= 4, size % 4 == 0, size <= 256 * 4 else { throw malformed() }
                    rates = stride(from: body, to: body + size, by: 4).map(u32)
                case "anih":
                    guard size >= 36 else { throw malformed() }
                    header = stride(from: body, to: body + 36, by: 4).map(u32)
                default: break
                }
                position = body + size + size % 2
                guard position <= end else { throw malformed() }
            }
        }
        try walk(12, bytes.count, depth: 0)
        guard !frames.isEmpty else { throw malformed() }
        // Incomplete legacy ANI containers remain a clearly labeled static fallback.
        if header.isEmpty {
            let first = sequence.first ?? 0
            guard first < frames.count else { throw malformed() }
            let cursor = try decodeCUR(frames[first], name: name)
            var fallback = ImportedCursor(id: cursor.id, name: cursor.name, png: cursor.png, width: cursor.width,
                height: cursor.height, hotspotX: cursor.hotspotX, hotspotY: cursor.hotspotY, firstFrameOnly: true)
            fallback.animationDecoded = true
            return fallback
        }
        guard header[0] >= 36, header[1] == frames.count, header[1] <= 256,
              header[2] > 0, header[2] <= 256, header[8] & 1 == 1 else { throw malformed() }
        let steps = header[2]
        if sequence.isEmpty {
            guard header[8] & 2 == 0 else { throw malformed() }
            sequence = (0..<steps).map { $0 % frames.count }
        }
        guard sequence.count == steps, sequence.allSatisfy({ $0 < frames.count }),
              rates.isEmpty || rates.count == steps else { throw malformed() }
        let fallback = header[7] == 0 ? 6 : header[7]
        let jiffies = rates.isEmpty ? Array(repeating: fallback, count: steps) : rates.map { $0 == 0 ? fallback : $0 }
        guard jiffies.allSatisfy({ $0 > 0 && $0 <= 3600 }) else { throw malformed() }
        let decoded = try frames.map { try decodeCUR($0, name: name) }
        var result = decoded[sequence[0]]
        result.animationDecoded = true
        guard decoded.allSatisfy({ $0.width == result.width && $0.height == result.height
            && $0.hotspotX == result.hotspotX && $0.hotspotY == result.hotspotY }) else {
            throw CursorImportError.invalid("ANI frames need a consistent canvas and click point. Try another cursor file.")
        }
        if steps > 1 {
            result.animation = CursorAnimation(frames: sequence.map { decoded[$0].png }, durations: jiffies.map { Double($0) / 60 })
        }
        return result
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
            if let role = item.roleOverride, role != "unassigned", CursorRole(rawValue: role) == nil { throw invalidLibrary() }
            if let animation = item.animation {
                guard (2...256).contains(animation.frames.count), animation.frames.count == animation.durations.count,
                      animation.durations.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 60 }) else { throw invalidLibrary() }
                for png in animation.frames {
                    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
                          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                          properties[kCGImagePropertyPixelWidth] as? Int == item.width,
                          properties[kCGImagePropertyPixelHeight] as? Int == item.height,
                          NSImage(data: png) != nil else { throw invalidLibrary() }
                }
            }
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
