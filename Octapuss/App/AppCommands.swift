import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var store: AppStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Import cursor files…") { store.chooseCursorFiles() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(store.isApplying)
            Button("Import unzipped set folder…") { store.chooseCursorFiles(asFolder: true) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(store.isApplying)
        }
        CommandGroup(after: .appInfo) {
            Button("Restore system pointer") { store.restore() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
