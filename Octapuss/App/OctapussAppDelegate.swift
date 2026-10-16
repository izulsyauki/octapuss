import AppKit
import Combine
import CoreServices

@MainActor
final class OctapussAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: AppStore? {
        didSet { observeCursorLifecycle() }
    }
    private var lifecycleObservers = Set<AnyCancellable>()
    private var explicitQuitRequested = false
    private var pendingTermination = false

    func keepRunningInMenuBar() {
        for window in NSApplication.shared.windows { window.orderOut(nil) }
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func showMainWindow() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        if let window = app.windows.first(where: { $0.title == "Octapuss" }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
        app.activate(ignoringOtherApps: true)
    }

    func quitFromMenuBar() {
        explicitQuitRequested = true
        NSApplication.shared.terminate(nil)
        // A failed cursor restoration cancels Quit, allowing a later retry.
        explicitQuitRequested = false
    }

    static func isSystemTermination(_ event: NSAppleEventDescriptor?) -> Bool {
        let keyword = AEKeyword(kAEQuitReason)
        guard let reason = (event?.attributeDescriptor(forKeyword: keyword)
                            ?? event?.paramDescriptor(forKeyword: keyword))?.enumCodeValue else {
            return false
        }
        return [kAEQuitAll, kAEShutDown, kAERestart, kAEReallyLogOut, kAELogOut]
            .contains { reason == OSType($0) }
    }

    private func observeCursorLifecycle() {
        guard let store, lifecycleObservers.isEmpty else { return }
        store.applyingPublisher.dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] applying in
                guard !applying, let self, self.pendingTermination, let store = self.store else { return }
                self.pendingTermination = false
                let restored = store.prepareToQuit()
                if !restored { self.showMainWindow() }
                NSApplication.shared.reply(toApplicationShouldTerminate: restored)
            }.store(in: &lifecycleObservers)
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let events: [(NotificationCenter, Notification.Name, CursorContinuation.Suspension, Bool)] = [
            (workspace, NSWorkspace.willSleepNotification, .sleep, false),
            (workspace, NSWorkspace.didWakeNotification, .sleep, true),
            (workspace, NSWorkspace.sessionDidResignActiveNotification, .session, false),
            (workspace, NSWorkspace.sessionDidBecomeActiveNotification, .session, true),
            (distributed, Notification.Name("com.apple.screenIsLocked"), .lock, false),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), .lock, true)
        ]
        for (center, name, reason, returning) in events {
            center.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] _ in
                if returning { self?.store?.resumeSystemCursor(after: reason) }
                else { self?.store?.suspendSystemCursor(for: reason) }
            }.store(in: &lifecycleObservers)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Octapuss" }) else {
                return
            }
            window.minSize = NSSize(width: 900, height: 640)
            window.setContentSize(NSSize(width: 1080, height: 760))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminationReply(for: NSAppleEventManager.shared().currentAppleEvent,
                         explicitlyRequested: explicitQuitRequested)
    }

    func terminationReply(for event: NSAppleEventDescriptor?, explicitlyRequested: Bool) -> NSApplication.TerminateReply {
        guard explicitlyRequested || Self.isSystemTermination(event) else {
            keepRunningInMenuBar()
            return .terminateCancel
        }
        guard let store else { return .terminateNow }
        if store.isApplying {
            pendingTermination = true
            store.restore()
            return .terminateLater
        }
        guard store.prepareToQuit() else {
            showMainWindow()
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }
}
