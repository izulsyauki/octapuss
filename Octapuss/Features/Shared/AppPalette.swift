import AppKit

enum AppPalette {
    static let ink = NSColor(srgbRed: 0.176, green: 0.141, blue: 0.251, alpha: 1)
    static let tide = NSColor(srgbRed: 0.247, green: 0.608, blue: 0.569, alpha: 1)
    static let blush = NSColor(srgbRed: 0.875, green: 0.424, blue: 0.573, alpha: 1)
    static let lavender = NSColor(srgbRed: 0.549, green: 0.420, blue: 0.847, alpha: 1)
    static let sunshine = NSColor(srgbRed: 0.957, green: 0.722, blue: 0.376, alpha: 1)
    static let pointerOutline = NSColor.white.withAlphaComponent(0.96)
    static let pointerDetail = NSColor.white.withAlphaComponent(0.8)
    static let previewLight = NSColor(srgbRed: 1, green: 0.973, blue: 0.914, alpha: 1)
    static let previewDark = NSColor(srgbRed: 0.102, green: 0.086, blue: 0.153, alpha: 1)
    static let surfaceLight = NSColor(srgbRed: 1, green: 0.992, blue: 0.973, alpha: 1)
    static let surfaceDark = NSColor(srgbRed: 0.145, green: 0.125, blue: 0.204, alpha: 1)
    static let backgroundLight = NSColor(srgbRed: 0.996, green: 0.961, blue: 0.906, alpha: 1)
    static let backgroundDark = previewDark

    static let background = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? backgroundDark
            : backgroundLight
    }

    static let surface = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? surfaceDark
            : surfaceLight
    }

    static let sidebar = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? surfaceDark
            : NSColor(srgbRed: 0.957, green: 0.929, blue: 0.969, alpha: 1)
    }

    static let secondaryText = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.714, green: 0.675, blue: 0.792, alpha: 1)
            : NSColor(srgbRed: 0.396, green: 0.337, blue: 0.435, alpha: 1)
    }
}
