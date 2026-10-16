import Foundation

/// Conservative filename matching; unknown files stay unassigned.
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
            (.verticalResize, ["verticalresize", "vertical", "sizens", "nsresize", "resizeupdown"]),
            (.horizontalResize, ["horizontalresize", "horizontal", "sizewe", "ewresize", "resizeleftright"]),
            (.diagonalNWSE, ["diagonalresize1", "d1", "sizenwse", "nwseresize"]),
            (.diagonalNESW, ["diagonalresize2", "d2", "sizenesw", "neswresize"]),
            (.move, ["move", "sizeall", "fleur", "allscroll"]),
            (.alternate, ["alternateselect", "alternate", "uparrow"]),
            (.link, ["linkselect", "link", "hand", "pointinghand", "pointer", "hand2"]),
            (.openHand, ["openhand", "grab"]), (.closedHand, ["closedhand", "grabbing"]),
            (.copy, ["copy", "dragcopy"]), (.alias, ["alias", "shortcut"]),
            (.contextual, ["contextmenu", "contextual"]), (.zoomIn, ["zoomin"]),
            (.zoomOut, ["zoomout"]), (.cell, ["cell", "cellselect"]), (.verticalText, ["verticaltext"])
        ]
        if let exact = names.first(where: { $0.1.contains(key) }) { return exact.0 }
        // Theme prefixes are common in downloads ("goku - normal"). Only
        // recognize an exact role after a spaced separator, never arbitrary words.
        let sections = filename.components(separatedBy: " - ")
        guard sections.count > 1, let suffix = sections.last else { return nil }
        let suffixKey = suffix.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined()
        return names.first { $0.1.contains(suffixKey) }?.0
    }
}
