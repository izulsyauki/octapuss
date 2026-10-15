import AppKit
import Darwin

/// Explicit opt-in integration check: briefly registers arrows, restores them, then kills
/// an owned worker to verify crash restoration. Never changes Accessibility color settings.
@main
struct SystemCursorLiveCheck {
    @MainActor
    static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        let args = CommandLine.arguments
        if args.count == 3, args[1] == "--cursor-read-many" {
            exit(SystemCursorAPI.runReader(names: args[2]))
        }
        if args.count == 4, args[1] == "--cursor-watchdog", let sessionID = UUID(uuidString: args[3]) {
            exit(SystemCursorSession.runWatchdog(path: args[2], sessionID: sessionID))
        }
        let api = try SystemCursorAPI()
        if args.count == 3, args[1] == "--worker" {
            let url = URL(fileURLWithPath: args[2])
            let session = SystemCursorSession(api: api, journalURL: url)
            try session.apply(try replacements())
            try Data().write(to: url.appendingPathExtension("worker-ready"))
            _ = FileHandle.standardInput.readDataToEndOfFile()
            try session.restore()
            return
        }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("octapuss-live-\(UUID().uuidString)")
        let url = root.appendingPathComponent("session.json")
        let session = SystemCursorSession(api: api, journalURL: url)
        let theme = try replacements()
        let baseline = try api.readMany(theme.map(\.name))
        defer {
            try? session.restore()
            if !session.hasPendingRecovery { try? FileManager.default.removeItem(at: root) }
        }
        try session.apply(theme)
        try session.restore()
        try api.verifyAll(baseline)
        guard !session.hasPendingRecovery else { throw CursorSystemError.pendingRecovery }
        print("Normal Apply/Restore: \(theme.count) slots, baseline pixels, sizes, hotspots, and journal cleanup verified.")

        let worker = Process()
        let input = Pipe()
        worker.executableURL = URL(fileURLWithPath: args[0])
        worker.arguments = ["--worker", url.path]
        worker.standardInput = input
        try worker.run()
        defer {
            try? input.fileHandleForWriting.close()
            if worker.isRunning { worker.terminate(); worker.waitUntilExit() }
        }
        let ready = url.appendingPathExtension("worker-ready")
        for _ in 0..<250 {
            if FileManager.default.fileExists(atPath: ready.path) { break }
            guard worker.isRunning else { throw CursorSystemError.watchdogUnavailable }
            Thread.sleep(forTimeInterval: 0.02)
        }
        guard FileManager.default.fileExists(atPath: ready.path) else { throw CursorSystemError.watchdogUnavailable }
        guard kill(worker.processIdentifier, SIGKILL) == 0 else { throw CursorSystemError.watchdogUnavailable }
        worker.waitUntilExit()
        for _ in 0..<250 {
            if !session.hasPendingRecovery { break }
            Thread.sleep(forTimeInterval: 0.02)
        }
        guard !session.hasPendingRecovery else { throw CursorSystemError.pendingRecovery }
        try api.verifyAll(baseline)
        print("SIGKILL recovery: watchdog restored all \(theme.count) slots and removed the journal.")
    }


    @MainActor
    static func replacements() throws -> [CursorSnapshot] {
        if let path = ProcessInfo.processInfo.environment["OCTAPUSS_LIVE_NATIVE_THEME"] {
            let theme = try CursorFileDecoder.decodeTheme(url: URL(fileURLWithPath: path))
            let plan = try CursorPackPlan(cursors: theme.cursors).replacements(using: SystemCursorAPI(), size: 32)
            print("Native theme: \(theme.name), \(plan.roleCount) roles, \(plan.snapshots.count) slots, \(plan.snapshots.filter { $0.frames > 1 }.count) animated slots.")
            return plan.snapshots
        }
        if let path = ProcessInfo.processInfo.environment["OCTAPUSS_LIVE_PACK_FOLDER"] {
            let files = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil)
                .filter { ["cur", "ani"].contains($0.pathExtension.lowercased()) }
            let cursors = try files.map { try CursorFileDecoder.decode(url: $0) }
            let plan = try CursorPackPlan(cursors: cursors).replacements(using: SystemCursorAPI(), size: 32)
            print("Pack plan: \(plan.roleCount) roles, \(plan.snapshots.count) slots, \(plan.snapshots.filter { $0.frames > 1 }.count) animated slots.")
            return plan.snapshots
        }
        if let path = ProcessInfo.processInfo.environment["OCTAPUSS_LIVE_CURSOR_FILE"] {
            let cursor = try CursorFileDecoder.decode(url: URL(fileURLWithPath: path))
            return try ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS"].map {
                try cursor.snapshot(name: $0, longestSide: 32)
            }
        }
        let images = try [1.0, 2.0, 5.0, 10.0].map { scale -> Data in
            let image = PointerArtwork.pointerImage(pack: .tide, size: 32 * scale)
            guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
                throw CursorSystemError.invalidBaseline
            }
            return data
        }
        return ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS"].map {
            CursorSnapshot(name: $0, width: 32, height: 32, x: 2, y: 2, frames: 1, duration: 0, images: images)
        }
    }
}
