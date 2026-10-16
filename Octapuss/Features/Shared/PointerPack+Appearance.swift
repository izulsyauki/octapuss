import AppKit

extension PointerPack {
    var color: NSColor {
        switch self {
        case .ink: AppPalette.ink
        case .tide: AppPalette.tide
        case .blush: AppPalette.blush
        }
    }
}
