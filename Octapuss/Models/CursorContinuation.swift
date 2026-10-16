import Foundation

/// Keeps the exact applied artwork independent from subsequent library browsing.
/// Suspension reasons overlap during lock + sleep; only the last return may resume.
struct CursorContinuation {
    enum Suspension: Hashable { case sleep, session, lock }
    private(set) var snapshots: [CursorSnapshot] = []
    private var suspensions: Set<Suspension> = []
    private var waitingToResume = false

    var canResume: Bool { waitingToResume && suspensions.isEmpty && !snapshots.isEmpty }

    mutating func applied(_ snapshots: [CursorSnapshot]) {
        self.snapshots = snapshots
        waitingToResume = false
    }

    mutating func suspend(_ reason: Suspension) -> Bool {
        suspensions.insert(reason)
        guard !snapshots.isEmpty, !waitingToResume else { return false }
        waitingToResume = true
        return true
    }

    mutating func returned(_ reason: Suspension) { suspensions.remove(reason) }
    mutating func didResume() { waitingToResume = false }
    mutating func cancel() {
        snapshots = []
        waitingToResume = false
    }
}
