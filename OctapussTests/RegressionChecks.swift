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
        let store = ProofStore(defaults: defaults)
        precondition(store.pack == .ink && store.pointerSize == .medium, "Invalid preferences must recover")
        store.pack = .blush
        store.pointerSize = .large
        store.darkPreview = true
        let reloaded = ProofStore(defaults: defaults)
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
        print("Regression checks completed: preferences, 9 cursor variants, 3 layout sizes, 20 clicks, repeated Restore, reset, and quit.")
    }
}
