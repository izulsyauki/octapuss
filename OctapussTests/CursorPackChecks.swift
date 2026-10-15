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
        let bitmap = NSBitmapImageRep(data: sprite.images[0])!
        precondition(bitmap.pixelsWide == 32 && bitmap.pixelsHigh == 64)
        precondition(bitmap.colorAt(x: 16, y: 16)!.usingColorSpace(.deviceRGB)!.blueComponent > 0.99,
                     "Native animation strip must put the first sequence frame at the top")
        precondition(bitmap.colorAt(x: 16, y: 48)!.usingColorSpace(.deviceRGB)!.redComponent > 0.99)

        let names = ["01 Normal Select", "02 Help Select", "03 Working In Background", "04 Busy", "05 Precision Select",
                     "06 Text Select", "07 Handwriting", "08 Unavailable", "09 Vertical Resize", "10 Horizontal Resize",
                     "11 Diagonal Resize 1", "12 Diagonal Resize 2", "13 Move", "14 Alternate Select", "15 Link Select"]
        let cursors = try names.map { try CursorFileDecoder.decode(data: red, name: $0) }
        precondition(cursors.compactMap(\.effectiveRole).count == 15)
        precondition(CursorRole.infer(from: "minecraft diamond") == nil, "Unknown filenames must not guess a role")
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
        print("Pack checks passed: role matching, duplicate blocking, ANI order/rates/strips, role overrides, all-slot rollback and restoration.")
    }
}
