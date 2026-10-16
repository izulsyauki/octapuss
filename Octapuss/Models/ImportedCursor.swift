import Foundation

struct ImportedCursor: Codable, Identifiable {
    var id: UUID
    let name: String
    let png: Data
    let width: Int
    let height: Int
    let hotspotX: Int
    let hotspotY: Int
    let firstFrameOnly: Bool
    var collectionID: UUID? = nil
    var collectionName: String? = nil
    var roleOverride: String? = nil
    var animation: CursorAnimation? = nil
    var animationDecoded: Bool? = nil
    var nativeSlotNames: [String]? = nil

    var setID: UUID { collectionID ?? id }
    var needsAnimationUpgrade: Bool { firstFrameOnly && animationDecoded != true }
}
