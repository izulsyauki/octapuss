import Foundation

/// Application code depends on storage behavior, not the JSON file implementation.
protocol CursorLibraryStorage {
    func load() throws -> [ImportedCursor]
    func save(_ cursors: [ImportedCursor]) throws
}
