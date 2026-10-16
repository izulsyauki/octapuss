import Foundation

extension CursorRole {
    var slotNames: [String] {
        let core: [String]
        let numbers: [Int]
        switch self {
        case .arrow: core = ["Arrow"]; numbers = [0]
        case .help: core = ["Help"]; numbers = [40]
        case .working: core = []; numbers = [4]
        case .busy: core = ["Wait"]; numbers = []
        case .precision: core = []; numbers = [7, 8, 20]
        case .text: core = ["IBeam", "IBeamXOR"]; numbers = [1]
        case .unavailable: core = ["NotAllowed"]; numbers = [3]
        case .verticalResize: core = ["ResizeUp", "ResizeDown", "ResizeUpDown", "WindowResizeNorth", "WindowResizeSouth", "WindowResizeNorthSouth"]; numbers = [21, 22, 23, 31, 32, 36]
        case .horizontalResize: core = ["ResizeLeft", "ResizeRight", "ResizeLeftRight", "WindowResizeEast", "WindowResizeWest", "WindowResizeEastWest"]; numbers = [17, 18, 19, 27, 28, 38]
        case .diagonalNWSE: core = ["WindowResizeNorthwest", "WindowResizeSoutheast", "WindowResizeNorthwestSoutheast"]; numbers = [33, 34, 35]
        case .diagonalNESW: core = ["WindowResizeNortheast", "WindowResizeSouthwest", "WindowResizeNortheastSouthwest"]; numbers = [29, 30, 37]
        case .move: core = ["Move"]; numbers = [39]
        case .link: core = ["PointingHand"]; numbers = [13]
        case .openHand: core = ["OpenHand"]; numbers = [12]
        case .closedHand: core = ["ClosedHand"]; numbers = [11]
        case .copy: core = ["Copy"]; numbers = [5]
        case .alias: core = ["Alias"]; numbers = [2]
        case .contextual: core = ["ArrowCtx"]; numbers = [24]
        case .zoomIn: core = ["ZoomIn"]; numbers = [42]
        case .zoomOut: core = ["ZoomOut"]; numbers = [43]
        case .cell: core = ["Cell"]; numbers = [41]
        case .verticalText: core = ["IBeamH"]; numbers = [26]
        case .handwriting, .alternate: return []
        }
        var result = core.map { "com.apple.coregraphics.\($0)" } + numbers.map { "com.apple.cursor.\($0)" }
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
            if self == .arrow { result.append("com.apple.coregraphics.ArrowS") }
            if self == .text { result.append("com.apple.coregraphics.IBeamS") }
        }
        return result
    }

    static func role(forNativeSlot slot: String) -> CursorRole? {
        if slot == "com.apple.coregraphics.ArrowS" { return .arrow }
        if slot == "com.apple.coregraphics.IBeamS" { return .text }
        return allCases.first { $0.slotNames.contains(slot) }
    }
}

extension ImportedCursor {
    var effectiveRole: CursorRole? {
        if roleOverride == "unassigned" { return nil }
        return roleOverride.flatMap(CursorRole.init(rawValue:))
            ?? nativeSlotNames?.first.flatMap(CursorRole.role(forNativeSlot:)) ?? CursorRole.infer(from: name)
    }
    var targetSlotNames: [String] {
        if roleOverride == nil, let nativeSlotNames { return nativeSlotNames }
        return effectiveRole?.slotNames ?? []
    }
}
