import Foundation

enum CursorSystemError: LocalizedError {
    case unavailable(String)
    case call(String, Int32)
    case invalidBaseline
    case ownershipChanged(String)
    case pendingRecovery
    case watchdogUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailable(let name): "System customization is unavailable: \(name) is missing."
        case .call(let action, let code): "\(action) failed (macOS code \(code))."
        case .invalidBaseline: "The existing system cursor could not be backed up safely."
        case .ownershipChanged(let name): "Another cursor change was detected for \(name). Octapuss kept the backup and did not overwrite it."
        case .pendingRecovery: "A previous session still needs restoration. Choose Restore system pointer first."
        case .watchdogUnavailable: "The crash-recovery companion could not start. No theme was applied."
        }
    }
}
