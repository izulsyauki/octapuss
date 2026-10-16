import AppKit
import ImageIO

struct JSONCursorLibrary: CursorLibraryStorage {
    let url: URL
    static var defaultURL: URL {
        ApplicationPaths.cursorLibrary
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
            if let slots = item.nativeSlotNames {
                guard !slots.isEmpty, slots.count <= 32, Set(slots).count == slots.count,
                      slots.allSatisfy({ CursorRole.role(forNativeSlot: $0) != nil }) else { throw invalidLibrary() }
            }
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
