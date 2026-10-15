import AppKit
import SwiftUI

// Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V4
// Native utility · genre: playful-operate · theme: DESIGN.md locked
// Structural fingerprint: pointer workbench with one dominant live preview.

enum AppPalette {
    static let ink = NSColor(srgbRed: 0.176, green: 0.141, blue: 0.251, alpha: 1)
    static let tide = NSColor(srgbRed: 0.247, green: 0.608, blue: 0.569, alpha: 1)
    static let blush = NSColor(srgbRed: 0.875, green: 0.424, blue: 0.573, alpha: 1)
    static let lavender = NSColor(srgbRed: 0.549, green: 0.420, blue: 0.847, alpha: 1)
    static let sunshine = NSColor(srgbRed: 0.957, green: 0.722, blue: 0.376, alpha: 1)
    static let pointerOutline = NSColor.white.withAlphaComponent(0.96)
    static let pointerDetail = NSColor.white.withAlphaComponent(0.8)
    static let previewLight = NSColor(srgbRed: 1, green: 0.973, blue: 0.914, alpha: 1)
    static let previewDark = NSColor(srgbRed: 0.102, green: 0.086, blue: 0.153, alpha: 1)
    static let surfaceLight = NSColor(srgbRed: 1, green: 0.992, blue: 0.973, alpha: 1)
    static let surfaceDark = NSColor(srgbRed: 0.145, green: 0.125, blue: 0.204, alpha: 1)
    static let backgroundLight = NSColor(srgbRed: 0.996, green: 0.961, blue: 0.906, alpha: 1)
    static let backgroundDark = previewDark

    static let background = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? backgroundDark
            : backgroundLight
    }

    static let surface = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? surfaceDark
            : surfaceLight
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
        case .ink: "Cozy night purple"
        case .tide: "Fresh lagoon mint"
        case .blush: "Berry-pink sparkle"
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

@MainActor
final class ProofStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var pack: PointerPack {
        didSet { defaults.set(pack.rawValue, forKey: "selectedPack") }
    }

    @Published var pointerSize: PointerSize {
        didSet { defaults.set(pointerSize.rawValue, forKey: "pointerSize") }
    }

    @Published var darkPreview: Bool {
        didSet { defaults.set(darkPreview, forKey: "darkPreview") }
    }

    @Published private(set) var previewEnabled = true
    @Published private(set) var clickCount = 0
    @Published private(set) var diagnostic = "Custom cursor inside the playground only."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pack = PointerPack(rawValue: defaults.string(forKey: "selectedPack") ?? "") ?? .ink
        pointerSize = PointerSize(rawValue: defaults.string(forKey: "pointerSize") ?? "") ?? .medium
        darkPreview = defaults.bool(forKey: "darkPreview")
    }

    var statusTitle: String {
        previewEnabled ? "App-local preview active" : "System pointer · preview paused"
    }

    func recordClick() {
        clickCount += 1
        diagnostic = "Boop registered. \(clickCount) successful click\(clickCount == 1 ? "" : "s")."
    }

    func restore() {
        previewEnabled = false
        NSCursor.arrow.set()
        diagnostic = "System pointer restored, including inside the playground."
    }

    func resumePreview() {
        previewEnabled = true
        diagnostic = "Custom cursor inside the playground only."
    }

    func resetPreferences() {
        pack = .ink
        pointerSize = .medium
        darkPreview = false
        clickCount = 0
        diagnostic = "Preferences reset. Your preview mode is unchanged."
    }

    func prepareToQuit() -> Bool {
        restore()
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

/// Owns both the cursor rectangle and native click target; no transparent hit-test overlay.
@MainActor
final class CursorPreviewNSView: NSView {
    private(set) var pack: PointerPack = .ink
    private(set) var pointerSize: PointerSize = .medium
    private(set) var customEnabled = true
    private(set) var darkPreview = false
    private(set) var clickCount = 0
    private var previewCursor: NSCursor = PointerArtwork.cursor(pack: .ink, size: 32)
    private var portrait = PointerArtwork.pointerImage(pack: .ink, size: 72)
    private var cursorTrackingArea: NSTrackingArea?
    var onClick: (() -> Void)?
    let sampleButton = NSButton(title: "Boop!", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        sampleButton.bezelStyle = .rounded
        sampleButton.target = self
        sampleButton.action = #selector(boop)
        sampleButton.setAccessibilityLabel("Boop, test pointer click")
        sampleButton.setAccessibilityHelp("Registers a click and updates the click count.")
        addSubview(sampleButton)
        setAccessibilityIdentifier("pointerPlayground")
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }

    func configure(pack: PointerPack, size: PointerSize, dark: Bool, enabled: Bool, clicks: Int) {
        let cursorChanged = self.pack != pack || pointerSize != size || customEnabled != enabled
        if self.pack != pack {
            portrait = PointerArtwork.pointerImage(pack: pack, size: 72)
        }
        self.pack = pack
        pointerSize = size
        darkPreview = dark
        customEnabled = enabled
        clickCount = clicks
        if cursorChanged {
            previewCursor = enabled ? PointerArtwork.cursor(pack: pack, size: size.points) : .arrow
            window?.invalidateCursorRects(for: self)
            if let window, window.isKeyWindow,
               visibleRect.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil)) {
                previewCursor.set()
            }
        }
        appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        needsDisplay = true
        needsLayout = true
    }

    @objc private func boop() { onClick?() }

    override func layout() {
        super.layout()
        sampleButton.frame = NSRect(x: 168, y: max(130, bounds.height - 58), width: 84, height: 30)
    }

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: previewCursor)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cursorTrackingArea { removeTrackingArea(cursorTrackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.cursorUpdate, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) { previewCursor.set() }

    override func draw(_ dirtyRect: NSRect) {
        let background = darkPreview ? AppPalette.previewDark : AppPalette.previewLight
        let foreground = darkPreview ? NSColor.white : AppPalette.ink
        let secondary = darkPreview
            ? NSColor(srgbRed: 0.78, green: 0.74, blue: 0.84, alpha: 1)
            : NSColor(srgbRed: 0.36, green: 0.31, blue: 0.43, alpha: 1)
        let outline = darkPreview ? NSColor.white.withAlphaComponent(0.18) : AppPalette.ink.withAlphaComponent(0.16)
        let surface = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14)
        background.setFill()
        surface.fill()
        outline.setStroke()
        surface.lineWidth = 1
        surface.stroke()

        let halo = NSRect(x: 22, y: (bounds.height - 112) / 2, width: 112, height: 112)
        AppPalette.sunshine.withAlphaComponent(darkPreview ? 0.18 : 0.30).setFill()
        NSBezierPath(ovalIn: halo).fill()
        portrait.draw(
            in: NSRect(x: 40, y: (bounds.height - 76) / 2, width: 76, height: 76),
            from: .zero, operation: .sourceOver, fraction: customEnabled ? 1 : 0.4,
            respectFlipped: true, hints: nil
        )

        let width = max(140, bounds.width - 190)
        drawText(customEnabled ? "Bring your pointer in" : "System pointer restored",
                 rect: NSRect(x: 168, y: 22, width: width, height: 26),
                 font: .systemFont(ofSize: 16, weight: .semibold), color: foreground)
        drawText(customEnabled
                 ? "Move here to try the real cursor. Click Boop to check its tip."
                 : "Choose Resume preview to use your custom cursor again.",
                 rect: NSRect(x: 168, y: 56, width: width, height: 66),
                 font: .systemFont(ofSize: 13), color: secondary)
        drawText(clickCount == 0 ? "Click test ready" : "\(clickCount) click\(clickCount == 1 ? "" : "s") registered",
                 rect: NSRect(x: 262, y: max(136, bounds.height - 52), width: max(100, bounds.width - 280), height: 38),
                 font: .systemFont(ofSize: 12, weight: .medium), color: secondary)
    }

    private func drawText(_ text: String, rect: NSRect, font: NSFont, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }
}

struct CursorPreviewBridge: NSViewRepresentable {
    @ObservedObject var store: ProofStore

    func makeNSView(context: Context) -> CursorPreviewNSView {
        let view = CursorPreviewNSView()
        view.setAccessibilityLabel("Pointer playground inside Octapuss")
        view.setAccessibilityHelp("Move here to try the selected cursor. Boop tests clicking.")
        return view
    }

    func updateNSView(_ view: CursorPreviewNSView, context: Context) {
        view.onClick = { store.recordClick() }
        view.configure(pack: store.pack, size: store.pointerSize, dark: store.darkPreview,
                       enabled: store.previewEnabled, clicks: store.clickCount)
    }

    static func dismantleNSView(_ view: CursorPreviewNSView, coordinator: ()) {
        view.onClick = nil
    }
}

struct OctapussMascot: View {
    var compact = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: AppPalette.sunshine).opacity(0.24))
            Image(nsImage: PointerArtwork.companionImage(pack: .blush))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(compact ? 5 : 8)
        }
        .frame(width: compact ? 34 : 58, height: compact ? 34 : 58)
        .accessibilityHidden(true)
    }
}

struct ScopeBadge: View {
    let enabled: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(nsColor: enabled ? AppPalette.tide : AppPalette.sunshine))
                .frame(width: 8, height: 8)
            Text(enabled ? "App-local preview active" : "Preview paused")
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color(nsColor: AppPalette.surface), in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08)))
        .accessibilityElement(children: .combine)
    }
}

struct CursorPreview: View {
    @ObservedObject var store: ProofStore

    var body: some View {
        CursorPreviewBridge(store: store)
            .frame(minHeight: 225)
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
        .background(
            isSelected ? Color(nsColor: pack.color).opacity(0.14) : Color.clear,
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelected ? Color(nsColor: pack.color).opacity(0.28) : Color.clear)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: ProofStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                OctapussMascot()
                VStack(alignment: .leading, spacing: 5) {
                    Text("Octapuss")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Dress up your pointer. Keep every click precise.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ScopeBadge(enabled: store.previewEnabled)
            }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pointer pals")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Pick a mood for your tiny guide.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    ForEach(PointerPack.allCases) { pack in
                        Button {
                            store.pack = pack

                        } label: {
                            PackRow(pack: pack, isSelected: store.pack == pack)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(store.pack == pack ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 184)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Pointer playground")
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
                if !store.previewEnabled {
                    Button("Resume preview") { store.resumePreview() }
                }
                Button("Settings…") { openSettings() }
                Spacer()
                HStack(spacing: 7) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color(nsColor: AppPalette.blush))
                    Text(store.diagnostic)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: 330, alignment: .trailing)
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 500)
        .background(Color(nsColor: AppPalette.background))
        .tint(Color(nsColor: AppPalette.lavender))
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ProofStore

    var body: some View {
        Form {
            Section("Octapuss scope") {
                Label("App-local pointer customization", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color(nsColor: AppPalette.tide))
                Text("The pointer changes only inside the labeled playground. No global permission is needed.")
                    .foregroundStyle(.secondary)
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
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 540, height: 430)
        .tint(Color(nsColor: AppPalette.lavender))
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
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Octapuss" }) else {
                return
            }
            window.minSize = NSSize(width: 760, height: 500)
            window.setContentSize(NSSize(width: 840, height: 560))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        return store.prepareToQuit() ? .terminateNow : .terminateCancel
    }
}

#if !OCTAPUSS_CHECKS
@main
struct OctapussProofApp: App {
    @NSApplicationDelegateAdaptor(ProofAppDelegate.self) private var appDelegate
    @StateObject private var store = ProofStore()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        Window("Octapuss", id: "main") {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    appDelegate.store = store
                }
        }
        .defaultSize(width: 840, height: 560)
        .commands {
            ProofCommands(store: store)
        }

        MenuBarExtra("Octapuss", systemImage: "cursorarrow.rays") {
            Text(store.statusTitle)
            Divider()
            Button("Open Octapuss") { openWindow(id: "main") }
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
            }
            Button(store.previewEnabled ? "Restore system pointer" : "Resume preview") {
                if store.previewEnabled { store.restore() } else { store.resumePreview() }
            }
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

#endif
