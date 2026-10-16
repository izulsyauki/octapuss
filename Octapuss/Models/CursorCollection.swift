import Foundation

struct CursorCollection: Identifiable {
    let id: UUID
    let name: String
    let cursors: [ImportedCursor]
}
