import Foundation

enum PointerPack: String, CaseIterable, Identifiable {
    case ink
    case tide
    case blush

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var detail: String {
        switch self {
        case .ink: "Cozy night purple"
        case .tide: "Fresh lagoon mint"
        case .blush: "Berry-pink sparkle"
        }
    }
}
