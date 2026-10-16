import AppKit
import Combine

/// Owns Apply, cancellation, restoration and suspension intent independently of library browsing.
@MainActor
final class CursorSessionController: ObservableObject {
    private let allowsSystemCustomization: Bool
    @Published private(set) var previewEnabled = true
    @Published private(set) var diagnostic = "Custom cursor inside the playground only."
    @Published private(set) var systemApplied = false
    @Published private(set) var systemAppliedLabel = ""
    @Published private(set) var systemAppliedAsPack = false
    @Published private(set) var systemNeedsRecovery = false
    @Published private(set) var systemColorOverride = false
    private var systemSession: SystemCursorSession?
    private let systemAccessOverride: SystemCursorAccess?
    @Published private(set) var isApplying = false
    @Published private(set) var applyingCursor: ImportedCursor?
    private var applyingName = ""
    private var cancelApplyRequested = false
    private var applyTask: Task<Void, Never>?
    private var cursorContinuation = CursorContinuation()
    private var resumeTask: Task<Void, Never>?
    private var recoveredOnLaunch = false

    init(allowsSystemCustomization: Bool, systemAccess: SystemCursorAccess? = nil,
         systemJournalURL: URL = SystemCursorSession.defaultJournalURL) {
        self.allowsSystemCustomization = allowsSystemCustomization
        systemAccessOverride = systemAccess
        if let systemAccess {
            systemSession = SystemCursorSession(api: systemAccess, journalURL: systemJournalURL)
        }
        systemColorOverride = allowsSystemCustomization && PointerColorCompatibility.hasOverride()
        if systemColorOverride {
            diagnostic = "macOS pointer colors override themes. In System Settings > Accessibility > Display > Pointer, choose Reset Colors, then Apply."
        }
    }

    var statusTitle: String {
        if isApplying { return cancelApplyRequested ? "Restoring pointer…" : "Applying \(applyingName)…" }
        if systemNeedsRecovery { return "System restoration needed" }
        if systemColorOverride { return "Pointer color override" }
        if systemApplied { return "System \(systemAppliedAsPack ? "pack" : "arrow"): \(systemAppliedLabel)" }
        return previewEnabled ? "App-local preview active" : "System pointer · preview paused"
    }

    func recoverSystemPointerIfNeeded() {
        guard allowsSystemCustomization else { return }
        guard !recoveredOnLaunch else { return }
        recoveredOnLaunch = true
        guard FileManager.default.fileExists(atPath: SystemCursorSession.defaultJournalURL.path) else { return }
        restore()
    }

    func apply(_ request: CursorApplicationRequest) {
        guard !isApplying, allowsSystemCustomization || systemAccessOverride != nil else { return }
        systemColorOverride = systemAccessOverride == nil && PointerColorCompatibility.hasOverride()
        guard !systemColorOverride else {
            diagnostic = "macOS pointer colors override themes. In System Settings > Accessibility > Display > Pointer, choose Reset Colors, then Apply."
            return
        }
        let plan = request.plan
        let size = request.size
        let title = request.title
        let label = request.label
        let override = systemAccessOverride
        do {
            if systemSession == nil { systemSession = try SystemCursorSession(api: SystemCursorAPI()) }
            guard let session = systemSession else { return }
            let fallback = try request.arrowSnapshots()
            applyingName = title
            applyingCursor = plan?.mapped.first { $0.effectiveRole == .busy }
                ?? plan?.mapped.first { $0.effectiveRole == .working }
            cancelApplyRequested = false
            isApplying = true
            diagnostic = "Applying \(title). You can cancel and restore your pointer."
            resumeTask?.cancel()
            resumeTask = nil
            applyTask = Task { [self] in
                defer {
                    applyingCursor = nil
                    applyTask = nil
                    isApplying = false
                }
                var transactionStarted = false
                do {
                    let result = try await Task.detached(priority: .userInitiated) {
                        if let plan {
                            let api: SystemCursorAccess
                            if let override { api = override } else { api = try SystemCursorAPI() }
                            return try plan.replacements(using: api, size: size.points)
                        }
                        return (snapshots: fallback, roleCount: 0, unavailable: [String]())
                    }.value
                    try Task.checkCancellation()
                    cursorContinuation.cancel()
                    transactionStarted = true
                    systemApplied = false
                    try await session.replaceAsync(result.snapshots, startWatchdog: override == nil)
                    try Task.checkCancellation()
                    cursorContinuation.applied(result.snapshots)
                    systemApplied = true
                    previewEnabled = true
                    systemAppliedAsPack = plan != nil
                    systemAppliedLabel = plan == nil ? label : "\(title) · \(result.roleCount) roles"
                    systemNeedsRecovery = false
                    if let plan {
                        let skipped = plan.unmapped.count + result.unavailable.count
                        diagnostic = "Pack applied: \(result.roleCount) roles across \(result.snapshots.count) system slots."
                            + (skipped > 0 ? " \(skipped) files/roles have no matching system slot; they remain unchanged." : "")
                    } else { diagnostic = "System arrow applied. Import a named cursor set to customize other roles." }
                } catch {
                    if cancelApplyRequested || Task.isCancelled {
                        do {
                            try await session.restoreAsync()
                            systemApplied = false
                            systemNeedsRecovery = false
                            previewEnabled = false
                            diagnostic = "Cursor change cancelled. System pointer restored."
                        } catch {
                            systemNeedsRecovery = true
                            diagnostic = "Restoration incomplete: \(error.localizedDescription)"
                        }
                    } else {
                        if transactionStarted { systemNeedsRecovery = session.hasPendingRecovery }
                        diagnostic = error.localizedDescription
                    }
                }
            }
        } catch { diagnostic = error.localizedDescription }
    }

    func restore() {
        resumeTask?.cancel()
        resumeTask = nil
        cursorContinuation.cancel()
        if isApplying {
            cancelApplyRequested = true
            applyTask?.cancel()
            previewEnabled = false
            diagnostic = "Finishing the current registration step, then restoring your pointer…"
            return
        }
        restoreRegistrations()
    }

    private func restoreRegistrations() {
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

    func suspendSystemCursor(for reason: CursorContinuation.Suspension) {
        if isApplying {
            _ = cursorContinuation.suspend(reason)
            restore()
            return
        }
        resumeTask?.cancel()
        resumeTask = nil
        let shouldRestore = cursorContinuation.suspend(reason)
        guard shouldRestore else { return }
        let wasPreviewEnabled = previewEnabled
        restoreRegistrations()
        previewEnabled = wasPreviewEnabled
        if !systemNeedsRecovery { diagnostic = "Your applied cursor will resume when you return." }
    }

    func resumeSystemCursor(after reason: CursorContinuation.Suspension) {
        cursorContinuation.returned(reason)
        guard cursorContinuation.canResume else { return }
        resumeTask?.cancel()
        // Let WindowServer finish restoring the user session before registering artwork.
        resumeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled, let self else { return }
            self.reapplyRememberedCursor()
        }
    }

    private func reapplyRememberedCursor() {
        guard !isApplying, cursorContinuation.canResume, let session = systemSession else { return }
        systemColorOverride = PointerColorCompatibility.hasOverride()
        guard !systemColorOverride else {
            diagnostic = "Your cursor could not resume because macOS pointer colors override themes. Reset Colors, then Apply again."
            return
        }
        do {
            try session.prepareForApplication()
            try session.apply(cursorContinuation.snapshots)
            cursorContinuation.didResume()
            systemApplied = true
            systemNeedsRecovery = false
            diagnostic = "Your applied cursor resumed. Restore system pointer turns it off."
        } catch {
            systemApplied = false
            systemNeedsRecovery = session.hasPendingRecovery
            diagnostic = "Your cursor could not resume: \(error.localizedDescription). Choose Apply to try again."
        }
    }

    func resumePreview() {
        previewEnabled = true
        diagnostic = "Custom cursor inside the playground only."
    }

    func prepareToQuit() -> Bool {
        restore()
        return !isApplying && !systemNeedsRecovery
    }

}
