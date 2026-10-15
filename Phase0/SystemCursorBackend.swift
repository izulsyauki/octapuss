import AppKit
import Darwin

enum CursorHelperRuntime {
    static func executableURL(in bundle: Bundle = .main) throws -> URL {
        let current = bundle.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        if bundle.bundleIdentifier == "dev.octapuss.cursorhelper" { return current }
        // Standalone test runners have no app bundle and already run without Dock presence.
        guard bundle.bundleURL.pathExtension == "app" else { return current }
        let helper = bundle.bundleURL.appendingPathComponent("Contents/Helpers/OctapussCursorHelper.app/Contents/MacOS/OctapussCursorHelper")
        guard FileManager.default.isExecutableFile(atPath: helper.path) else {
            throw CursorSystemError.call("Locate background cursor helper; rebuild Octapuss", -1)
        }
        return helper
    }

    static func prepare() -> Bool {
        // LSBackgroundOnly prevents even the initial Dock registration. Also enforce
        // this policy for standalone runners and older bundles invoking helper modes.
        let application = NSApplication.shared
        if application.activationPolicy() != .prohibited {
            guard application.setActivationPolicy(.prohibited) else { return false }
        }
        return application.activationPolicy() == .prohibited && application.windows.isEmpty
    }
}

/// Private ABI declarations, dynamically resolved. No upstream implementation is bundled.
/// Research references and compatibility limits: docs/SYSTEM_CURSOR.md.
protocol SystemCursorAccess {
    func read(_ name: String) throws -> CursorSnapshot
    func readMany(_ names: [String]) throws -> [CursorSnapshot]
    func readAvailable(_ names: [String]) throws -> [CursorSnapshot]
    func write(_ snapshot: CursorSnapshot) throws
}

extension SystemCursorAccess {
    func readAvailable(_ names: [String]) throws -> [CursorSnapshot] { names.compactMap { try? read($0) } }
    func readMany(_ names: [String]) throws -> [CursorSnapshot] { try names.map { try read($0) } }
    func verify(_ expected: CursorSnapshot) throws {
        try verifyAll([expected])
    }
    func verifyAll(_ expected: [CursorSnapshot]) throws {
        for attempt in 0..<4 {
            let actual = try readMany(expected.map(\.name))
            if actual.count == expected.count,
               zip(actual, expected).allSatisfy({ (try? $0.matches($1)) == true }) { return }
            if attempt < 3 { Thread.sleep(forTimeInterval: 0.02) }
        }
        throw CursorSystemError.call("Verify registered cursor images", -1)
    }
}

enum PointerColorCompatibility {
    static func hasOverride(in defaults: UserDefaults? = UserDefaults(suiteName: "com.apple.universalaccess")) -> Bool {
        func differs(_ key: String, expected: Double) -> Bool {
            guard let color = defaults?.dictionary(forKey: key) else { return false }
            func component(_ key: String, fallback: Double) -> Double {
                if let number = color[key] as? NSNumber { return number.doubleValue }
                if let text = color[key] as? String, let number = Double(text) { return number }
                return fallback
            }
            return ["red", "green", "blue"].contains {
                abs(component($0, fallback: expected) - expected) > 0.001
            } || abs(component("alpha", fallback: 1) - 1) > 0.001
        }
        return differs("cursorFill", expected: 0) || differs("cursorOutline", expected: 1)
    }
}

final class SystemCursorAPI: SystemCursorAccess {
    typealias Connection = @convention(c) () -> Int32
    typealias NewConnection = @convention(c) (Int32, UnsafeMutablePointer<Int32>) -> Int32
    typealias ReleaseConnection = @convention(c) (Int32) -> Int32
    typealias CopyImages = @convention(c) (Int32, UnsafePointer<CChar>, UnsafeMutablePointer<CGSize>, UnsafeMutablePointer<CGPoint>, UnsafeMutablePointer<Int>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Unmanaged<CFArray>?>) -> Int32
    typealias Register = @convention(c) (Int32, UnsafePointer<CChar>, Bool, Bool, CGSize, CGPoint, Int, Double, CFArray, UnsafeMutablePointer<Int32>) -> Int32

    let connection: Connection
    let newConnection: NewConnection
    let releaseConnection: ReleaseConnection
    let copyImages: CopyImages
    let register: Register
    private let handles: [UnsafeMutableRawPointer]

    init() throws {
        let paths = [
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
        ]
        let opened = paths.compactMap { dlopen($0, RTLD_LAZY | RTLD_LOCAL) }
        handles = opened
        func symbol(_ names: [String]) throws -> UnsafeMutableRawPointer {
            for name in names {
                for handle in opened {
                    if let address = dlsym(handle, name) { return address }
                }
            }
            throw CursorSystemError.unavailable(names[0])
        }
        connection = unsafeBitCast(try symbol(["CGSMainConnectionID", "SLSMainConnectionID", "_CGSDefaultConnection"]), to: Connection.self)
        newConnection = unsafeBitCast(try symbol(["CGSNewConnection", "SLSNewConnection"]), to: NewConnection.self)
        releaseConnection = unsafeBitCast(try symbol(["CGSReleaseConnection", "SLSReleaseConnection"]), to: ReleaseConnection.self)
        copyImages = unsafeBitCast(try symbol(["CGSCopyRegisteredCursorImages", "SLSCopyRegisteredCursorImages", "CGSGetRegisteredCursorImages"]), to: CopyImages.self)
        register = unsafeBitCast(try symbol(["CGSRegisterCursorWithImages", "SLSRegisterCursorWithImages"]), to: Register.self)
    }

    func read(_ name: String) throws -> CursorSnapshot {
        guard let result = try readMany([name]).first else { throw CursorSystemError.invalidBaseline }
        return result
    }

    func readMany(_ names: [String]) throws -> [CursorSnapshot] {
        try readNames(names, availableOnly: false)
    }

    func readAvailable(_ names: [String]) throws -> [CursorSnapshot] {
        try readNames(names, availableOnly: true)
    }

    private func readNames(_ names: [String], availableOnly: Bool) throws -> [CursorSnapshot] {
        // The private copy API caches registrations for a process, even across connections.
        // A one-shot reader is required to observe the actual global registry after writes.
        let process = Process()
        let output = Pipe()
        process.executableURL = try CursorHelperRuntime.executableURL()
        process.arguments = ["--cursor-read-many", (availableOnly ? "?" : "") + names.joined(separator: ",")]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CursorSystemError.call("Read system cursor registry", process.terminationStatus) }
        return try JSONDecoder().decode([CursorSnapshot].self, from: data)
    }

    static func runReader(names: String) -> Int32 {
        do {
            guard CursorHelperRuntime.prepare() else { return 1 }
            let api = try SystemCursorAPI()
            let optional = names.hasPrefix("?")
            let list = (optional ? String(names.dropFirst()) : names).split(separator: ",").map(String.init)
            let snapshots: [CursorSnapshot]
            if optional { snapshots = list.compactMap { try? api.readDirect($0) } }
            else { snapshots = try list.map { try api.readDirect($0) } }
            try FileHandle.standardOutput.write(contentsOf: JSONEncoder().encode(snapshots))
            return 0
        } catch { return 1 }
    }

    private func readDirect(_ name: String) throws -> CursorSnapshot {
        // A writer's connection can retain the preceding cursor representation.
        // Verify against a fresh read connection, not its local cache.
        var reader: Int32 = 0
        let connectResult = newConnection(0, &reader)
        guard connectResult == 0 else { throw CursorSystemError.call("Open verification connection", connectResult) }
        defer { _ = releaseConnection(reader) }
        var size = CGSize.zero
        var hotspot = CGPoint.zero
        var frames = 0
        var duration = 0.0
        var images: Unmanaged<CFArray>?
        let result = name.withCString {
            copyImages(reader, $0, &size, &hotspot, &frames, &duration, &images)
        }
        guard result == 0, let images else { throw CursorSystemError.call("Read \(name)", result) }
        let array = images.takeRetainedValue() as [AnyObject]
        guard size.width > 0, size.height > 0, frames > 0, !array.isEmpty else {
            throw CursorSystemError.invalidBaseline
        }
        let data: [Data] = try array.map { item in
            guard CFGetTypeID(item) == CGImage.typeID else { throw CursorSystemError.invalidBaseline }
            let image = unsafeBitCast(item, to: CGImage.self)
            guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw CursorSystemError.invalidBaseline
            }
            return png
        }
        return CursorSnapshot(name: name, width: size.width, height: size.height,
                              x: hotspot.x, y: hotspot.y, frames: frames, duration: duration, images: data)
    }

    func write(_ snapshot: CursorSnapshot) throws {
        let images: [CGImage] = try snapshot.images.map {
            guard let image = NSBitmapImageRep(data: $0)?.cgImage else {
                throw CursorSystemError.invalidBaseline
            }
            return image
        }
        guard !images.isEmpty, snapshot.width > 0, snapshot.height > 0,
              snapshot.frames > 0, snapshot.x >= 0, snapshot.y >= 0,
              snapshot.x < snapshot.width, snapshot.y < snapshot.height else {
            throw CursorSystemError.invalidBaseline
        }
        var seed: Int32 = 0
        let result = snapshot.name.withCString {
            register(connection(), $0, true, true,
                     CGSize(width: snapshot.width, height: snapshot.height),
                     CGPoint(x: snapshot.x, y: snapshot.y), snapshot.frames,
                     snapshot.duration, images as CFArray, &seed)
        }
        guard result == 0 else { throw CursorSystemError.call("Register \(snapshot.name)", result) }
    }
}

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

struct CursorSnapshot: Codable {
    let name: String
    let width: Double
    let height: Double
    let x: Double
    let y: Double
    let frames: Int
    let duration: Double
    let images: [Data]

    /// Compare decoded pixels, not PNG encoding, to detect another utility taking ownership.
    func matches(_ other: CursorSnapshot) throws -> Bool {
        guard name == other.name, width == other.width, height == other.height,
              x == other.x, y == other.y, frames == other.frames,
              abs(duration - other.duration) < 0.000001 else { return false }
        func hashes(_ data: [Data]) throws -> [String] {
            try data.map { png in
                guard let image = NSBitmapImageRep(data: png)?.cgImage,
                      let context = CGContext(data: nil, width: image.width, height: image.height,
                                              bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                      let bytes = context.data else { throw CursorSystemError.invalidBaseline }
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                var hash: UInt64 = 14695981039346656037
                for byte in UnsafeRawBufferPointer(start: bytes, count: image.width * image.height * 4) {
                    hash = (hash ^ UInt64(byte)) &* 1099511628211
                }
                return "\(image.width)x\(image.height):\(hash)"
            }.sorted()
        }
        return try hashes(images) == hashes(other.images)
    }
}

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

struct CursorJournal: Codable {
    let sessionID: UUID?
    let original: [CursorSnapshot]
    let applied: [CursorSnapshot]
}

/// Journaled native cursor slots. No pointer hiding or privileged installation.
@MainActor
final class SystemCursorSession {
    let journalURL: URL
    private let api: SystemCursorAccess
    private var watchdog: Process?
    private var lifeline: Pipe?

    nonisolated static var defaultJournalURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Octapuss/system-arrow-session.json")
    }

    init(api: SystemCursorAccess, journalURL: URL = SystemCursorSession.defaultJournalURL) {
        self.api = api
        self.journalURL = journalURL
    }

    var hasPendingRecovery: Bool { FileManager.default.fileExists(atPath: journalURL.path) }

    func apply(_ replacements: [CursorSnapshot], startWatchdog: Bool = true) throws {
        try Self.withJournalLock(journalURL) {
            try applyLocked(replacements, startWatchdog: startWatchdog)
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
        try Self.withJournalLock(journalURL) { try restoreLocked() }
    }

    /// Explicit Apply accepts externally changed cursors as the next baseline.
    /// Restore anything still owned first, and retain the old backup for inspection.
    func prepareForApplication() throws {
        try Self.withJournalLock(journalURL) {
            do { try restoreLocked() }
            catch CursorSystemError.ownershipChanged {
                let archive = journalURL.deletingLastPathComponent()
                    .appendingPathComponent("system-arrow-backup-\(UUID().uuidString).json")
                try FileManager.default.moveItem(at: journalURL, to: archive)
                closeWatchdog()
            }
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
