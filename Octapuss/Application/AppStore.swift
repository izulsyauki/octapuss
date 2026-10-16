import Combine
import Foundation

/// UI-facing coordinator. Library edits and cursor runtime each have one state owner.
@MainActor
final class AppStore: ObservableObject {
    private let preferences: CursorPreferences
    private let libraryController: CursorLibraryController
    private let cursorSession: CursorSessionController
    private var subscriptions = Set<AnyCancellable>()

    @Published var pack: PointerPack {
        didSet {
            preferences.pack = pack
            libraryController.selectedImportedID = nil
        }
    }
    @Published var pointerSize: PointerSize {
        didSet { preferences.pointerSize = pointerSize }
    }
    @Published var darkPreview: Bool {
        didSet { preferences.darkPreview = darkPreview }
    }
    @Published private(set) var clickCount = 0
    @Published private(set) var diagnostic: String

    var selectedImportedID: UUID? {
        get { libraryController.selectedImportedID }
        set { libraryController.selectedImportedID = newValue }
    }
    var importedCursors: [ImportedCursor] { libraryController.importedCursors }
    var cursorCollections: [CursorCollection] { libraryController.cursorCollections }
    var selectedImportedCursor: ImportedCursor? { libraryController.selectedImportedCursor }
    var selectedCollection: CursorCollection? { libraryController.selectedCollection }
    var lastDeletedPack: CursorCollection? { libraryController.lastDeletedPack }
    var selectedTitle: String { selectedImportedCursor?.name ?? pack.title }
    var selectedPackPlan: CursorPackPlan { libraryController.selectedPackPlan }
    var appliesPack: Bool { libraryController.appliesPack }
    var applyActionTitle: String { isApplying ? "Applying…" : libraryController.applyActionTitle }

    var previewEnabled: Bool { cursorSession.previewEnabled }
    var systemApplied: Bool { cursorSession.systemApplied }
    var systemAppliedLabel: String { cursorSession.systemAppliedLabel }
    var systemAppliedAsPack: Bool { cursorSession.systemAppliedAsPack }
    var systemNeedsRecovery: Bool { cursorSession.systemNeedsRecovery }
    var systemColorOverride: Bool { cursorSession.systemColorOverride }
    var isApplying: Bool { cursorSession.isApplying }
    var applyingCursor: ImportedCursor? { cursorSession.applyingCursor }
    var statusTitle: String { cursorSession.statusTitle }
    var applyingPublisher: Published<Bool>.Publisher { cursorSession.$isApplying }

    init(defaults: UserDefaults = .standard, allowsSystemCustomization: Bool = true, libraryURL: URL? = nil,
         systemAccess: SystemCursorAccess? = nil, systemJournalURL: URL = SystemCursorSession.defaultJournalURL,
         libraryStorage: (any CursorLibraryStorage)? = nil) {
        let preferences = CursorPreferences(defaults: defaults)
        self.preferences = preferences
        pack = preferences.pack
        pointerSize = preferences.pointerSize
        darkPreview = preferences.darkPreview
        let storage: (any CursorLibraryStorage)? = libraryStorage
            ?? ((allowsSystemCustomization || libraryURL != nil) ? JSONCursorLibrary(url: libraryURL ?? JSONCursorLibrary.defaultURL) : nil)
        libraryController = CursorLibraryController(preferences: preferences, storage: storage)
        cursorSession = CursorSessionController(allowsSystemCustomization: allowsSystemCustomization,
            systemAccess: systemAccess, systemJournalURL: systemJournalURL)
        diagnostic = libraryController.diagnostic ?? cursorSession.diagnostic
        observeControllers()
    }

    private func observeControllers() {
        libraryController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &subscriptions)
        cursorSession.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &subscriptions)
        libraryController.$diagnostic.dropFirst().compactMap { $0 }.sink { [weak self] in
            self?.diagnostic = $0
        }.store(in: &subscriptions)
        cursorSession.$diagnostic.dropFirst().sink { [weak self] in
            self?.diagnostic = $0
        }.store(in: &subscriptions)
    }

    func chooseCursorFiles(asFolder: Bool = false) {
        CursorImportPanel.choose(asFolder: asFolder) { [weak self] urls in
            if asFolder, let folder = urls.first { self?.importCursorFolder(folder) }
            else { self?.importCursorFiles(urls) }
        }
    }

    func importCursorFolder(_ folder: URL) { libraryController.importCursorFolder(folder) }
    func importCursorFiles(_ urls: [URL], collectionName: String? = nil) {
        libraryController.importCursorFiles(urls, collectionName: collectionName)
    }
    func assignSelectedRole(_ choice: String) { libraryController.assignSelectedRole(choice) }
    func removeSelectedImport() { libraryController.removeSelectedImport() }
    func deleteCursorPack(id: UUID) { libraryController.deleteCursorPack(id: id) }
    func undoPackDeletion() { libraryController.undoPackDeletion() }

    func applySelectedCursor() {
        cursorSession.apply(CursorApplicationRequest(pack: pack, size: pointerSize,
            imported: selectedImportedCursor, collection: selectedCollection))
    }
    func restore() { cursorSession.restore() }
    func resumePreview() { cursorSession.resumePreview() }
    func recoverSystemPointerIfNeeded() { cursorSession.recoverSystemPointerIfNeeded() }
    func suspendSystemCursor(for reason: CursorContinuation.Suspension) { cursorSession.suspendSystemCursor(for: reason) }
    func resumeSystemCursor(after reason: CursorContinuation.Suspension) { cursorSession.resumeSystemCursor(after: reason) }
    func prepareToQuit() -> Bool { cursorSession.prepareToQuit() }

    func recordClick() {
        clickCount += 1
        diagnostic = "Boop registered. \(clickCount) successful click\(clickCount == 1 ? "" : "s")."
    }

    func resetPreferences() {
        pack = .ink
        pointerSize = .medium
        darkPreview = false
        clickCount = 0
        diagnostic = "Preferences reset. Your preview mode is unchanged."
    }
}
