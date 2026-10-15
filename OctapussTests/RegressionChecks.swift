import AppKit
import SwiftUI

/// Runs against the same source as the app, with isolated preferences and real native views.
@main
struct RegressionChecks {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let suite = "dev.octapuss.regression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("missing-pack", forKey: "selectedPack")
        defaults.set("missing-size", forKey: "pointerSize")
        let store = ProofStore(defaults: defaults, allowsSystemCustomization: false)
        defaults.set(["red": 1, "green": 1, "blue": 1, "alpha": 1], forKey: "cursorOutline")
        defaults.set(["red": 0, "green": 0, "blue": 0, "alpha": 1], forKey: "cursorFill")
        precondition(!PointerColorCompatibility.hasOverride(in: defaults))
        defaults.set(["red": 0, "green": 1, "blue": 0.9, "alpha": 1], forKey: "cursorOutline")
        precondition(PointerColorCompatibility.hasOverride(in: defaults))
        defaults.set(["red": "0", "green": "1", "blue": "0.9", "alpha": "1"], forKey: "cursorOutline")
        precondition(PointerColorCompatibility.hasOverride(in: defaults))
        precondition(store.pack == .ink && store.pointerSize == .medium, "Invalid preferences must recover")
        store.pack = .blush
        store.pointerSize = .large
        store.darkPreview = true
        let reloaded = ProofStore(defaults: defaults, allowsSystemCustomization: false)
        precondition(reloaded.pack == .blush && reloaded.pointerSize == .large && reloaded.darkPreview,
                     "Appearance preferences must survive reopening")

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 225),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let view = CursorPreviewNSView(frame: NSRect(x: 0, y: 0, width: 480, height: 225))
        window.contentView = view
        view.onClick = { store.recordClick() }
        for pack in PointerPack.allCases {
            for size in PointerSize.allCases {
                let cursor = PointerArtwork.cursor(pack: pack, size: size.points)
                precondition(cursor.image.size == NSSize(width: size.points, height: size.points))
                precondition(cursor.hotSpot == NSPoint(x: size.points / 16, y: size.points / 16),
                             "Hotspot must scale with the arrow apex")
                view.configure(pack: pack, size: size, dark: true, enabled: true, clicks: 0)
                precondition(view.pack == pack && view.pointerSize == size)
            }
        }
        for width: CGFloat in [480, 560, 760] {
            view.setFrameSize(NSSize(width: width, height: 225))
            view.layoutSubtreeIfNeeded()
            let button = view.sampleButton
            precondition(view.bounds.contains(button.frame), "Click target must fit after resizing")
            let point = NSPoint(x: button.frame.midX, y: button.frame.midY)
            let hit = view.hitTest(view.convert(point, to: view.superview))
            precondition(hit === button || hit?.isDescendant(of: button) == true,
                         "Preview must not intercept the native button")
        }
        for _ in 0..<20 { view.sampleButton.performClick(nil) }
        precondition(store.clickCount == 20, "Every Boop must register exactly once")
        for _ in 0..<20 { store.restore() }
        precondition(!store.previewEnabled, "Restore must disable the actual app-local cursor")
        store.pack = .tide
        precondition(!store.previewEnabled, "Changing a preset must not undo Restore")
        store.resumePreview()
        precondition(store.previewEnabled)
        store.restore()
        store.resetPreferences()
        precondition(store.pack == .ink && store.pointerSize == .medium && !store.darkPreview)
        precondition(store.clickCount == 0 && !store.previewEnabled, "Reset must preserve paused state")
        precondition(store.prepareToQuit() && !store.previewEnabled)
        view.onClick = nil
        checkSystemTransactions()
        do { try CursorImportChecks.run() }
        catch { preconditionFailure(error.localizedDescription) }
        do { try CursorPackChecks.run() }
        catch { preconditionFailure(error.localizedDescription) }
        print("Regression checks completed: preferences, 9 cursor variants, 3 layout sizes, 20 clicks, repeated Restore, reset, and quit.")
    }

    @MainActor
    static func checkSystemTransactions() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("octapuss-check-\(UUID().uuidString)/session.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        func snapshot(_ name: String, _ pack: PointerPack) -> CursorSnapshot {
            let image = PointerArtwork.pointerImage(pack: pack, size: 32)
            let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
            return CursorSnapshot(name: name, width: 32, height: 32, x: 2, y: 2,
                                  frames: 1, duration: 0, images: [png])
        }
        let original = [snapshot("arrow", .ink), snapshot("arrowS", .ink)]
        let applied = [snapshot("arrow", .tide), snapshot("arrowS", .tide)]
        let api = FakeSystemCursorAPI(snapshots: original)
        let session = SystemCursorSession(api: api, journalURL: url)
        do {
            try session.apply(applied, startWatchdog: false)
            precondition(session.hasPendingRecovery)
            let retiredID = try JSONDecoder().decode(CursorJournal.self, from: Data(contentsOf: url)).sessionID!
            try session.restore()
            try session.restore()
            precondition(!session.hasPendingRecovery)
            let restoredInitially = try api.read("arrow").matches(original[0])
            precondition(restoredInitially)

            try session.apply(applied, startWatchdog: false)
            try SystemCursorSession.restoreOwnedJournal(at: url, sessionID: retiredID, using: api)
            precondition(session.hasPendingRecovery, "Retired watchdog must leave the new journal intact")
            let newSessionUnchanged = try api.read("arrow").matches(applied[0])
            precondition(newSessionUnchanged, "Retired watchdog must not revert a newer theme")
            try session.restore()

            api.failNextWriteFor = "arrowS"
            do {
                try session.apply(applied, startWatchdog: false)
                preconditionFailure("Partial registration must report failure")
            } catch {}
            precondition(!session.hasPendingRecovery, "Failed apply must restore the first written slot")
            let rolledBack = try api.read("arrow").matches(original[0])
            precondition(rolledBack)

            try session.apply(applied, startWatchdog: false)
            api.snapshots["arrow"] = snapshot("arrow", .blush)
            api.failNextWriteFor = "arrowS"
            do {
                try session.prepareForApplication()
                preconditionFailure("A real restoration failure must block reapplication")
            } catch {}
            precondition(session.hasPendingRecovery, "Write failures must retain the active recovery journal")
            do {
                try session.restore()
                preconditionFailure("Must not overwrite another utility's cursor")
            } catch {}
            precondition(session.hasPendingRecovery, "Ownership conflict must retain the baseline")
            let otherSlotRestored = try api.read("arrowS").matches(original[1])
            precondition(otherSlotRestored, "A conflict must not prevent restoring other owned slots")
            let external = api.snapshots["arrow"]!
            try session.prepareForApplication()
            precondition(!session.hasPendingRecovery, "Explicit Apply must clear a stale ownership conflict")
            let externalPreserved = try api.read("arrow").matches(external)
            precondition(externalPreserved, "Preparing Apply must preserve the externally changed cursor")
            let backups = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("system-arrow-backup-") }
            precondition(backups.count == 1, "The conflicting backup must be archived")
            try session.apply(applied, startWatchdog: false)
            try session.restore()
            let newBaselineRestored = try api.read("arrow").matches(external)
            precondition(newBaselineRestored, "Restore must use the new system baseline after Reset Colors")
            precondition(!session.hasPendingRecovery)
            print("System transaction checks completed: baseline recovery, partial rollback, idempotent Restore, ownership conflict.")
        } catch { preconditionFailure(error.localizedDescription) }
    }
}

final class FakeSystemCursorAPI: SystemCursorAccess {
    var snapshots: [String: CursorSnapshot]
    var failNextWriteFor: String?
    init(snapshots: [CursorSnapshot]) {
        self.snapshots = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.name, $0) })
    }
    func read(_ name: String) throws -> CursorSnapshot {
        guard let snapshot = snapshots[name] else { throw CursorSystemError.invalidBaseline }
        return snapshot
    }
    func write(_ snapshot: CursorSnapshot) throws {
        if failNextWriteFor == snapshot.name {
            failNextWriteFor = nil
            throw CursorSystemError.call("Injected failure", -1)
        }
        snapshots[snapshot.name] = snapshot
    }
}
