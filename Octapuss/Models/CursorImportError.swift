import Foundation

enum CursorImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let reason): return reason }
    }
}

/// A normalized, local copy: no dependency on the original Downloads file.
