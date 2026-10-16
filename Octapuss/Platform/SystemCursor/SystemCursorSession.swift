import Foundation
import Darwin

/// Journaled native cursor slots. No pointer hiding or privileged installation.
final class SystemCursorSession: @unchecked Sendable {
    let journalURL: URL
    private let api: SystemCursorAccess
    private var watchdog: Process?
    private var lifeline: Pipe?
    // All instance mutations, including synchronous recovery callers, share this queue.
    private let operations = DispatchQueue(label: "dev.octapuss.cursor-session", qos: .userInitiated)

    static var defaultJournalURL: URL {
        ApplicationPaths.cursorJournal
    }

    init(api: SystemCursorAccess, journalURL: URL = SystemCursorSession.defaultJournalURL) {
        self.api = api
        self.journalURL = journalURL
    }

    var hasPendingRecovery: Bool { FileManager.default.fileExists(atPath: journalURL.path) }

    func apply(_ replacements: [CursorSnapshot], startWatchdog: Bool = true) throws {
        try operations.sync {
            try Self.withJournalLock(journalURL) {
                try applyLocked(replacements, startWatchdog: startWatchdog)
            }
        }
    }

    func replaceAsync(_ replacements: [CursorSnapshot], startWatchdog: Bool = true) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operations.async {
                do {
                    try Self.withJournalLock(self.journalURL) {
                        try self.prepareForApplicationLocked()
                        try self.applyLocked(replacements, startWatchdog: startWatchdog)
                    }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func restoreAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operations.async {
                do {
                    try Self.withJournalLock(self.journalURL) { try self.restoreLocked() }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func applyLocked(_ replacements: [CursorSnapshot], startWatchdog: Bool) throws {
        guard !hasPendingRecovery else { throw CursorSystemError.pendingRecovery }
        guard !replacements.isEmpty else { throw CursorSystemError.invalidBaseline }
        guard Set(replacements.map(\.name)).count == replacements.count else { throw CursorSystemError.invalidBaseline }
        // Read every baseline before acquiring any global effect.
        let originals = try api.readMany(replacements.map(\.name))
        let sessionID = UUID()
        let journal = CursorJournal(sessionID: sessionID, original: originals, applied: replacements)
        try FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(journal).write(to: journalURL, options: .atomic)
        do {
            if startWatchdog { try launchWatchdog(sessionID: sessionID) }
            for snapshot in replacements { try api.write(snapshot) }
            try api.verifyAll(replacements)
        } catch {
            // A failed write may have partially applied. Restore only known owned slots.
            do { try restoreLocked() } catch { throw error }
            throw error
        }
    }

    func restore() throws {
        try operations.sync {
            try Self.withJournalLock(journalURL) { try restoreLocked() }
        }
    }

    /// Explicit Apply accepts externally changed cursors as the next baseline.
    /// Restore anything still owned first, and retain the old backup for inspection.
    func prepareForApplication() throws {
        try operations.sync {
            try Self.withJournalLock(journalURL) {
                try prepareForApplicationLocked()
            }
        }
    }

    private func prepareForApplicationLocked() throws {
        do { try restoreLocked() }
        catch CursorSystemError.ownershipChanged {
            let archive = journalURL.deletingLastPathComponent()
                .appendingPathComponent("system-arrow-backup-\(UUID().uuidString).json")
            try FileManager.default.moveItem(at: journalURL, to: archive)
            closeWatchdog()
        }
    }

    private func restoreLocked() throws {
        guard hasPendingRecovery else {
            closeWatchdog()
            return
        }
        let journal = try JSONDecoder().decode(CursorJournal.self, from: Data(contentsOf: journalURL))
        try Self.restore(journal, using: api)
        try FileManager.default.removeItem(at: journalURL)
        closeWatchdog()
    }

    private static func withJournalLock<T>(_ url: URL, wait: Bool = false, body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(url.appendingPathExtension("lock").path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw CursorSystemError.pendingRecovery }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | (wait ? 0 : LOCK_NB)) == 0 else { throw CursorSystemError.pendingRecovery }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    static func restore(_ journal: CursorJournal, using api: SystemCursorAccess) throws {
        guard journal.original.count == journal.applied.count else { throw CursorSystemError.invalidBaseline }
        var failures: [Error] = []
        let currentSlots = try api.readMany(journal.original.map(\.name))
        guard currentSlots.count == journal.original.count else { throw CursorSystemError.invalidBaseline }
        var restored: [CursorSnapshot] = []
        for (index, baseline) in journal.original.enumerated() {
            do {
            guard baseline.name == journal.applied[index].name else { throw CursorSystemError.invalidBaseline }
            let current = currentSlots[index]
            if try current.matches(baseline) { continue }
            guard try current.matches(journal.applied[index]) else {
                throw CursorSystemError.ownershipChanged(baseline.name)
            }
            try api.write(baseline)
            restored.append(baseline)
            } catch { failures.append(error) }
        }
        if !restored.isEmpty {
            do { try api.verifyAll(restored) } catch { failures.append(error) }
        }
        // Never let an ownership conflict conceal a failed write or verification.
        if let failure = failures.first(where: {
            if case CursorSystemError.ownershipChanged = $0 { return false }
            return true
        }) { throw failure }
        if let failure = failures.first { throw failure }
    }

    private func launchWatchdog(sessionID: UUID) throws {
        let process = Process()
        let pipe = Pipe()
        let readyPath = journalURL.appendingPathExtension("ready-\(sessionID.uuidString)")
        if FileManager.default.fileExists(atPath: readyPath.path) {
            try FileManager.default.removeItem(at: readyPath)
        }
        process.executableURL = try CursorHelperRuntime.executableURL()
        process.arguments = ["--cursor-watchdog", journalURL.path, sessionID.uuidString]
        process.standardInput = pipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Child signals readiness before we register anything.
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: readyPath.path) {
                try FileManager.default.removeItem(at: readyPath)
                watchdog = process
                lifeline = pipe
                return
            }
            guard process.isRunning else { throw CursorSystemError.watchdogUnavailable }
            Thread.sleep(forTimeInterval: 0.01)
        }
        try? pipe.fileHandleForWriting.close()
        throw CursorSystemError.watchdogUnavailable
    }

    private func closeWatchdog() {
        try? lifeline?.fileHandleForWriting.close()
        lifeline = nil
        watchdog = nil
    }

    static func restoreOwnedJournal(at url: URL, sessionID: UUID, using api: SystemCursorAccess) throws {
        try withJournalLock(url, wait: true) {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let journal = try JSONDecoder().decode(CursorJournal.self, from: Data(contentsOf: url))
            // A retired watchdog must never restore or delete a replacement session's baseline.
            guard journal.sessionID == sessionID else { return }
            try restore(journal, using: api)
            try FileManager.default.removeItem(at: url)
        }
    }

    static func runWatchdog(path: String, sessionID: UUID) -> Int32 {
        let url = URL(fileURLWithPath: path)
        do {
            guard CursorHelperRuntime.prepare() else { return 1 }
            let api = try SystemCursorAPI()
            // Resolve the API before accepting ownership of crash cleanup.
            try Data().write(to: url.appendingPathExtension("ready-\(sessionID.uuidString)"), options: .atomic)
            _ = FileHandle.standardInput.readDataToEndOfFile()
            try restoreOwnedJournal(at: url, sessionID: sessionID, using: api)
            return 0
        } catch { return 1 } // Durable baseline remains available for the next launch.
    }
}
