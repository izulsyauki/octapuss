import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
    private let allowsSystemCustomization: Bool

    @Published var pack: PointerPack {
        didSet {
            defaults.set(pack.rawValue, forKey: "selectedPack")
            selectedImportedID = nil
        }
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
    @Published private(set) var systemApplied = false
    @Published private(set) var systemAppliedLabel = ""
    @Published private(set) var systemNeedsRecovery = false
    @Published private(set) var systemColorOverride = false
    private var systemSession: SystemCursorSession?
    private var recoveredOnLaunch = false
    @Published private(set) var importedCursors: [ImportedCursor] = []
    @Published var selectedImportedID: UUID? {
        didSet { defaults.set(selectedImportedID?.uuidString, forKey: "selectedImportedCursor") }
    }
    private var library: CursorLibrary?
    var selectedImportedCursor: ImportedCursor? { importedCursors.first { $0.id == selectedImportedID } }
    var selectedTitle: String { selectedImportedCursor?.name ?? pack.title }

    init(defaults: UserDefaults = .standard, allowsSystemCustomization: Bool = true, libraryURL: URL? = nil) {
        self.defaults = defaults
        self.allowsSystemCustomization = allowsSystemCustomization
        pack = PointerPack(rawValue: defaults.string(forKey: "selectedPack") ?? "") ?? .ink
        pointerSize = PointerSize(rawValue: defaults.string(forKey: "pointerSize") ?? "") ?? .medium
        darkPreview = defaults.bool(forKey: "darkPreview")
        systemColorOverride = allowsSystemCustomization && PointerColorCompatibility.hasOverride()
        if systemColorOverride {
            diagnostic = "macOS pointer colors override themes. In System Settings > Accessibility > Display > Pointer, choose Reset Colors, then Apply."
        }
        if allowsSystemCustomization || libraryURL != nil {
            let candidate = CursorLibrary(url: libraryURL ?? CursorLibrary.defaultURL)
            do {
                importedCursors = try candidate.load()
                selectedImportedID = UUID(uuidString: defaults.string(forKey: "selectedImportedCursor") ?? "")
                if selectedImportedCursor == nil { selectedImportedID = nil }
                library = candidate
            } catch { diagnostic = error.localizedDescription }
        }
    }

    func chooseCursorFiles() {
        let panel = NSOpenPanel()
        panel.title = "Import cursor files"
        panel.message = "Choose .cur or .ani files. Unzip downloaded sets first. Animated cursors use their first frame."
        panel.prompt = "Import"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "cur"), UTType(filenameExtension: "ani")].compactMap { $0 }
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.importCursorFiles(panel.urls)
        }
    }

    func importCursorFiles(_ urls: [URL]) {
        guard let library else {
            diagnostic = "Your saved cursor library is unavailable. Your downloads have not been changed."
            return
        }
        guard urls.count <= 16 else {
            diagnostic = "Import up to 16 cursor files at a time. Unzip sets first."
            return
        }
        var next = importedCursors
        var chosen: UUID?
        var errors: [String] = []
        for url in urls {
            do {
                let cursor = try CursorFileDecoder.decode(url: url)
                if let duplicate = next.first(where: {
                    $0.png == cursor.png && $0.hotspotX == cursor.hotspotX && $0.hotspotY == cursor.hotspotY
                        && $0.firstFrameOnly == cursor.firstFrameOnly
                }) { chosen = chosen ?? duplicate.id }
                else { next.append(cursor); chosen = chosen ?? cursor.id }
            } catch { errors.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        do {
            if chosen != nil {
                try library.save(next)
                importedCursors = next
                selectedImportedID = chosen
                diagnostic = "\(selectedTitle) is ready to preview. Choose Apply system arrow to use it outside Octapuss."
            }
            if let first = errors.first { diagnostic = "\(errors.count) file(s) could not be imported. \(first)" }
        } catch { diagnostic = "Import was not saved: \(error.localizedDescription)" }
    }

    func removeSelectedImport() {
        guard let id = selectedImportedID, let library else { return }
        do {
            let next = importedCursors.filter { $0.id != id }
            try library.save(next)
            importedCursors = next
            selectedImportedID = nil
            diagnostic = "Removed from your library. The applied system arrow and original download are unchanged."
        } catch { diagnostic = error.localizedDescription }
    }

    var statusTitle: String {
        if systemNeedsRecovery { return "System restoration needed" }
        if systemColorOverride { return "Pointer color override" }
        if systemApplied { return "System arrow: \(systemAppliedLabel)" }
        return previewEnabled ? "App-local preview active" : "System pointer · preview paused"
    }

    func recoverSystemPointerIfNeeded() {
        guard allowsSystemCustomization else { return }
        guard !recoveredOnLaunch else { return }
        recoveredOnLaunch = true
        guard FileManager.default.fileExists(atPath: SystemCursorSession.defaultJournalURL.path) else { return }
        restore()
    }

    func applySystemArrow() {
        guard allowsSystemCustomization else { return }
        systemColorOverride = PointerColorCompatibility.hasOverride()
        guard !systemColorOverride else {
            diagnostic = "macOS pointer colors override themes. In System Settings > Accessibility > Display > Pointer, choose Reset Colors, then Apply."
            return
        }
        do {
            if systemSession == nil { systemSession = try SystemCursorSession(api: SystemCursorAPI()) }
            guard let session = systemSession else { return }
            try session.prepareForApplication()
            systemApplied = false
            let names = ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS"]
            var replacements: [CursorSnapshot] = []
            for name in names {
                // ArrowS is required on the host macOS 26. Older systems may omit it.
                if name.hasSuffix("ArrowS"), ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26 {
                    continue
                }
                if let imported = selectedImportedCursor {
                    replacements.append(try imported.snapshot(name: name, longestSide: pointerSize.points))
                    continue
                }
                let images = try [1.0, 2.0, 5.0, 10.0].map { scale -> Data in
                    let image = PointerArtwork.pointerImage(pack: pack, size: pointerSize.points * scale)
                    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                          let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
                        throw CursorSystemError.invalidBaseline
                    }
                    return png
                }
                replacements.append(CursorSnapshot(name: name, width: pointerSize.points, height: pointerSize.points,
                                                   x: pointerSize.points / 16, y: pointerSize.points / 16,
                                                   frames: 1, duration: 0, images: images))
            }
            try session.apply(replacements)
            systemApplied = true
            previewEnabled = true
            systemAppliedLabel = "\(selectedTitle) · \(pointerSize.title)"
            systemNeedsRecovery = false
            diagnostic = "System arrow applied. Text, hand, and resize cursors stay native."
        } catch {
            systemNeedsRecovery = systemSession?.hasPendingRecovery ?? false
            diagnostic = error.localizedDescription
        }
    }

    func recordClick() {
        clickCount += 1
        diagnostic = "Boop registered. \(clickCount) successful click\(clickCount == 1 ? "" : "s")."
    }

    func restore() {
        previewEnabled = false
        NSCursor.arrow.set()
        do {
            if allowsSystemCustomization, systemSession == nil,
               FileManager.default.fileExists(atPath: SystemCursorSession.defaultJournalURL.path) {
                systemSession = try SystemCursorSession(api: SystemCursorAPI())
            }
            try systemSession?.restore()
            systemApplied = false
            systemNeedsRecovery = false
            diagnostic = "System pointer restored, including inside the playground."
        } catch {
            systemNeedsRecovery = true
            diagnostic = "Restoration incomplete: \(error.localizedDescription)"
        }
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
        return !systemNeedsRecovery
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

    private var importedID: UUID?

    func configure(pack: PointerPack, size: PointerSize, dark: Bool, enabled: Bool, clicks: Int, imported: ImportedCursor? = nil) {
        let artworkChanged = self.pack != pack || importedID != imported?.id
        let cursorChanged = artworkChanged || pointerSize != size || customEnabled != enabled
        if artworkChanged {
            portrait = imported?.image(longestSide: 72) ?? PointerArtwork.pointerImage(pack: pack, size: 72)
        }
        importedID = imported?.id
        self.pack = pack
        pointerSize = size
        darkPreview = dark
        customEnabled = enabled
        clickCount = clicks
        if cursorChanged {
            previewCursor = enabled ? (imported?.cursor(longestSide: size.points) ?? PointerArtwork.cursor(pack: pack, size: size.points)) : .arrow
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
        let portraitScale = 76 / max(portrait.size.width, portrait.size.height)
        let portraitSize = NSSize(width: portrait.size.width * portraitScale, height: portrait.size.height * portraitScale)
        portrait.draw(
            in: NSRect(x: 78 - portraitSize.width / 2, y: (bounds.height - portraitSize.height) / 2,
                       width: portraitSize.width, height: portraitSize.height),
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
                       enabled: store.previewEnabled, clicks: store.clickCount, imported: store.selectedImportedCursor)
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
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(nsColor: enabled ? AppPalette.tide : AppPalette.sunshine))
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(title)
        }
        .frame(maxWidth: 260, alignment: .trailing)
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
        VStack(spacing: 0) {
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
                ScopeBadge(enabled: store.systemApplied || store.previewEnabled, title: store.statusTitle)
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
                            PackRow(pack: pack, isSelected: store.selectedImportedID == nil && store.pack == pack)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(store.selectedImportedID == nil && store.pack == pack ? .isSelected : [])
                    }
                    Divider().padding(.vertical, 4)
                    HStack {
                        Text("Your cursors").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Button { store.chooseCursorFiles() } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Import cursor files")
                    }
                    if store.importedCursors.isEmpty {
                        Text("Bring a new pal from the web.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Button("Import cursor…") { store.chooseCursorFiles() }
                    } else {
                        Picker("Imported cursor", selection: $store.selectedImportedID) {
                            Text("Choose a cursor").tag(nil as UUID?)
                            ForEach(store.importedCursors) { cursor in
                                Text(cursor.name).tag(Optional(cursor.id))
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Imported cursor")
                        if let cursor = store.selectedImportedCursor {
                            HStack {
                                Image(nsImage: cursor.image(longestSide: 28))
                                Text(cursor.name).font(.system(size: 12, weight: .medium))
                                    .lineLimit(2).help(cursor.name)
                            }
                            if cursor.firstFrameOnly {
                                Text("ANI · first frame only").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Button("Remove from library") { store.removeSelectedImport() }
                                .font(.system(size: 11))
                        }
                    }
                    Text(".cur · .ani (first frame)\nUnzip sets before importing.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Link("Find cursors on the web", destination: URL(string: "https://www.rw-designer.com/cursor-library")!)
                        .font(.system(size: 11))
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

        }
        .padding(24)
        }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Button("Apply system arrow") { store.applySystemArrow() }
                    .buttonStyle(.borderedProminent)
                Button("Restore system pointer") { store.restore() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                if !store.previewEnabled {
                    Button("Resume preview") { store.resumePreview() }
                }
                Button("Settings…") { openSettings() }
                Spacer()
            }
                HStack(spacing: 7) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color(nsColor: AppPalette.blush))
                    Text(store.diagnostic)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(Color(nsColor: AppPalette.background))
        .tint(Color(nsColor: AppPalette.lavender))
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ProofStore

    var body: some View {
        Form {
            Section("System customization") {
                Label(store.statusTitle, systemImage: "cursorarrow")
                    .foregroundStyle(Color(nsColor: AppPalette.tide))
                Text("Apply system arrow changes the registered macOS arrow, including outside Octapuss. App-drawn and protected cursors can differ. Text, hand, and resize cursors remain native.")
                    .foregroundStyle(.secondary)
                Button("Apply selected system arrow") { store.applySystemArrow() }
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
                    store.recoverSystemPointerIfNeeded()
                }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in
                    store.restore()
                }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in
                    store.restore()
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
            Button("Apply system arrow") { store.applySystemArrow() }
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
            Button("Restore system pointer") { store.restore() }
            if !store.previewEnabled {
                Button("Resume local preview") { store.resumePreview() }
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

@main
enum OctapussEntry {
    @MainActor
    static func main() {
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--cursor-read-many" {
            exit(SystemCursorAPI.runReader(names: CommandLine.arguments[2]))
        }
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--cursor-watchdog",
           let sessionID = UUID(uuidString: CommandLine.arguments[3]) {
            exit(SystemCursorSession.runWatchdog(path: CommandLine.arguments[2], sessionID: sessionID))
        }
        OctapussProofApp.main()
    }
}
#endif
