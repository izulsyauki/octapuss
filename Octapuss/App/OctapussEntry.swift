import AppKit

#if !OCTAPUSS_CHECKS
@main
enum OctapussEntry {
    @MainActor
    static func main() {
        if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--cursor-helper-check" {
            let valid = Bundle.main.bundleIdentifier == "dev.octapuss.cursorhelper"
                && Bundle.main.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool == true
                && CursorHelperRuntime.prepare()
            print(valid ? "Background cursor helper: prohibited activation, no windows." : "Invalid cursor helper configuration.")
            exit(valid ? 0 : 1)
        }
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--cursor-read-many" {
            exit(SystemCursorAPI.runReader(names: CommandLine.arguments[2]))
        }
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--cursor-watchdog",
           let sessionID = UUID(uuidString: CommandLine.arguments[3]) {
            exit(SystemCursorSession.runWatchdog(path: CommandLine.arguments[2], sessionID: sessionID))
        }
        // A helper launched with missing/invalid arguments must never open the UI.
        guard Bundle.main.bundleIdentifier != "dev.octapuss.cursorhelper" else { exit(64) }
        OctapussApp.main()
    }
}
#endif
