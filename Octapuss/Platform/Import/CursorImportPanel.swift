import AppKit
import UniformTypeIdentifiers

enum CursorImportPanel {
    static func choose(asFolder: Bool, completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.title = asFolder ? "Import cursor set" : "Import cursor files"
        panel.message = asFolder
            ? "Choose an unzipped folder. Cursor roles are matched by filename; ANI animation is imported."
            : "Choose .cur or .ani files, or one .cursor theme. Animation and supported cursor roles are imported."
        panel.prompt = "Import"
        panel.canChooseDirectories = asFolder
        panel.canChooseFiles = !asFolder
        panel.allowsMultipleSelection = !asFolder
        if !asFolder {
            panel.allowedContentTypes = ["cur", "ani", "cursor"].compactMap { UTType(filenameExtension: $0) }
        }
        panel.begin { response in
            guard response == .OK else { return }
            completion(panel.urls)
        }
    }
}
