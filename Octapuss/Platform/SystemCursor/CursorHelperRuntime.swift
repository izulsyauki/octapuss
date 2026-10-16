import AppKit

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
