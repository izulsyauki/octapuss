import AppKit
import SwiftUI

/// Render only Octapuss-owned views, offscreen; never captures the desktop or other apps.
@main
struct LibraryRenderChecks {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["OCTAPUSS_RENDER_DIR"] ?? "/tmp/octapuss-library-review")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "octapuss-render-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let libraryURL = root.appendingPathComponent("test-library.json")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let store = AppStore(defaults: defaults, allowsSystemCustomization: false, libraryURL: libraryURL)
        let packPath = ProcessInfo.processInfo.environment["OCTAPUSS_RENDER_PACK_PATH"] ?? "/tmp/octapuss-import-fixtures"
        let packURL = URL(fileURLWithPath: packPath)
        if packURL.pathExtension.lowercased() == "cursor" { store.importCursorFiles([packURL]) }
        else { store.importCursorFolder(packURL) }
        let importedID = store.selectedImportedID
        guard let collection = store.selectedCollection, !collection.cursors.isEmpty else {
            throw CursorImportError.invalid("Generate the three synthetic fixtures with OCTAPUSS_IMPORT_FIXTURE_DIR=/tmp/octapuss-import-fixtures and --check first.")
        }
        let collectionID = collection.id
        for state in ["builtin", "imported", "deleted"] {
            if state == "imported" { store.selectedImportedID = importedID }
            else if state == "deleted" { store.deleteCursorPack(id: collectionID) }
            else { store.pack = .blush }
            for dark in [false, true] {
                for (name, size) in [("default", NSSize(width: 1080, height: 760)), ("minimum", NSSize(width: 900, height: 640))] {
                    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [], backing: .buffered, defer: false)
                    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                    let view = NSHostingView(rootView: CursorLibraryView().environmentObject(store))
                    window.contentView = view
                    window.setContentSize(size)
                    view.frame = NSRect(origin: .zero, size: size)
                    view.layoutSubtreeIfNeeded()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.15))
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                        throw CursorImportError.invalid("Offscreen rendering unavailable.")
                    }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else {
                        throw CursorImportError.invalid("PNG render unavailable.")
                    }
                    let filename = "\(state)-\(dark ? "dark" : "light")-\(name).png"
                    try png.write(to: root.appendingPathComponent(filename))
                    print(root.appendingPathComponent(filename).path)
                    window.contentView = nil
                }
            }
        }
    }
}
