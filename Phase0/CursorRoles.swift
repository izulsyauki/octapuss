import Foundation

/// Windows role names are matched conservatively. Unknown files stay unassigned.
enum CursorRole: String, Codable, CaseIterable, Identifiable {
    case arrow, help, working, busy, precision, text, handwriting, unavailable
    case verticalResize, horizontalResize, diagonalNWSE, diagonalNESW, move, alternate, link
    case openHand, closedHand, copy, alias, contextual, zoomIn, zoomOut, cell, verticalText
    var id: String { rawValue }
    var title: String {
        switch self {
        case .arrow: "Normal select"
        case .help: "Help select"
        case .working: "Working in background"
        case .busy: "Busy / loading"
        case .precision: "Precision select"
        case .text: "Text select"
        case .handwriting: "Handwriting (no global slot)"
        case .unavailable: "Unavailable"
        case .verticalResize: "Vertical resize"
        case .horizontalResize: "Horizontal resize"
        case .diagonalNWSE: "Diagonal resize 1 (NW–SE)"
        case .diagonalNESW: "Diagonal resize 2 (NE–SW)"
        case .move: "Move"
        case .alternate: "Alternate select (no global slot)"
        case .link: "Link select"
        case .openHand: "Open hand"
        case .closedHand: "Grab / closed hand"
        case .copy: "Copy"
        case .alias: "Alias / shortcut"
        case .contextual: "Context menu"
        case .zoomIn: "Zoom in"
        case .zoomOut: "Zoom out"
        case .cell: "Cell select"
        case .verticalText: "Vertical text"
        }
    }

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

    static func infer(from filename: String) -> CursorRole? {
        let words = filename.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.drop(while: { $0.allSatisfy(\.isNumber) })
        let key = words.joined()
        let names: [(CursorRole, [String])] = [
            (.arrow, ["normalselect", "normal", "arrow", "default", "leftptr"]),
            (.help, ["helpselect", "help", "questionarrow"]),
            (.working, ["workinginbackground", "working", "appstarting", "progress", "leftptrwatch"]),
            (.busy, ["busy", "wait", "loading", "watch", "spinning"]),
            (.precision, ["precisionselect", "precision", "crosshair", "cross"]),
            (.text, ["textselect", "text", "ibeam", "xterm"]),
            (.handwriting, ["handwriting", "pen", "pencil"]),
            (.unavailable, ["unavailable", "notallowed", "forbidden", "no", "crossedcircle"]),
            (.verticalResize, ["verticalresize", "sizens", "nsresize", "resizeupdown"]),
            (.horizontalResize, ["horizontalresize", "sizewe", "ewresize", "resizeleftright"]),
            (.diagonalNWSE, ["diagonalresize1", "sizenwse", "nwseresize"]),
            (.diagonalNESW, ["diagonalresize2", "sizenesw", "neswresize"]),
            (.move, ["move", "sizeall", "fleur", "allscroll"]),
            (.alternate, ["alternateselect", "alternate", "uparrow"]),
            (.link, ["linkselect", "link", "hand", "pointinghand", "pointer", "hand2"]),
            (.openHand, ["openhand", "grab"]), (.closedHand, ["closedhand", "grabbing"]),
            (.copy, ["copy", "dragcopy"]), (.alias, ["alias", "shortcut"]),
            (.contextual, ["contextmenu", "contextual"]), (.zoomIn, ["zoomin"]),
            (.zoomOut, ["zoomout"]), (.cell, ["cell", "cellselect"]), (.verticalText, ["verticaltext"])
        ]
        return names.first { $0.1.contains(key) }?.0
    }
}

extension ImportedCursor {
    var effectiveRole: CursorRole? {
        if roleOverride == "unassigned" { return nil }
        return roleOverride.flatMap(CursorRole.init(rawValue:)) ?? CursorRole.infer(from: name)
    }
}

struct CursorPackPlan {
    let cursors: [ImportedCursor]
    var mapped: [ImportedCursor] { cursors.filter { !($0.effectiveRole?.slotNames.isEmpty ?? true) } }
    var unmapped: [ImportedCursor] { cursors.filter { $0.effectiveRole?.slotNames.isEmpty ?? true } }

    func replacements(using api: SystemCursorAccess, size: CGFloat) throws -> (snapshots: [CursorSnapshot], roleCount: Int, unavailable: [String]) {
        guard !mapped.isEmpty else { throw CursorImportError.invalid("No system roles are assigned. Choose a role for each cursor, then Apply pack.") }
        let groups = Dictionary(grouping: mapped, by: { $0.effectiveRole! })
        if let duplicate = groups.first(where: { $0.value.count > 1 }) {
            throw CursorImportError.invalid("Two cursors use \(duplicate.key.title). Assign distinct roles before applying this pack.")
        }
        let requested = Set(mapped.flatMap { $0.effectiveRole!.slotNames }).sorted()
        let available = Set(try api.readAvailable(requested).map(\.name))
        var snapshots: [CursorSnapshot] = []
        var unavailable: [String] = []
        var roles = 0
        var owners: [String: UUID] = [:]
        // Apply the normal arrow last so a non-arrow registration doesn't remain displayed.
        for cursor in mapped.sorted(by: { ($0.effectiveRole == .arrow ? 1 : 0) < ($1.effectiveRole == .arrow ? 1 : 0) }) {
            let names = cursor.effectiveRole!.slotNames.filter { available.contains($0) }
            if names.isEmpty { unavailable.append(cursor.effectiveRole!.title); continue }
            roles += 1
            for name in names {
                if owners[name] != nil {
                    throw CursorImportError.invalid("Two assigned roles share the macOS slot \(name). Unassign one before applying.")
                }
                owners[name] = cursor.id
                snapshots.append(try cursor.snapshot(name: name, longestSide: size))
            }
        }
        guard !snapshots.isEmpty else { throw CursorImportError.invalid("No mapped cursor slots are available in this macOS session. Nothing was applied.") }
        return (snapshots, roles, unavailable)
    }
}
