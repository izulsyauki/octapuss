import Foundation

enum ApplicationPaths {
    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Octapuss")
    }

    static var cursorLibrary: URL { supportDirectory.appendingPathComponent("imported-cursors.json") }
    static var cursorJournal: URL { supportDirectory.appendingPathComponent("system-arrow-session.json") }
}
