import Foundation

/// Native registry boundary. The application can use macOS access or an isolated fake.
protocol SystemCursorAccess {
    func read(_ name: String) throws -> CursorSnapshot
    func readMany(_ names: [String]) throws -> [CursorSnapshot]
    func readAvailable(_ names: [String]) throws -> [CursorSnapshot]
    func write(_ snapshot: CursorSnapshot) throws
}
