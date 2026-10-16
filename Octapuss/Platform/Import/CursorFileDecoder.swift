import AppKit
import ImageIO

enum CursorFileDecoder {
    static let maximumFileSize = 4 * 1024 * 1024

    static func decodeTheme(url: URL) throws -> (name: String, cursors: [ImportedCursor]) {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumFileSize else {
            throw CursorImportError.invalid("Choose a .cursor theme smaller than 4 MB.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumFileSize + 1) ?? Data()
        return try decodeTheme(data: data, fallbackName: url.deletingPathExtension().lastPathComponent)
    }

    static func decodeTheme(data: Data, fallbackName: String) throws -> (name: String, cursors: [ImportedCursor]) {
        guard !data.isEmpty, data.count <= maximumFileSize,
              let root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let entries = root["Cursors"] as? [String: [String: Any]], !entries.isEmpty, entries.count <= 64 else {
            throw CursorImportError.invalid("This .cursor file is not a supported native cursor theme.")
        }
        let themeName = String(((root["ThemeName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName).prefix(100))
        var cursors: [ImportedCursor] = []
        var decodedPixels = 0
        for slot in entries.keys.sorted() {
            guard let role = CursorRole.role(forNativeSlot: slot), let entry = entries[slot],
                  let representations = entry["Representations"] as? [Data], !representations.isEmpty,
                  representations.count <= 16,
                  let countValue = entry["FrameCount"] as? NSNumber,
                  countValue.doubleValue.isFinite, countValue.doubleValue == Double(countValue.intValue),
                  (1...256).contains(countValue.intValue),
                  let width = entry["PointsWide"] as? Double, width.isFinite, width > 0, width <= 256,
                  let height = entry["PointsHigh"] as? Double, height.isFinite, height > 0, height <= 256,
                  let x = entry["HotSpotX"] as? Double, x.isFinite, x >= 0, x < width,
                  let y = entry["HotSpotY"] as? Double, y.isFinite, y >= 0, y < height,
                  let duration = entry["FrameDuration"] as? Double, duration.isFinite,
                  duration >= 0, duration <= 60, countValue.intValue == 1 || duration > 0 else {
                throw CursorImportError.invalid("The native cursor entry \(slot) has unsupported metadata or role.")
            }
            let count = countValue.intValue
            var best: (source: CGImageSource, width: Int, height: Int)?
            for bytes in representations {
                guard bytes.count <= maximumFileSize,
                      let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                      let w = properties[kCGImagePropertyPixelWidth] as? Int,
                      let h = properties[kCGImagePropertyPixelHeight] as? Int,
                      h % count == 0, (1...256).contains(w), (1...256).contains(h / count),
                      abs(Double(w) / Double(h / count) - width / height) < 0.1 else { continue }
                if best == nil || w * (h / count) > best!.width * best!.height {
                    best = (source, w, h / count)
                }
            }
            guard let best else {
                throw CursorImportError.invalid("The native cursor \(slot) has no valid bounded image strip.")
            }
            decodedPixels += best.width * best.height * count
            guard decodedPixels <= 16 * 1024 * 1024,
                  let strip = CGImageSourceCreateImageAtIndex(best.source, 0, nil) else {
                throw CursorImportError.invalid("The theme exceeds the decoded image limit or has an unreadable strip.")
            }
            var frames: [Data] = []
            for index in 0..<count {
                guard let frame = strip.cropping(to: CGRect(x: 0, y: index * best.height, width: best.width, height: best.height)),
                      let context = CGContext(data: nil, width: best.width, height: best.height,
                          bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw malformed() }
                context.draw(frame, in: CGRect(x: 0, y: 0, width: best.width, height: best.height))
                guard let image = context.makeImage(),
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw malformed() }
                frames.append(png)
            }
            var cursor = ImportedCursor(id: UUID(), name: "\(role.title) · \(slot.components(separatedBy: ".").last!)",
                png: frames[0], width: best.width, height: best.height,
                hotspotX: min(best.width - 1, Int((x / width * Double(best.width)).rounded())),
                hotspotY: min(best.height - 1, Int((y / height * Double(best.height)).rounded())), firstFrameOnly: false)
            cursor.animationDecoded = true
            if count > 1 { cursor.animation = CursorAnimation(frames: frames, durations: Array(repeating: duration, count: count)) }
            // Precision has distinct native variants. Keep both rather than merging
            // different images or assigning two cursors to the same slots.
            cursor.nativeSlotNames = role == .precision ? [slot] : role.slotNames
            cursors.append(cursor)
        }
        return (themeName, cursors)
    }

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
            var payload = Array(bytes[offset..<(offset + length)])
            var expandedPalette = false
            // ImageIO's ICO decoder misreads 8-bit DIBs with a short RGBQUAD
            // table. Expand only unused palette entries; retain every pixel,
            // the AND transparency mask, and the cursor's hotspot unchanged.
            if length >= 40, u32(offset) == 40, u16(offset + 14) == 8, u32(offset + 16) == 0 {
                let colors = u32(offset + 32)
                if colors > 0 && colors < 256 {
                    let paletteEnd = 40 + colors * 4
                    let pixelStride = ((width + 3) / 4) * 4
                    let maskStride = ((width + 31) / 32) * 4
                    guard length >= paletteEnd + (pixelStride + maskStride) * height else { throw malformed() }
                    payload.insert(contentsOf: Array(repeating: UInt8(0), count: (256 - colors) * 4), at: paletteEnd)
                    payload.replaceSubrange(32..<36, with: [0, 1, 0, 0]) // biClrUsed = 256
                    expandedPalette = true
                }
            }
            // ImageIO decodes ICO payloads, including palette/DIB masks and PNG images.
            // Rebuild a single-entry ICO; CUR's hotspot fields are not ICO planes/depth.
            var ico: [UInt8] = [0, 0, 1, 0, 1, 0]
            ico += Array(bytes[entry..<(entry + 16)])
            ico[10] = 1; ico[11] = 0; ico[12] = 32; ico[13] = 0
            if length >= 16, bytes[offset] == 40 || bytes[offset] == 108 || bytes[offset] == 124 {
                ico[12] = bytes[offset + 14]; ico[13] = bytes[offset + 15]
                if ico[12] < 8 { ico[8] = UInt8(1 << Int(ico[12])) }
            }
            if expandedPalette { ico[8] = 0 } // ICO directory: zero means 256 colors.
            for index in 0..<4 { ico[14 + index] = UInt8(truncatingIfNeeded: payload.count >> (index * 8)) }
            ico[18] = 22; ico[19] = 0; ico[20] = 0; ico[21] = 0
            ico += payload
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
