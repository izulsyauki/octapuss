import SwiftUI

#if !OCTAPUSS_CHECKS
struct OctapussApp: App {
    @NSApplicationDelegateAdaptor(OctapussAppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        Window("Octapuss", id: "main") {
            CursorLibraryView()
                .environmentObject(store)
                .onAppear {
                    appDelegate.store = store
                    store.recoverSystemPointerIfNeeded()
                }
        }
        .defaultSize(width: 1080, height: 760)
        .commands {
            AppCommands(store: store)
            CommandGroup(replacing: .appTermination) {
                Button("Keep Running in Menu Bar") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
        }

        MenuBarExtra("Octapuss", systemImage: "cursorarrow.rays") {
            Text(store.statusTitle)
            Divider()
            Button("Open Octapuss") {
                appDelegate.showMainWindow()
                openWindow(id: "main")
            }
            Button(store.applyActionTitle) { store.applySelectedCursor() }.disabled(store.isApplying)
            Menu("Pointer pal") {
                ForEach(PointerPack.allCases) { pack in
                    Button {
                        store.pack = pack

                    } label: {
                        if store.pack == pack {
                            Label(pack.title, systemImage: "checkmark")
                        } else {
                            Text(pack.title)
                        }
                    }
                }
            }.disabled(store.isApplying)
            Button("Restore system pointer") { store.restore() }
            if !store.previewEnabled {
                Button("Resume local preview") { store.resumePreview() }
            }
            Divider()
            Button("Settings…") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            }
                .keyboardShortcut(",", modifiers: .command)
            Button("Quit Octapuss") {
                appDelegate.quitFromMenuBar()
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

#endif
