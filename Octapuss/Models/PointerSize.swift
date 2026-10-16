import Foundation

enum PointerSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var points: CGFloat {
        switch self {
        case .small: 24
        case .medium: 32
        case .large: 40
        }
    }
}
