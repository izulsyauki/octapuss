import AppKit
import Darwin

/// Private ABI declarations, dynamically resolved. No upstream implementation is bundled.
/// Research references and compatibility limits: docs/SYSTEM_CURSOR.md.
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
        try Self.write(snapshot, connection: connection(), register: register)
    }

    /// Keep the ABI boundary injectable so checks can observe registration flags
    /// without changing a real system cursor.
    static func write(_ snapshot: CursorSnapshot, connection: Int32, register: Register) throws {
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
            // Register globally, but do not force this role onto the live pointer.
            // Apply/Restore write many roles; displaying each one caused visible
            // cycling through text, resize, busy, and baseline shapes.
            register(connection, $0, true, false,
                     CGSize(width: snapshot.width, height: snapshot.height),
                     CGPoint(x: snapshot.x, y: snapshot.y), snapshot.frames,
                     snapshot.duration, images as CFArray, &seed)
        }
        guard result == 0 else { throw CursorSystemError.call("Register \(snapshot.name)", result) }
    }
}
