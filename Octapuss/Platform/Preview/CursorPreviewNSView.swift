import AppKit
import Combine

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
    private var importedPNG: Data?
    private var animationData: [Data] = []
    private var animationDurations: [Double] = []
    private var animationCursors: [NSCursor] = []
    private var animationPortraits: [NSImage] = []
    private var animationTimer: Timer?
    private var animationObservers = Set<AnyCancellable>()
    var isAnimationRunning: Bool { animationTimer != nil }
    private var animationStartedAt = 0.0
    private var animationIndex = 0

    func configure(pack: PointerPack, size: PointerSize, dark: Bool, enabled: Bool, clicks: Int, imported: ImportedCursor? = nil) {
        let nextFrames = imported?.animation?.frames ?? []
        let nextDurations = imported?.animation?.durations ?? []
        let artworkChanged = self.pack != pack || importedID != imported?.id || importedPNG != imported?.png
            || animationData != nextFrames || animationDurations != nextDurations
        let cursorChanged = artworkChanged || pointerSize != size || customEnabled != enabled
        if artworkChanged {
            portrait = imported?.image(longestSide: 72) ?? PointerArtwork.pointerImage(pack: pack, size: 72)
        }
        importedID = imported?.id
        importedPNG = imported?.png
        animationData = nextFrames
        animationDurations = nextDurations
        self.pack = pack
        pointerSize = size
        darkPreview = dark
        customEnabled = enabled
        clickCount = clicks
        if cursorChanged {
            stopAnimation()
            animationIndex = 0
            animationCursors = []
            animationPortraits = []
            if let imported, !nextFrames.isEmpty {
                for png in nextFrames {
                    // Frame metadata is fixed by the decoder; only the artwork changes.
                    let pointerImage = NSImage(data: png)!
                    let factor = size.points / CGFloat(max(imported.width, imported.height))
                    pointerImage.size = NSSize(width: CGFloat(imported.width) * factor, height: CGFloat(imported.height) * factor)
                    animationCursors.append(NSCursor(image: pointerImage,
                        hotSpot: NSPoint(x: CGFloat(imported.hotspotX) * factor, y: CGFloat(imported.hotspotY) * factor)))
                    let portraitImage = NSImage(data: png)!
                    let portraitFactor = 72 / CGFloat(max(imported.width, imported.height))
                    portraitImage.size = NSSize(width: CGFloat(imported.width) * portraitFactor, height: CGFloat(imported.height) * portraitFactor)
                    animationPortraits.append(portraitImage)
                }
            }
            previewCursor = enabled ? (imported?.cursor(longestSide: size.points) ?? PointerArtwork.cursor(pack: pack, size: size.points)) : .arrow
            window?.invalidateCursorRects(for: self)
            if pointerIsInsidePreview {
                previewCursor.set()
            }
            startAnimationIfNeeded()
        }
        appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        needsDisplay = true
        needsLayout = true
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopAnimation()
        animationObservers.removeAll()
        guard window != nil else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                     NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
                     NSWindow.didChangeOcclusionStateNotification] {
            NotificationCenter.default.publisher(for: name)
                .sink { [weak self] notification in
                    guard let self, notification.object as? NSWindow === self.window else { return }
                    self.refreshAnimation()
                }
                .store(in: &animationObservers)
        }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAnimation() }
            .store(in: &animationObservers)
        startAnimationIfNeeded()
    }

    override func viewDidHide() {
        super.viewDidHide()
        stopAnimation()
        releasePreviewCursor(in: window)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window { releasePreviewCursor(in: window) }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        startAnimationIfNeeded()
    }

    private func refreshAnimation() {
        stopAnimation()
        startAnimationIfNeeded()
    }

    deinit { animationTimer?.invalidate() }

    private func startAnimationIfNeeded() {
        guard animationTimer == nil, customEnabled, let window, window.isKeyWindow,
              window.isVisible, !window.isMiniaturized, window.occlusionState.contains(.visible),
              !isHiddenOrHasHiddenAncestor, animationCursors.count > 1,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        animationStartedAt = Date.timeIntervalSinceReferenceDate
        let timer = Timer(timeInterval: max(1.0 / 60, min(animationDurations.min() ?? 0.1, 0.1)), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advanceAnimation() }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func advanceAnimation() {
        guard let window, window.isKeyWindow, customEnabled, !isHiddenOrHasHiddenAncestor,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let total = animationDurations.reduce(0, +)
        guard total > 0 else { return }
        let time = (Date.timeIntervalSinceReferenceDate - animationStartedAt).truncatingRemainder(dividingBy: total)
        var index = 0
        var end = animationDurations[0]
        while index + 1 < animationDurations.count && time >= end { index += 1; end += animationDurations[index] }
        guard index != animationIndex else { return }
        animationIndex = index
        previewCursor = animationCursors[index]
        portrait = animationPortraits[index]
        needsDisplay = true
        window.invalidateCursorRects(for: self)
        if pointerIsInsidePreview { previewCursor.set() }
    }

    @objc private func boop() { onClick?() }

    override func layout() {
        super.layout()
        sampleButton.frame = NSRect(x: 168, y: max(130, bounds.height - 58), width: 84, height: 30)
    }

    override func resetCursorRects() {
        let rect = previewCursorRect
        guard !rect.isEmpty else { return }
        addCursorRect(rect, cursor: previewCursor)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cursorTrackingArea { removeTrackingArea(cursorTrackingArea) }
        cursorTrackingArea = nil
        let rect = previewCursorRect
        guard !rect.isEmpty else { return }
        let area = NSTrackingArea(
            rect: rect,
            options: [.cursorUpdate, .mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    private var previewCursorRect: NSRect {
        let rect = bounds.intersection(visibleRect)
        return rect.isNull || rect.isEmpty ? .zero : rect
    }

    private var pointerIsInsidePreview: Bool {
        guard let window, window.isKeyWindow, window.isVisible,
              !isHiddenOrHasHiddenAncestor else { return false }
        return previewCursorRect.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    private func releasePreviewCursor(in window: NSWindow?) {
        // Only replace artwork owned by this preview, while still in this window.
        // Another app or a text field may already have selected its own cursor.
        guard let window, window.isKeyWindow, window.isVisible,
              let content = window.contentView,
              content.bounds.contains(content.convert(window.mouseLocationOutsideOfEventStream, from: nil)),
              NSCursor.current === previewCursor || animationCursors.contains(where: { $0 === NSCursor.current }) else { return }
        NSCursor.arrow.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        if pointerIsInsidePreview { previewCursor.set() }
    }

    override func mouseExited(with event: NSEvent) {
        releasePreviewCursor(in: window)
        super.mouseExited(with: event)
    }

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
