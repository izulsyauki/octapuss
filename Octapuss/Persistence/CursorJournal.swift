import Foundation

struct CursorJournal: Codable {
    let sessionID: UUID?
    let original: [CursorSnapshot]
    let applied: [CursorSnapshot]
}
