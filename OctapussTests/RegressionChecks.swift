import AppKit
import CoreServices
import SwiftUI

/// Runs against the same source as the app, with isolated preferences and real native views.
@main
struct RegressionChecks {
    @MainActor
    static func main() async {
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
        checkPreviewAnimationLifecycle()
        checkPreviewCursorBoundary()
        view.onClick = nil
        checkSystemTransactions()
        do { try CursorImportChecks.run() }
        catch { preconditionFailure(error.localizedDescription) }
        do { try CursorPackChecks.run() }
        catch { preconditionFailure(error.localizedDescription) }
        await checkApplyBusyLifecycle()
        checkMenuBarLifecycle(store: store)
        print("Regression checks completed: preferences, 9 cursor variants, 3 layout sizes, 20 clicks, repeated Restore, reset, and quit.")
    }

    @MainActor
    static func checkApplyBusyLifecycle() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("octapuss-busy-\(UUID())")
        let suite = "octapuss-busy-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        do {
            let image = PointerArtwork.pointerImage(pack: .ink, size: 32)
            let png = NSBitmapImageRep(cgImage: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
                .representation(using: .png, properties: [:])!
            let setID = UUID()
            let arrow = ImportedCursor(id: UUID(), name: "Normal", png: png, width: 32, height: 32,
                hotspotX: 2, hotspotY: 2, firstFrameOnly: false, collectionID: setID, collectionName: "Busy test",
                roleOverride: CursorRole.arrow.rawValue)
            var busy = arrow
            busy.id = UUID()
            busy.roleOverride = CursorRole.busy.rawValue
            busy.animation = CursorAnimation(frames: [png, png], durations: [0.1, 0.1])
            let libraryURL = root.appendingPathComponent("library.json")
            try CursorLibrary(url: libraryURL).save([arrow, busy])
            defaults.set(arrow.id.uuidString, forKey: "selectedImportedCursor")
            let names = CursorRole.arrow.slotNames + CursorRole.busy.slotNames
            let baseline = try names.map { try arrow.snapshot(name: $0, longestSide: 24) }
            let api = BlockingCursorAPI(snapshots: baseline)
            let journal = root.appendingPathComponent("session.json")
            let store = ProofStore(defaults: defaults, allowsSystemCustomization: false, libraryURL: libraryURL,
                                   systemAccess: api, systemJournalURL: journal)
            func waitFor(_ condition: () -> Bool) async {
                let deadline = Date().addingTimeInterval(8)
                while Date() < deadline {
                    if condition() { return }
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
                preconditionFailure("Async cursor operation timed out")
            }
            store.applySystemArrow()
            precondition(store.isApplying && store.applyingCursor?.id == busy.id)
            precondition(store.statusTitle == "Applying Busy test…")
            await waitFor { api.entered.wait(timeout: .now()) == .success }
            // Main-actor continuations still execute while native registration is blocked.
            precondition(store.isApplying && !store.systemApplied)
            store.applySystemArrow() // Duplicate input must not queue another operation.
            api.proceed.signal()
            await waitFor { !store.isApplying }
            precondition(store.systemApplied && store.applyingCursor == nil)

            api.blockNextWrite = true
            store.applySystemArrow()
            await waitFor { api.entered.wait(timeout: .now()) == .success }
            store.restore()
            precondition(store.isApplying && store.statusTitle == "Restoring pointer…")
            api.proceed.signal()
            await waitFor { !store.isApplying }
            precondition(!store.systemApplied && !store.previewEnabled && !store.systemNeedsRecovery)
            precondition(!FileManager.default.fileExists(atPath: journal.path))
            try api.base.verifyAll(baseline)

            api.base.failNextWriteFor = names[0]
            store.applySystemArrow()
            await waitFor { !store.isApplying }
            precondition(!store.systemApplied && !store.systemNeedsRecovery && store.applyingCursor == nil)
            try api.base.verifyAll(baseline)

            api.blockNextWrite = true
            store.applySystemArrow()
            await waitFor { api.entered.wait(timeout: .now()) == .success }
            precondition(!store.prepareToQuit(), "Quit must wait for in-flight Apply cleanup")
            api.proceed.signal()
            await waitFor { !store.isApplying }
            precondition(store.prepareToQuit() && !store.systemApplied)
            try api.base.verifyAll(baseline)
            api.blockNextWrite = true
            store.applySystemArrow()
            await waitFor { api.entered.wait(timeout: .now()) == .success }
            store.suspendSystemCursor(for: .lock)
            store.resumeSystemCursor(after: .lock)
            api.proceed.signal()
            await waitFor { !store.isApplying }
            try? await Task.sleep(nanoseconds: 800_000_000)
            precondition(!store.systemApplied && !FileManager.default.fileExists(atPath: journal.path),
                         "An interrupted Apply must not reactivate after unlock")
            try api.base.verifyAll(baseline)
            print("Apply busy checks passed: artwork, main-actor responsiveness, duplicate guard, cancel, error, Quit, lock interruption, and no late activation.")
        } catch { preconditionFailure(error.localizedDescription) }
    }

    @MainActor
    static func checkPreviewCursorBoundary() {
        let window = AnimationCheckWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 300),
                                          styleMask: [.titled], backing: .buffered, defer: false)
        let view = CursorPreviewNSView(frame: NSRect(x: 0, y: 0, width: 300, height: 225))
        window.contentView!.addSubview(view)
        window.testMouseLocation = view.convert(NSPoint(x: 40, y: 40), to: nil)
        let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, subtype: 0, data1: 0, data2: 0)!
        defer { NSCursor.arrow.set() }
        view.configure(pack: .blush, size: .medium, dark: false, enabled: true, clicks: 0)
        view.updateTrackingAreas()
        precondition(view.trackingAreas.contains { $0.options.contains(.mouseEnteredAndExited) })
        precondition(view.trackingAreas.allSatisfy { view.bounds.contains($0.rect) && !$0.options.contains(.inVisibleRect) },
                     "Cursor tracking must not expand beyond the playground bounds")
        view.cursorUpdate(with: event)
        let preview = NSCursor.current
        precondition(preview !== NSCursor.arrow)
        window.testMouseLocation = NSPoint(x: 500, y: 40)
        view.mouseExited(with: event)
        precondition(NSCursor.current === NSCursor.arrow, "Leaving the playground must release its cursor")
        view.cursorUpdate(with: event)
        view.configure(pack: .tide, size: .large, dark: false, enabled: true, clicks: 0)
        precondition(NSCursor.current === NSCursor.arrow, "Late updates must not reclaim the sidebar cursor")
        NSCursor.iBeam.set()
        view.mouseExited(with: event)
        precondition(NSCursor.current === NSCursor.iBeam, "Exit must preserve another control's cursor")
        window.testMouseLocation = view.convert(NSPoint(x: 40, y: 40), to: nil)
        view.cursorUpdate(with: event)
        view.isHidden = true
        precondition(NSCursor.current === NSCursor.arrow, "Hiding the playground must release its cursor")
        view.isHidden = false
        view.cursorUpdate(with: event)
        view.removeFromSuperview()
        precondition(NSCursor.current === NSCursor.arrow, "Removing the playground must release its cursor")
        window.contentView!.addSubview(view)
        view.cursorUpdate(with: event)
        let owned = NSCursor.current
        window.testMouseLocation = NSPoint(x: -100, y: -100)
        view.mouseExited(with: event)
        precondition(NSCursor.current === owned, "Exit must not force a cursor into another app")
        window.testMouseLocation = view.convert(NSPoint(x: 40, y: 40), to: nil)
        window.testKey = false
        NSCursor.iBeam.set()
        view.cursorUpdate(with: event)
        precondition(NSCursor.current === NSCursor.iBeam, "An inactive preview cannot claim the cursor")
        print("Preview boundary checks passed: exit, late updates, text cursor, hide, detach, outside-window and inactive ownership.")
    }

    @MainActor
    static func checkPreviewAnimationLifecycle() {
        let window = AnimationCheckWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 225),
                                          styleMask: [.titled], backing: .buffered, defer: false)
        let view = CursorPreviewNSView(frame: window.contentView!.bounds)
        window.contentView = view
        let image = PointerArtwork.pointerImage(pack: .ink, size: 32)
        let bitmap = NSBitmapImageRep(cgImage: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
        let png = bitmap.representation(using: .png, properties: [:])!
        let cursor = ImportedCursor(id: UUID(), name: "Animated test", png: png, width: 32, height: 32,
                                    hotspotX: 2, hotspotY: 2, firstFrameOnly: false,
                                    animation: CursorAnimation(frames: [png, png], durations: [0.1, 0.1]))
        view.configure(pack: .ink, size: .medium, dark: false, enabled: true, clicks: 0, imported: cursor)
        let motionAllowed = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        precondition(view.isAnimationRunning == motionAllowed)
        window.testKey = false
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
        precondition(!view.isAnimationRunning, "Inactive previews must stop their timer")
        window.testKey = true
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        precondition(view.isAnimationRunning == motionAllowed)
        view.isHidden = true
        precondition(!view.isAnimationRunning, "Hidden previews must stop their timer")
        view.isHidden = false
        precondition(view.isAnimationRunning == motionAllowed)
        window.testVisible = false
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        precondition(!view.isAnimationRunning, "Occluded previews must stop their timer")
        window.testVisible = true
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        precondition(view.isAnimationRunning == motionAllowed)
        view.configure(pack: .ink, size: .medium, dark: false, enabled: false, clicks: 0, imported: cursor)
        precondition(!view.isAnimationRunning, "Restore must stop preview animation")
        window.contentView = nil
        precondition(!view.isAnimationRunning, "Detached previews must stop their timer")
        print("Preview animation checks passed: inactive, hidden, occluded, Restore, detach, and resume.")
    }

    @MainActor
    static func checkMenuBarLifecycle(store: ProofStore) {
        let delegate = ProofAppDelegate()
        delegate.store = store
        let app = NSApplication.shared
        store.resumePreview()
        precondition(delegate.terminationReply(for: nil, explicitlyRequested: false) == .terminateCancel)
        precondition(store.previewEnabled, "Dock Quit must keep the cursor session running")
        precondition(!delegate.applicationShouldTerminateAfterLastWindowClosed(app))
        precondition(delegate.terminationReply(for: nil, explicitlyRequested: true) == .terminateNow)
        precondition(!store.previewEnabled, "Menu-bar Quit must run cursor restoration")

        for reason in [kAEQuitAll, kAEShutDown, kAERestart, kAEReallyLogOut, kAELogOut] {
            let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass),
                eventID: AEEventID(kAEQuitApplication), targetDescriptor: nil,
                returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
            event.setAttribute(NSAppleEventDescriptor(enumCode: OSType(reason)), forKeyword: AEKeyword(kAEQuitReason))
            store.resumePreview()
            precondition(delegate.terminationReply(for: event, explicitlyRequested: false) == .terminateNow,
                         "System logout/shutdown must not be intercepted as Dock Quit")
            precondition(!store.previewEnabled, "System termination must restore the cursor")
        }
        print("Menu-bar lifecycle checks passed: Dock Quit retains preview, last-window close keeps running, explicit/system Quit restores cursor.")
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
            let cycleStart = Date()
            for _ in 0..<100 {
                try session.apply(applied, startWatchdog: false)
                try session.restore()
                precondition(!session.hasPendingRecovery)
                try api.verifyAll([external, original[1]])
            }
            print("100 fake Apply/Restore cycles passed in \(String(format: "%.2f", Date().timeIntervalSince(cycleStart))) seconds; baseline and journal cleanup verified each cycle.")
            var continuation = CursorContinuation()
            continuation.applied(applied)
            try session.apply(applied, startWatchdog: false)
            precondition(continuation.suspend(.lock))
            try session.restore()
            precondition(!continuation.suspend(.sleep), "Overlapping suspension must restore only once")
            precondition(!continuation.suspend(.session))
            continuation.returned(.sleep)
            continuation.returned(.session)
            precondition(!continuation.canResume, "Wake must not resume while still locked")
            continuation.returned(.lock)
            precondition(continuation.canResume)
            precondition(try! continuation.snapshots[0].matches(applied[0]), "Resume must preserve applied artwork")
            try session.apply(continuation.snapshots, startWatchdog: false)
            continuation.didResume()
            precondition(!continuation.canResume, "Repeated return notifications must not reapply")
            precondition(continuation.suspend(.sleep))
            try session.restore()
            continuation.cancel()
            continuation.returned(.sleep)
            precondition(!continuation.canResume && continuation.snapshots.isEmpty,
                         "Manual Restore during suspension must cancel pending reapplication")
            continuation.applied(applied)
            precondition(continuation.suspend(.session))
            continuation.returned(.session)
            precondition(continuation.canResume, "Session return without sleep must resume")
            continuation.cancel()
            precondition(!continuation.suspend(.lock), "Lock after manual Restore must remain off")
            continuation.returned(.lock)
            precondition(!continuation.canResume)
            print("Cursor continuation checks passed: overlapping lock/sleep/session, exact artwork, duplicate returns, manual cancellation.")
            print("System transaction checks completed: baseline recovery, partial rollback, idempotent Restore, ownership conflict.")
        } catch { preconditionFailure(error.localizedDescription) }
    }
}

@MainActor
final class AnimationCheckWindow: NSWindow {
    var testKey = true
    var testVisible = true
    var testMouseLocation = NSPoint(x: -100, y: -100)
    override var mouseLocationOutsideOfEventStream: NSPoint { testMouseLocation }
    override var isKeyWindow: Bool { testKey }
    override var isVisible: Bool { testVisible }
    override var occlusionState: NSWindow.OcclusionState { testVisible ? [.visible] : [] }
}

final class BlockingCursorAPI: SystemCursorAccess {
    let base: FakeSystemCursorAPI
    let entered = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)
    var blockNextWrite = true
    init(snapshots: [CursorSnapshot]) { base = FakeSystemCursorAPI(snapshots: snapshots) }
    func read(_ name: String) throws -> CursorSnapshot { try base.read(name) }
    func write(_ snapshot: CursorSnapshot) throws {
        if blockNextWrite {
            blockNextWrite = false
            entered.signal()
            guard proceed.wait(timeout: .now() + 8) == .success else {
                throw CursorSystemError.call("Test registration barrier", -1)
            }
        }
        try base.write(snapshot)
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
