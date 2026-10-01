import AppKit
import CoreGraphics
import SwiftUI

// Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V4
// Native utility · genre: playful-operate · theme: DESIGN.md locked
// Structural fingerprint: pointer workbench with one dominant live preview.

enum AppPalette {
    static let ink = NSColor(srgbRed: 0.125, green: 0.165, blue: 0.192, alpha: 1)
    static let tide = NSColor(srgbRed: 0.086, green: 0.463, blue: 0.427, alpha: 1)
    static let blush = NSColor(srgbRed: 0.643, green: 0.278, blue: 0.376, alpha: 1)
    static let pointerOutline = NSColor.white.withAlphaComponent(0.96)
    static let pointerDetail = NSColor.white.withAlphaComponent(0.8)
    static let previewLight = NSColor(srgbRed: 1, green: 0.988, blue: 0.961, alpha: 1)
    static let previewDark = NSColor(srgbRed: 0.082, green: 0.114, blue: 0.133, alpha: 1)
    static let backgroundLight = NSColor(srgbRed: 0.965, green: 0.945, blue: 0.902, alpha: 1)
    static let backgroundDark = previewDark

    static let background = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? backgroundDark
            : backgroundLight
    }
}

enum PointerPack: String, CaseIterable, Identifiable {
    case ink
    case tide
    case blush

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var detail: String {
        switch self {
        case .ink: "Crisp and neutral"
        case .tide: "Deep teal"
        case .blush: "Warm rose"
        }
    }

    var color: NSColor {
        switch self {
        case .ink: AppPalette.ink
        case .tide: AppPalette.tide
        case .blush: AppPalette.blush
        }
    }
}

enum PointerSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var points: CGFloat {
        switch self {
        case .small: 24
        case .medium: 32
        case .large: 40
        }
    }
}

enum ProofStatus: Equatable {
    case off
    case companion
    case hideTest
    case recoveryRequired(String)

    var title: String {
        switch self {
        case .off: "Customization off · preview available"
        case .companion: "Pointer companion active"
        case .hideTest: "Documented hide test running"
        case .recoveryRequired: "Restoration incomplete"
        }
    }
}

@MainActor
final class ProofStore: ObservableObject {
    @Published var pack: PointerPack {
        didSet { UserDefaults.standard.set(pack.rawValue, forKey: "selectedPack") }
    }

    @Published var pointerSize: PointerSize {
        didSet { UserDefaults.standard.set(pointerSize.rawValue, forKey: "pointerSize") }
    }

    @Published var darkPreview = false
    @Published private(set) var status: ProofStatus = .off
    @Published private(set) var diagnostic = "Ready. No global permission requested."

    private let companion = PointerCompanionController()
    private var hideOwned = false
    private var hideRestoreWorkItem: DispatchWorkItem?

    init() {
        let savedPack = UserDefaults.standard.string(forKey: "selectedPack")
        let savedSize = UserDefaults.standard.string(forKey: "pointerSize")
        pack = PointerPack(rawValue: savedPack ?? "") ?? .ink
        pointerSize = PointerSize(rawValue: savedSize ?? "") ?? .medium
    }

    var cursor: NSCursor {
        PointerArtwork.cursor(pack: pack, size: pointerSize.points)
    }

    func toggleCompanion() {
        if status == .companion {
            restore()
            return
        }

        guard !hideOwned else {
            diagnostic = "Restore the hide test before starting the companion."
            return
        }

        companion.start(pack: pack)
        status = .companion
        diagnostic = "Companion only: the native pointer intentionally remains visible."
    }

    func updateCompanionIfNeeded() {
        guard status == .companion else { return }
        companion.update(pack: pack)
    }

    func runForegroundHideCheck() {
        guard status == .off else {
            diagnostic = "Restore current effects before running the hide check."
            return
        }

        let result = CGDisplayHideCursor(CGMainDisplayID())
        guard result == .success else {
            status = .recoveryRequired("CGDisplayHideCursor returned \(result.rawValue)")
            diagnostic = "The cursor was not hidden. No hide ownership was recorded."
            return
        }

        hideOwned = true
        status = .hideTest
        diagnostic = "Cursor hidden for 2 seconds while Octapuss is foreground. It will be shown exactly once."

        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.restore()
            }
        }
        hideRestoreWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
    }

    func restore() {
        hideRestoreWorkItem?.cancel()
        hideRestoreWorkItem = nil
        companion.stop()

        if hideOwned {
            let result = CGDisplayShowCursor(CGMainDisplayID())
            if result != .success {
                status = .recoveryRequired("CGDisplayShowCursor returned \(result.rawValue)")
                diagnostic = "Restoration incomplete. Try Restore again before quitting."
                return
            }
            hideOwned = false
        }

        status = .off
        diagnostic = "Across-app effects stopped. The labeled preview remains available."
    }

    func prepareToQuit() -> Bool {
        restore()
        if case .recoveryRequired = status { return false }
        return true
    }
}

enum PointerArtwork {
    static func cursor(pack: PointerPack, size: CGFloat) -> NSCursor {
        let scale = size / 32
        return NSCursor(
            image: pointerImage(pack: pack, size: size),
            hotSpot: NSPoint(x: 2 * scale, y: 2 * scale)
        )
    }

    static func pointerImage(pack: PointerPack, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let scale = size / 32
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 2 * scale, y: 2 * scale))
            path.line(to: NSPoint(x: 3.4 * scale, y: 24 * scale))
            path.line(to: NSPoint(x: 9.4 * scale, y: 18.8 * scale))
            path.line(to: NSPoint(x: 14.2 * scale, y: 28.5 * scale))
            path.line(to: NSPoint(x: 19 * scale, y: 26.1 * scale))
            path.line(to: NSPoint(x: 14.3 * scale, y: 17 * scale))
            path.line(to: NSPoint(x: 22.5 * scale, y: 16.1 * scale))
            path.close()

            AppPalette.pointerOutline.setStroke()
            path.lineWidth = max(2.8, 3.3 * scale)
            path.lineJoinStyle = .round
            path.stroke()
            pack.color.setFill()
            path.fill()

            let earPath = NSBezierPath()
            earPath.move(to: NSPoint(x: 5.5 * scale, y: 18.5 * scale))
            earPath.line(to: NSPoint(x: 7.4 * scale, y: 14.2 * scale))
            earPath.line(to: NSPoint(x: 10.4 * scale, y: 18.1 * scale))
            earPath.move(to: NSPoint(x: 9.7 * scale, y: 18.6 * scale))
            earPath.line(to: NSPoint(x: 12.1 * scale, y: 14.7 * scale))
            earPath.line(to: NSPoint(x: 14.7 * scale, y: 17.8 * scale))
            earPath.lineWidth = max(1, 1.2 * scale)
            earPath.lineCapStyle = .round
            AppPalette.pointerDetail.setStroke()
            earPath.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }

    static func companionImage(pack: PointerPack) -> NSImage {
        let size: CGFloat = 30
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            let head = NSBezierPath(roundedRect: NSRect(x: 4, y: 7, width: 22, height: 18), xRadius: 9, yRadius: 9)
            let leftEar = NSBezierPath()
            leftEar.move(to: NSPoint(x: 7, y: 10))
            leftEar.line(to: NSPoint(x: 9, y: 3))
            leftEar.line(to: NSPoint(x: 14, y: 8))
            leftEar.close()
            let rightEar = NSBezierPath()
            rightEar.move(to: NSPoint(x: 16, y: 8))
            rightEar.line(to: NSPoint(x: 21, y: 3))
            rightEar.line(to: NSPoint(x: 23, y: 10))
            rightEar.close()
            AppPalette.pointerOutline.setStroke()
            pack.color.setFill()
            for path in [leftEar, rightEar, head] {
                path.lineWidth = 2
                path.stroke()
                path.fill()
            }
            let tentacles = NSBezierPath()
            for x in stride(from: 9.0, through: 21.0, by: 4.0) {
                tentacles.move(to: NSPoint(x: x, y: 23))
                tentacles.curve(to: NSPoint(x: x - 1.5, y: 28), controlPoint1: NSPoint(x: x + 2, y: 25), controlPoint2: NSPoint(x: x + 1, y: 28))
            }
            tentacles.lineWidth = 2.2
            tentacles.lineCapStyle = .round
            pack.color.setStroke()
            tentacles.stroke()
            return true
        }
        return image
    }
}

@MainActor
final class PointerCompanionController {
    private var panel: NSPanel?
    private var imageView: NSImageView?
    private var timer: Timer?

    func start(pack: PointerPack) {
        stop()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 34, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false

        let imageView = NSImageView(frame: panel.contentView?.bounds ?? .zero)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = PointerArtwork.companionImage(pack: pack)
        panel.contentView = imageView
        panel.orderFrontRegardless()

        self.panel = panel
        self.imageView = imageView
        moveToPointer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.moveToPointer()
            }
        }
    }

    func update(pack: PointerPack) {
        imageView?.image = PointerArtwork.companionImage(pack: pack)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
        imageView = nil
    }

    private func moveToPointer() {
        guard let panel else { return }
        let point = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: point.x + 13, y: point.y - 42))
    }
}

final class CursorPreviewNSView: NSView {
    var cursor: NSCursor = .arrow {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: cursor)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

struct CursorPreviewBridge: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> CursorPreviewNSView {
        let view = CursorPreviewNSView()
        view.cursor = cursor
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.group)
        view.setAccessibilityLabel("Pointer preview inside Octapuss")
        view.setAccessibilityHelp("Move the pointer here to try the selected cursor at its actual size.")
        return view
    }

    func updateNSView(_ nsView: CursorPreviewNSView, context: Context) {
        nsView.cursor = cursor
    }
}

struct CursorPreview: View {
    @ObservedObject var store: ProofStore

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: store.darkPreview ? AppPalette.previewDark : AppPalette.previewLight))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(store.darkPreview ? Color.white.opacity(0.12) : Color.black.opacity(0.1))
            VStack(alignment: .leading, spacing: 12) {
                Text("Move here to try the actual pointer")
                    .font(.system(size: 15, weight: .semibold))
                Text("Click targets stay ordinary so the visible tip can be checked precisely.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Text("Sample text")
                        .textSelection(.enabled)
                    Button("Sample button") {}
                }
            }
            .foregroundStyle(Color(nsColor: store.darkPreview ? AppPalette.pointerOutline : AppPalette.ink))
            .padding(22)
            CursorPreviewBridge(cursor: store.cursor)
                .accessibilityHidden(false)
        }
        .frame(minHeight: 205)
    }
}

struct PackRow: View {
    let pack: PointerPack
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: PointerArtwork.pointerImage(pack: pack, size: 27))
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.title).font(.system(size: 13, weight: .semibold))
                Text(pack.detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(nsColor: AppPalette.tide))
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: ProofStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Octapuss Cursor Lab")
                        .font(.system(size: 22, weight: .semibold))
                    Text(store.status.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(store.status == .companion ? "Pause companion" : "Enable pointer companion") {
                    store.toggleCompanion()
                }
                .keyboardShortcut(.space, modifiers: [.command])
            }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pointer presets")
                        .font(.system(size: 15, weight: .semibold))
                    ForEach(PointerPack.allCases) { pack in
                        Button {
                                store.pack = pack
                                store.updateCompanionIfNeeded()
                        } label: {
                            PackRow(pack: pack, isSelected: store.pack == pack)
                        }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(store.pack == pack ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 172)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Preview inside Octapuss")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Picker("", selection: $store.darkPreview) {
                            Text("Light").tag(false)
                            Text("Dark").tag(true)
                        }
                        .labelsHidden()
                        .accessibilityLabel("Test background")
                        .pickerStyle(.segmented)
                        .frame(width: 128)
                    }
                    CursorPreview(store: store)
                    HStack {
                        Text("Size")
                        Picker("", selection: $store.pointerSize) {
                            ForEach(PointerSize.allCases) { size in
                                Text(size.title).tag(size)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Pointer size")
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            HStack(alignment: .center, spacing: 12) {
                Button("Restore system pointer") { store.restore() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Run 2-second foreground hide check") { store.runForegroundHideCheck() }
                    .disabled(store.status != .off)
                Spacer()
                Text(store.diagnostic)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 300, alignment: .trailing)
            }
        }
        .padding(24)
        .frame(minWidth: 680, minHeight: 440)
        .background(Color(nsColor: AppPalette.background))
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ProofStore

    var body: some View {
        Form {
            Section("Feasibility scope") {
                Text("App-local preview: implemented")
                Text("Pointer companion: implemented with the native pointer visible")
                Text("System-wide replacement: not established by public APIs")
            }
            Section("Privacy") {
                Text("The proof stores only the selected pack and size. It records no pointer history, typing, screenshots, or app activity.")
            }
            Button("Reset preferences") {
                store.pack = .ink
                store.pointerSize = .medium
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 320)
    }
}

struct ProofCommands: Commands {
    @ObservedObject var store: ProofStore

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Restore system pointer") { store.restore() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

@MainActor
final class ProofAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: ProofStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Octapuss Cursor Lab" }) else {
                return
            }
            window.minSize = NSSize(width: 680, height: 440)
            window.setContentSize(NSSize(width: 780, height: 520))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        return store.prepareToQuit() ? .terminateNow : .terminateCancel
    }
}

@main
struct OctapussProofApp: App {
    @NSApplicationDelegateAdaptor(ProofAppDelegate.self) private var appDelegate
    @StateObject private var store = ProofStore()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        Window("Octapuss Cursor Lab", id: "main") {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    appDelegate.store = store
                }
        }
        .defaultSize(width: 780, height: 520)
        .commands {
            ProofCommands(store: store)
        }

        MenuBarExtra("Octapuss", systemImage: "cursorarrow.rays") {
            Text(store.status.title)
            Divider()
            Button("Open Octapuss") { openWindow(id: "main") }
            Button(store.status == .companion ? "Pause companion" : "Enable pointer companion") {
                store.toggleCompanion()
            }
            Button("Restore system pointer") { store.restore() }
            Divider()
            Button("Settings…") { openSettings() }
                .keyboardShortcut(",", modifiers: .command)
            Button("Quit Octapuss") {
                if store.prepareToQuit() {
                    NSApplication.shared.terminate(nil)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
