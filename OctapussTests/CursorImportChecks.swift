import AppKit

enum CursorImportChecks {
    @MainActor
    static func run() throws {
        func le(_ value: Int, _ count: Int) -> [UInt8] {
            (0..<count).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
        }
        func cur(_ payload: [UInt8], width: Int, height: Int, x: Int, y: Int) -> Data {
            Data([0, 0, 2, 0, 1, 0, UInt8(width), UInt8(height), 0, 0] + le(x, 2) + le(y, 2)
                 + le(payload.count, 4) + le(22, 4) + payload)
        }
        func chunk(_ tag: String, _ bytes: [UInt8]) -> [UInt8] {
            Array(tag.utf8) + le(bytes.count, 4) + bytes + (bytes.count % 2 == 1 ? [0] : [])
        }
        let image = NSImage(size: NSSize(width: 16, height: 32), flipped: true) { rect in
            NSColor.systemPink.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)).fill()
            return true
        }
        let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
        let pngCursor = cur(Array(png), width: 16, height: 32, x: 8, y: 24)
        let decoded = try CursorFileDecoder.decode(data: pngCursor, name: "Synthetic pink")
        precondition(decoded.width == 16 && decoded.height == 32 && decoded.hotspotX == 8 && decoded.hotspotY == 24)
        let snapshot = try decoded.snapshot(name: "arrow", longestSide: 40)
        precondition(snapshot.width == 20 && snapshot.height == 40 && snapshot.x == 10 && snapshot.y == 30)
        precondition(snapshot.images.count == 4)
        let cursor = decoded.cursor(longestSide: 40)
        precondition(cursor.hotSpot == NSPoint(x: 10, y: 30) && cursor.image.size == NSSize(width: 20, height: 40))

        // A 1-bit bottom-up DIB with opaque white XOR pixels and an AND mask.
        let header = le(40, 4) + le(16, 4) + le(32, 4) + le(1, 2) + le(1, 2)
            + Array(repeating: UInt8(0), count: 24)
        let palette: [UInt8] = [0, 0, 0, 0, 255, 255, 255, 0]
        let xor: [UInt8] = (0..<16).flatMap { _ -> [UInt8] in [255, 255, 0, 0] }
        var mask = Array(repeating: UInt8(0), count: 64)
        mask[60] = 128 // Top-left is transparent after bottom-up decoding.
        let dibCursor = cur(header + palette + xor + mask, width: 16, height: 16, x: 1, y: 2)
        let dib = try CursorFileDecoder.decode(data: dibCursor, name: "Synthetic monochrome")
        precondition(dib.width == 16 && dib.hotspotX == 1)
        let bitmap = NSBitmapImageRep(data: dib.png)!
        precondition(bitmap.colorAt(x: 0, y: 0)!.alphaComponent < 0.01, "DIB transparency must survive import")
        precondition(bitmap.colorAt(x: 1, y: 0)!.alphaComponent > 0.99)

        let frames = chunk("LIST", Array("fram".utf8) + chunk("icon", Array(dibCursor)) + chunk("icon", Array(pngCursor)))
        let body = Array("ACON".utf8) + chunk("seq ", le(1, 4)) + frames
        let ani = Data(Array("RIFF".utf8) + le(body.count, 4) + body)
        let animated = try CursorFileDecoder.decode(data: ani, name: "Synthetic animation")
        precondition(animated.firstFrameOnly && animated.width == 16 && animated.height == 32,
                     "ANI must honor the first sequence entry")
        precondition(!animated.needsAnimationUpgrade, "A known headerless ANI fallback must not offer an endless upgrade")

        var invalidOffset = [UInt8](pngCursor)
        invalidOffset.replaceSubrange(18..<22, with: [255, 255, 255, 255])
        var invalidHotspot = [UInt8](pngCursor)
        invalidHotspot[10] = 16
        for malformed in [Data(), Data(pngCursor.prefix(10)), Data(invalidOffset), Data(invalidHotspot),
                          Data(ani.dropLast()), Data(repeating: 0, count: CursorFileDecoder.maximumFileSize + 1)] {
            do {
                _ = try CursorFileDecoder.decode(data: malformed, name: "Invalid")
                preconditionFailure("Invalid cursor must be rejected")
            } catch {}
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("octapuss-import-check-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("Synthetic pink.cur")
        try pngCursor.write(to: file)
        let libraryURL = directory.appendingPathComponent("library.json")
        let suite = "octapuss-import-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProofStore(defaults: defaults, allowsSystemCustomization: false, libraryURL: libraryURL)
        store.importCursorFiles([file])
        precondition(store.importedCursors.count == 1 && store.selectedImportedCursor != nil && !store.systemApplied)
        let id = store.selectedImportedID
        store.importCursorFiles([file])
        precondition(store.importedCursors.count == 1 && store.selectedImportedID == id, "Reimport must deduplicate")
        let reopened = ProofStore(defaults: defaults, allowsSystemCustomization: false, libraryURL: libraryURL)
        precondition(reopened.selectedImportedID == id && reopened.importedCursors.count == 1)
        try FileManager.default.removeItem(at: file)
        precondition(reopened.selectedImportedCursor!.image(longestSide: 32).isValid, "Library must be independent of Downloads")
        reopened.pack = .blush
        precondition(reopened.selectedImportedID == nil, "Built-in selection must clear imported selection")
        reopened.selectedImportedID = id
        reopened.removeSelectedImport()
        precondition(reopened.importedCursors.isEmpty && reopened.selectedImportedID == nil)
        let empty = try CursorLibrary(url: libraryURL).load()
        precondition(empty.isEmpty)

        // Existing libraries had no collection keys: retain them as single-cursor sets.
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode([decoded])) as! [[String: Any]]
        legacy[0].removeValue(forKey: "collectionID")
        legacy[0].removeValue(forKey: "collectionName")
        try JSONSerialization.data(withJSONObject: legacy).write(to: libraryURL)
        let migrated = ProofStore(defaults: defaults, allowsSystemCustomization: false, libraryURL: libraryURL)
        precondition(migrated.cursorCollections.count == 1 && migrated.cursorCollections[0].id == decoded.id)

        let setFolder = directory.appendingPathComponent("Synthetic cursor set")
        try FileManager.default.createDirectory(at: setFolder, withIntermediateDirectories: true)
        try pngCursor.write(to: setFolder.appendingPathComponent("Arrow.cur"))
        try pngCursor.write(to: setFolder.appendingPathComponent("Select.cur"))
        try dibCursor.write(to: setFolder.appendingPathComponent("Precision.cur"))
        try ani.write(to: setFolder.appendingPathComponent("Working.ani"))
        try Data("Ignored metadata".utf8).write(to: setFolder.appendingPathComponent("readme.txt"))
        migrated.importCursorFolder(setFolder)
        let set = migrated.selectedCollection!
        precondition(set.name == "Synthetic cursor set" && set.cursors.count == 4,
                     "Distinct filenames must survive even when artwork is identical")
        precondition(Set(set.cursors.map(\.name)).contains("Arrow") && Set(set.cursors.map(\.name)).contains("Select"))
        migrated.selectedImportedID = set.cursors[0].id
        migrated.assignSelectedRole(CursorRole.copy.rawValue)
        migrated.importCursorFolder(setFolder)
        precondition(migrated.selectedCollection?.id == set.id && migrated.selectedCollection?.cursors.count == 4,
                     "Updating the same folder must preserve its collection rather than duplicate it")
        precondition(Set(migrated.selectedCollection!.cursors.map(\.id)) == Set(set.cursors.map(\.id)))
        precondition(migrated.importedCursors.first { $0.id == set.cursors[0].id }?.effectiveRole == .copy,
                     "Updating animation data must preserve an explicit role assignment")
        precondition(!migrated.systemApplied, "Importing a set must never apply it")
        migrated.selectedImportedID = set.cursors[1].id
        precondition(migrated.selectedCollection?.id == set.id)
        migrated.removeSelectedImport()
        precondition(migrated.selectedCollection?.id == set.id && migrated.selectedCollection?.cursors.count == 3,
                     "Removing one cursor must keep the rest of its set selected")
        let reloadedSets = ProofStore(defaults: defaults, allowsSystemCustomization: false, libraryURL: libraryURL)
        precondition(reloadedSets.selectedCollection?.id == set.id && reloadedSets.selectedCollection?.cursors.count == 3)

        if let path = ProcessInfo.processInfo.environment["OCTAPUSS_IMPORT_FIXTURE_DIR"] {
            let fixtures = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
            try pngCursor.write(to: fixtures.appendingPathComponent("Synthetic pink.cur"))
            try dibCursor.write(to: fixtures.appendingPathComponent("Synthetic monochrome.cur"))
            try ani.write(to: fixtures.appendingPathComponent("Synthetic animation.ani"))
        }
        if let paths = ProcessInfo.processInfo.environment["OCTAPUSS_REAL_CURSOR_FILES"] {
            for path in paths.split(separator: ":") {
                let item = try CursorFileDecoder.decode(url: URL(fileURLWithPath: String(path)))
                print("Real import verified: \(item.name), \(item.width)x\(item.height), hotspot \(item.hotspotX),\(item.hotspotY), first-frame \(item.firstFrameOnly)")
            }
        }
        print("Import checks passed: PNG/DIB CUR, mask transparency, ANI sequence, malformed files, scaled hotspots, persistence, deduplication, removal, legacy libraries, folder sets, set selection.")
    }
}
