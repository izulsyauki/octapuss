import AppKit

enum CursorPackChecks {
    @MainActor
    static func run() throws {
        func le(_ value: Int, _ length: Int) -> [UInt8] {
            (0..<length).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
        }
        func png(_ color: NSColor) -> Data {
            let image = NSImage(size: NSSize(width: 32, height: 32), flipped: true) { rect in
                color.setFill(); rect.fill(); return true
            }
            return NSBitmapImageRep(cgImage: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
                .representation(using: .png, properties: [:])!
        }
        func cur(_ png: Data) -> Data {
            Data([0, 0, 2, 0, 1, 0, 32, 32, 0, 0] + le(1, 2) + le(2, 2) + le(png.count, 4) + le(22, 4) + Array(png))
        }
        func chunk(_ tag: String, _ data: [UInt8]) -> [UInt8] {
            Array(tag.utf8) + le(data.count, 4) + data + (data.count % 2 == 0 ? [] : [0])
        }
        let red = cur(png(.red)), blue = cur(png(.blue))
        let header = [36, 2, 2, 0, 0, 0, 0, 6, 3].flatMap { le($0, 4) }
        let body = Array("ACON".utf8) + chunk("anih", header) + chunk("rate", le(6, 4) + le(12, 4))
            + chunk("seq ", le(1, 4) + le(0, 4))
            + chunk("LIST", Array("fram".utf8) + chunk("icon", Array(red)) + chunk("icon", Array(blue)))
        let ani = Data(Array("RIFF".utf8) + le(body.count, 4) + body)
        let decoded = try CursorFileDecoder.decode(data: ani, name: "04 Busy")
        precondition(!decoded.firstFrameOnly && decoded.animation?.frames.count == 2)
        precondition(decoded.animation!.durations == [0.1, 0.2])
        let first = try CursorFileDecoder.decode(data: blue, name: "Blue")
        precondition(decoded.png == first.png, "ANI sequence must determine the first frame")
        let sprite = try decoded.snapshot(name: "busy", longestSide: 32)
        precondition(sprite.frames == 2 && abs(sprite.duration - 0.15) < 0.000001)
        RegistrationProbe.calls = []
        try SystemCursorAPI.write(sprite, connection: 123, register: RegistrationProbe.register)
        precondition(RegistrationProbe.calls.count == 1)
        let registration = RegistrationProbe.calls[0]
        precondition(registration.connection == 123 && registration.name == sprite.name)
        precondition(registration.globally && !registration.instantly,
                     "Registering a role must not display it over the current semantic cursor")
        precondition(registration.frames == sprite.frames && registration.imageCount == sprite.images.count)
        precondition(registration.size == CGSize(width: sprite.width, height: sprite.height))
        precondition(registration.hotspot == CGPoint(x: sprite.x, y: sprite.y))
        precondition(registration.duration == sprite.duration)
        RegistrationProbe.result = -1
        do {
            try SystemCursorAPI.write(sprite, connection: 123, register: RegistrationProbe.register)
            preconditionFailure("Native registration errors must still propagate")
        } catch CursorSystemError.call(_, let code) { precondition(code == -1) }
        RegistrationProbe.result = 0
        print("Native registration checks passed: global role updates without forced display; metadata and errors preserved.")
        let bitmap = NSBitmapImageRep(data: sprite.images[0])!
        precondition(bitmap.pixelsWide == 32 && bitmap.pixelsHigh == 64)
        precondition(bitmap.colorAt(x: 16, y: 16)!.usingColorSpace(.deviceRGB)!.blueComponent > 0.99,
                     "Native animation strip must put the first sequence frame at the top")
        precondition(bitmap.colorAt(x: 16, y: 48)!.usingColorSpace(.deviceRGB)!.redComponent > 0.99)

        let nativeEntry: [String: Any] = ["FrameCount": 2, "FrameDuration": 0.15,
            "PointsWide": 32.0, "PointsHigh": 32.0, "HotSpotX": 4.0, "HotSpotY": 6.0,
            "Representations": [sprite.images[0]]]
        let nativeRoot: [String: Any] = ["ThemeName": "Native test", "Cursors": [
            "com.apple.coregraphics.Arrow": nativeEntry,
            "com.apple.cursor.7": nativeEntry, "com.apple.cursor.8": nativeEntry]]
        let nativeData = try PropertyListSerialization.data(fromPropertyList: nativeRoot, format: .xml, options: 0)
        let native = try CursorFileDecoder.decodeTheme(data: nativeData, fallbackName: "Fallback")
        precondition(native.name == "Native test" && native.cursors.count == 3)
        let nativeArrow = native.cursors.first { $0.effectiveRole == .arrow }!
        precondition(nativeArrow.hotspotX == 4 && nativeArrow.hotspotY == 6)
        precondition(nativeArrow.animation!.frames.count == 2 && nativeArrow.animation!.durations == [0.15, 0.15])
        let nativeBitmap = NSBitmapImageRep(data: nativeArrow.png)!
        precondition(nativeBitmap.colorAt(x: 16, y: 16)!.usingColorSpace(.deviceRGB)!.blueComponent > 0.99,
                     "Native theme strips must retain their first frame and vertical order")
        let fractional = CursorSnapshot(name: "fractional", width: 32, height: 30.967741935483872,
            x: 1.23456789, y: 2.34567891, frames: 2, duration: 0.4, images: sprite.images)
        let rounded = CursorSnapshot(name: fractional.name, width: 32, height: Double(Float(fractional.height)),
            x: Double(Float(fractional.x)), y: Double(Float(fractional.y)), frames: 2,
            duration: Double(Float(0.4)), images: sprite.images)
        let roundedMatches = try fractional.matches(rounded)
        precondition(roundedMatches, "Native float rounding must not become a false ownership conflict")
        let moved = CursorSnapshot(name: fractional.name, width: 32, height: fractional.height,
            x: fractional.x + 0.1, y: fractional.y, frames: 2, duration: 0.4, images: sprite.images)
        let movedMatches = try fractional.matches(moved)
        precondition(!movedMatches, "A real hotspot change must still fail ownership checks")
        let nativeSlots = Set(native.cursors.flatMap(\.targetSlotNames))
        let nativeAPI = FakeSystemCursorAPI(snapshots: try nativeSlots.map { try first.snapshot(name: $0, longestSide: 32) })
        let nativePlan = try CursorPackPlan(cursors: native.cursors).replacements(using: nativeAPI, size: 32)
        precondition(nativePlan.roleCount == 2 && nativePlan.snapshots.count == nativeSlots.count,
                     "Disjoint native precision variants must not conflict")
        var invalidEntry = nativeEntry
        invalidEntry["HotSpotX"] = 99.0
        let invalidData = try PropertyListSerialization.data(fromPropertyList: ["Cursors": ["com.apple.coregraphics.Arrow": invalidEntry]], format: .binary, options: 0)
        do {
            _ = try CursorFileDecoder.decodeTheme(data: invalidData, fallbackName: "Bad")
            preconditionFailure("Out-of-bounds native hotspots must fail")
        } catch {}
        if let path = ProcessInfo.processInfo.environment["OCTAPUSS_NATIVE_THEME_PATH"] {
            let theme = try CursorFileDecoder.decodeTheme(url: URL(fileURLWithPath: path))
            precondition(theme.name == "Anya" && theme.cursors.count == 13)
            precondition(theme.cursors.filter { $0.animation != nil }.count == 6)
            precondition(theme.cursors.first { $0.effectiveRole == .arrow }?.animation?.frames.count == 5)
            precondition(theme.cursors.first { $0.effectiveRole == .text }?.animation?.frames.count == 12)
            let suite = "octapuss-native-theme-\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
            defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url) }
            let store = ProofStore(defaults: defaults, allowsSystemCustomization: false, libraryURL: url)
            store.importCursorFiles([URL(fileURLWithPath: path)])
            precondition(store.selectedCollection?.name == "Anya" && store.importedCursors.count == 13)
            let ids = Set(store.importedCursors.map(\.id))
            store.importCursorFiles([URL(fileURLWithPath: path)])
            precondition(store.importedCursors.count == 13 && Set(store.importedCursors.map(\.id)) == ids)
            let savedTheme = try CursorLibrary(url: url).load()
            precondition(savedTheme.count == 13)
            let slots = Set(theme.cursors.flatMap(\.targetSlotNames))
            let api = FakeSystemCursorAPI(snapshots: try slots.map { try first.snapshot(name: $0, longestSide: 32) })
            let plan = try CursorPackPlan(cursors: theme.cursors).replacements(using: api, size: 40)
            print("Anya theme checks passed: 13 entries, 6 animated, \(plan.roleCount) roles, \(plan.snapshots.count) slots, persistence and stable reimport.")
        }

        let names = ["01 Normal Select", "02 Help Select", "03 Working In Background", "04 Busy", "05 Precision Select",
                     "06 Text Select", "07 Handwriting", "08 Unavailable", "09 Vertical Resize", "10 Horizontal Resize",
                     "11 Diagonal Resize 1", "12 Diagonal Resize 2", "13 Move", "14 Alternate Select", "15 Link Select"]
        let cursors = try names.map { try CursorFileDecoder.decode(data: red, name: $0) }
        precondition(cursors.compactMap(\.effectiveRole).count == 15)
        precondition(CursorRole.infer(from: "minecraft diamond") == nil, "Unknown filenames must not guess a role")
        precondition(CursorRole.infer(from: "goku - normal") == .arrow)
        precondition(CursorRole.infer(from: "goku - text ") == .text)
        precondition(CursorRole.infer(from: "goku - horizontal") == .horizontalResize)
        precondition(CursorRole.infer(from: "goku - vertical") == .verticalResize)
        precondition(CursorRole.infer(from: "goku - d1") == .diagonalNWSE)
        precondition(CursorRole.infer(from: "goku - d2") == .diagonalNESW)
        precondition(CursorRole.infer(from: "normal goku") == nil)
        precondition(CursorRole.infer(from: "goku - normal artwork") == nil,
                     "Theme suffix detection must require a complete recognized role")
        let plan = CursorPackPlan(cursors: cursors)
        precondition(plan.mapped.count == 13 && plan.unmapped.count == 2)
        let slots = Set(plan.mapped.flatMap { $0.effectiveRole!.slotNames })
        let baseline = try slots.map { try first.snapshot(name: $0, longestSide: 32) }
        let api = FakeSystemCursorAPI(snapshots: baseline)
        let result = try plan.replacements(using: api, size: 32)
        precondition(result.roleCount == 13 && result.snapshots.count == slots.count)
        precondition(Set(result.snapshots.map(\.name)).count == result.snapshots.count)
        precondition(result.snapshots.last?.name.contains("Arrow") == true || result.snapshots.last?.name == "com.apple.cursor.0")
        precondition(CursorRole.working.slotNames == ["com.apple.cursor.4"])
        precondition(CursorRole.busy.slotNames == ["com.apple.coregraphics.Wait"])
        var duplicate = cursors[0]
        duplicate.id = UUID()
        do {
            _ = try CursorPackPlan(cursors: cursors + [duplicate]).replacements(using: api, size: 32)
            preconditionFailure("Duplicate role assignments must block application")
        } catch {}
        var reassigned = cursors[6]
        reassigned.roleOverride = CursorRole.openHand.rawValue
        precondition(reassigned.effectiveRole == .openHand)
        reassigned.roleOverride = "unassigned"
        precondition(reassigned.effectiveRole == nil)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("octapuss-pack-check-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let session = SystemCursorSession(api: api, journalURL: root.appendingPathComponent("journal.json"))
        try session.apply(result.snapshots, startWatchdog: false)
        try session.restore()
        try api.verifyAll(baseline)
        // Switching to a pack without Busy must restore the old pack's Busy
        // artwork rather than inherit it or choose an unrelated cursor.
        let noBusy = CursorPackPlan(cursors: [cursors[0], cursors[2]])
        let noBusyResult = try noBusy.replacements(using: api, size: 32)
        precondition(!noBusyResult.snapshots.contains { CursorRole.busy.slotNames.contains($0.name) })
        try session.apply(result.snapshots, startWatchdog: false)
        try session.prepareForApplication()
        try session.apply(noBusyResult.snapshots, startWatchdog: false)
        let busyBaseline = baseline.filter { CursorRole.busy.slotNames.contains($0.name) }
        try api.verifyAll(busyBaseline)
        try session.restore()
        try api.verifyAll(baseline)
        var excludedBusy = cursors[3]
        excludedBusy.roleOverride = "unassigned"
        let excluded = try CursorPackPlan(cursors: [cursors[0], excludedBusy]).replacements(using: api, size: 32)
        precondition(!excluded.snapshots.contains { CursorRole.busy.slotNames.contains($0.name) },
                     "An explicitly unassigned Busy cursor must remain excluded")
        print("Missing Busy checks passed: previous artwork restored, native baseline retained, manual exclusion honored.")
        api.failNextWriteFor = result.snapshots[result.snapshots.count / 2].name
        do {
            try session.apply(result.snapshots, startWatchdog: false)
            preconditionFailure("Partial pack failure must be reported")
        } catch {}
        try api.verifyAll(baseline)
        precondition(!session.hasPendingRecovery)

        if let folder = ProcessInfo.processInfo.environment["OCTAPUSS_PACK_FIXTURE_PATH"] {
            let files = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)
                .filter { ["cur", "ani"].contains($0.pathExtension.lowercased()) }
            let imported = try files.map { try CursorFileDecoder.decode(url: $0) }
            precondition(imported.count == 15 && CursorPackPlan(cursors: imported).mapped.count == 13)
            let busy = imported.first { $0.effectiveRole == .busy }!
            let working = imported.first { $0.effectiveRole == .working }!
            precondition(busy.animation?.frames.count == 24 && working.animation?.frames.count == 18)
            precondition(abs(busy.systemTimeline.duration - 0.1) < 0.000001)
            precondition(busy.systemTimeline.frames.count == 24 && working.systemTimeline.frames.count == 18)
            print("Minecraft pack decoded: 15 files, 13 native roles, background18/busy24 frames at100ms.")
        }
        if let folder = ProcessInfo.processInfo.environment["OCTAPUSS_GOKU_FIXTURE_PATH"] {
            let directory = URL(fileURLWithPath: folder)
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { ["cur", "ani"].contains($0.pathExtension.lowercased()) }
            let imported = try files.map { try CursorFileDecoder.decode(url: $0) }
            precondition(imported.count == 15 && imported.allSatisfy { $0.effectiveRole != nil })
            for cursor in imported.filter({ $0.effectiveRole == .busy || $0.effectiveRole == .working }) {
                for frame in cursor.animation!.frames {
                    let bitmap = NSBitmapImageRep(data: frame)!
                    let visible = (0..<bitmap.pixelsHigh).contains { y in
                        (0..<bitmap.pixelsWide).contains { x in bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.01 }
                    }
                    precondition(visible, "\(cursor.name) animation frames must contain visible pixels")
                }
                if let directory = ProcessInfo.processInfo.environment["OCTAPUSS_GOKU_FRAME_DIR"] {
                    let folder = URL(fileURLWithPath: directory)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try cursor.png.write(to: folder.appendingPathComponent("\(cursor.effectiveRole!.rawValue).png"))
                }
            }
            let plan = CursorPackPlan(cursors: imported)
            precondition(plan.mapped.count == 13 && plan.unmapped.count == 2)
            let slots = Set(plan.mapped.flatMap(\.targetSlotNames))
            let api = FakeSystemCursorAPI(snapshots: try slots.map { try first.snapshot(name: $0, longestSide: 32) })
            let result = try plan.replacements(using: api, size: 32)
            precondition(result.roleCount == 13)
            let suite = "octapuss-goku-\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            let libraryURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
            defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: libraryURL) }
            let store = ProofStore(defaults: defaults, allowsSystemCustomization: false, libraryURL: libraryURL)
            store.importCursorFolder(directory)
            precondition(store.selectedCollection?.cursors.count == 15 && store.selectedPackPlan.mapped.count == 13)
            let cursor = store.importedCursors.first { $0.effectiveRole == .text }!
            store.selectedImportedID = cursor.id
            store.assignSelectedRole(CursorRole.openHand.rawValue)
            let reopened = ProofStore(defaults: defaults, allowsSystemCustomization: false, libraryURL: libraryURL)
            precondition(reopened.selectedImportedCursor?.effectiveRole == .openHand,
                         "Manual roles must persist and override filename detection")
            reopened.assignSelectedRole("unassigned")
            precondition(reopened.selectedImportedCursor?.effectiveRole == nil)
            reopened.assignSelectedRole(CursorRole.text.rawValue)
            reopened.importCursorFolder(directory)
            precondition(reopened.importedCursors.first { $0.id == cursor.id }?.roleOverride == CursorRole.text.rawValue,
                         "Folder updates must preserve a manually selected role")
            print("Son Goku checks passed: 15 files, 13 system roles, \(result.snapshots.count) slots; manual assignment, exclusion, relaunch, and reimport.")
        }
        print("Pack checks passed: role matching, duplicate blocking, ANI order/rates/strips, role overrides, all-slot rollback and restoration.")
    }
}

private enum RegistrationProbe {
    struct Call {
        let connection: Int32
        let name: String
        let globally: Bool
        let instantly: Bool
        let size: CGSize
        let hotspot: CGPoint
        let frames: Int
        let duration: Double
        let imageCount: Int
    }
    static var calls: [Call] = []
    static var result: Int32 = 0
    static let register: SystemCursorAPI.Register = { connection, name, globally, instantly, size, hotspot, frames, duration, images, seed in
        calls.append(Call(connection: connection, name: String(cString: name), globally: globally,
                          instantly: instantly, size: size, hotspot: hotspot, frames: frames,
                          duration: duration, imageCount: CFArrayGetCount(images)))
        seed.pointee = 1
        return result
    }
}
