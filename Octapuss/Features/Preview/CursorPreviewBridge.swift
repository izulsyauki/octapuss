import SwiftUI

struct CursorPreviewBridge: NSViewRepresentable {
    @ObservedObject var store: AppStore

    func makeNSView(context: Context) -> CursorPreviewNSView {
        let view = CursorPreviewNSView()
        view.setAccessibilityLabel("Pointer playground inside Octapuss")
        view.setAccessibilityHelp("Move here to try the selected cursor. Boop tests clicking.")
        return view
    }

    func updateNSView(_ view: CursorPreviewNSView, context: Context) {
        view.onClick = { store.recordClick() }
        view.configure(pack: store.pack, size: store.pointerSize, dark: store.darkPreview,
                       enabled: store.previewEnabled || store.isApplying, clicks: store.clickCount,
                       imported: store.isApplying ? store.applyingCursor : store.selectedImportedCursor)
    }

    static func dismantleNSView(_ view: CursorPreviewNSView, coordinator: ()) {
        view.stopAnimation()
        view.onClick = nil
    }
}
