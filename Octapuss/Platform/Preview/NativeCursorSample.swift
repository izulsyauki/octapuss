import AppKit

enum NativeCursorSample: String, CaseIterable, Identifiable {
    case text, link, crosshair, openHand, closedHand, horizontalResize, verticalResize, unavailable
    var id: String { rawValue }
    var title: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .crosshair: "Precision"
        case .openHand: "Open hand"
        case .closedHand: "Grab"
        case .horizontalResize: "Resize sideways"
        case .verticalResize: "Resize up / down"
        case .unavailable: "Unavailable"
        }
    }
    var cursor: NSCursor {
        switch self {
        case .text: .iBeam
        case .link: .pointingHand
        case .crosshair: .crosshair
        case .openHand: .openHand
        case .closedHand: .closedHand
        case .horizontalResize: .resizeLeftRight
        case .verticalResize: .resizeUpDown
        case .unavailable: .operationNotAllowed
        }
    }
}
