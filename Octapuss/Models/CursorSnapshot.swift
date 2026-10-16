import Foundation

struct CursorSnapshot: Codable {
    let name: String
    let width: Double
    let height: Double
    let x: Double
    let y: Double
    let frames: Int
    let duration: Double
    let images: [Data]
}
