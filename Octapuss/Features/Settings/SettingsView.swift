import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section("System customization") {
                Label(store.statusTitle, systemImage: "cursorarrow")
                    .foregroundStyle(Color(nsColor: AppPalette.tide))
                Text("Apply pack changes every assigned and available macOS cursor role. Unassigned roles, app-drawn cursors, protected prompts, and Windows-only roles can differ. Single unnamed cursor imports change the arrow only.")
                    .foregroundStyle(.secondary)
                Button(store.applyActionTitle) { store.applySelectedCursor() }.disabled(store.isApplying)
                Button("Restore system pointer") { store.restore() }
                if store.systemColorOverride {
                    Text("Your custom macOS pointer colors override registered themes. Choose Accessibility > Display > Pointer > Reset Colors in System Settings, then Apply again.")
                    Button("Open System Settings…") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
                    }
                }
            }
            Section("Preview") {
                Text(store.statusTitle)
                Button(store.previewEnabled ? "Restore system pointer" : "Resume preview") {
                    if store.previewEnabled { store.restore() } else { store.resumePreview() }
                }
            }
            Section("Privacy") {
                Text("Octapuss stores your pointer style, size, and preview background on this Mac. It records no pointer history, typing, screenshots, or app activity.")
            }
            Button("Reset preferences") {
                store.resetPreferences()
            }.disabled(store.isApplying)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 540, height: 430)
        .tint(Color(nsColor: AppPalette.lavender))
    }
}
