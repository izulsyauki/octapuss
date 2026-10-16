import Foundation
import Combine

/// Publishes library edits only after storage accepts them. Original downloads are never removed.
@MainActor
final class CursorLibraryController: ObservableObject {
    private let preferences: CursorPreferences
    @Published private(set) var diagnostic: String?
    @Published private(set) var importedCursors: [ImportedCursor] = []
    @Published private(set) var lastDeletedPack: CursorCollection?
    private var deletedPackSelection: UUID?
    @Published var selectedImportedID: UUID? {
        didSet { preferences.selectedImportedID = selectedImportedID }
    }
    private var storage: (any CursorLibraryStorage)?
    var selectedImportedCursor: ImportedCursor? { importedCursors.first { $0.id == selectedImportedID } }
    var selectedTitle: String { selectedImportedCursor?.name ?? "Imported set" }
    var cursorCollections: [CursorCollection] {
        Dictionary(grouping: importedCursors, by: \.setID).map { id, items in
            CursorCollection(id: id, name: items.first?.collectionName ?? items.first?.name ?? "Imported set",
                             cursors: items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var selectedCollection: CursorCollection? {
        guard let selected = selectedImportedCursor else { return nil }
        return cursorCollections.first { $0.id == selected.setID }
    }
    var appliesPack: Bool {
        guard let set = selectedCollection else { return false }
        return set.cursors.count > 1 || set.cursors.first?.effectiveRole != nil
    }
    var applyActionTitle: String { appliesPack ? "Apply pack" : "Apply system arrow" }
    var selectedPackPlan: CursorPackPlan { CursorPackPlan(cursors: selectedCollection?.cursors ?? []) }

    init(preferences: CursorPreferences, storage: (any CursorLibraryStorage)?) {
        self.preferences = preferences
        guard let storage else { return }
        do {
            importedCursors = try storage.load()
            selectedImportedID = preferences.selectedImportedID
            if selectedImportedCursor == nil { selectedImportedID = nil }
            self.storage = storage
        } catch { diagnostic = error.localizedDescription }
    }

    func assignSelectedRole(_ choice: String) {
        guard let id = selectedImportedID, let storage,
              choice == "unassigned" || CursorRole(rawValue: choice) != nil else { return }
        do {
            var next = importedCursors
            guard let index = next.firstIndex(where: { $0.id == id }) else { return }
            next[index].roleOverride = choice
            try storage.save(next)
            importedCursors = next
            diagnostic = "Role saved. Apply pack when your mappings are ready."
        } catch { diagnostic = "The role could not be saved: \(error.localizedDescription)" }
    }

    func importCursorFolder(_ folder: URL) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            let files = try contents.filter {
                guard ["cur", "ani"].contains($0.pathExtension.lowercased()) else { return false }
                return try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            guard !files.isEmpty else {
                diagnostic = "No .cur or .ani files in this folder. Choose the unzipped folder containing the cursor files."
                return
            }
            importCursorFiles(files, collectionName: folder.lastPathComponent)
        } catch { diagnostic = "The cursor folder could not be opened: \(error.localizedDescription)" }
    }

    func importCursorFiles(_ urls: [URL], collectionName: String? = nil) {
        guard let storage else {
            diagnostic = "Your saved cursor library is unavailable. Your downloads have not been changed."
            return
        }
        guard urls.count <= 64 else {
            diagnostic = "Import up to 64 cursor files at a time. Unzip sets first."
            return
        }
        if urls.contains(where: { $0.pathExtension.lowercased() == "cursor" }) {
            guard urls.count == 1 else {
                diagnostic = "Import one .cursor theme at a time, separately from CUR/ANI files."
                return
            }
            do {
                let theme = try CursorFileDecoder.decodeTheme(url: urls[0])
                let candidates = cursorCollections.filter {
                    $0.name == theme.name && $0.cursors.map(\.name).sorted() == theme.cursors.map(\.name).sorted()
                }
                let existing = candidates.count == 1 ? candidates.first : nil
                let groupID = existing?.id ?? UUID()
                var next = importedCursors.filter { $0.setID != existing?.id }
                let imported = theme.cursors.map { item -> ImportedCursor in
                    var cursor = item
                    cursor.collectionID = groupID
                    cursor.collectionName = theme.name
                    if let old = existing?.cursors.first(where: { $0.name == cursor.name }) {
                        cursor.id = old.id
                        cursor.roleOverride = old.roleOverride
                    }
                    return cursor
                }
                next.append(contentsOf: imported)
                try storage.save(next)
                importedCursors = next
                selectedImportedID = imported.first(where: { $0.effectiveRole == .arrow })?.id ?? imported.first?.id
                diagnostic = "\(theme.name) imported: \(imported.count) cursors. Preview, then choose Apply pack."
            } catch { diagnostic = "Theme import was not saved: \(error.localizedDescription)" }
            return
        }
        let grouped = urls.count > 1 || collectionName != nil
        let groupName = collectionName ?? urls.first?.deletingLastPathComponent().lastPathComponent ?? "Imported set"
        let incomingNames = urls.map { String($0.deletingPathExtension().lastPathComponent.prefix(100)) }.sorted()
        let candidates = cursorCollections.filter { $0.name == groupName && $0.cursors.map(\.name).sorted() == incomingNames }
        let existing = grouped && candidates.count == 1 && Set(incomingNames).count == incomingNames.count ? candidates.first : nil
        let groupID = existing?.id ?? (grouped ? UUID() : nil)
        var next = importedCursors
        var chosen: UUID?
        var errors: [String] = []
        for url in urls {
            do {
                var cursor = try CursorFileDecoder.decode(url: url)
                cursor.collectionID = groupID
                cursor.collectionName = grouped ? String(groupName.prefix(100)) : nil
                if let old = existing?.cursors.first(where: { $0.name == cursor.name }),
                   let index = next.firstIndex(where: { $0.id == old.id }) {
                    cursor.id = old.id
                    cursor.roleOverride = old.roleOverride
                    next[index] = cursor
                    chosen = chosen ?? cursor.id
                    continue
                }
                if !grouped, let duplicate = next.first(where: {
                    $0.png == cursor.png && $0.hotspotX == cursor.hotspotX && $0.hotspotY == cursor.hotspotY
                        && $0.firstFrameOnly == cursor.firstFrameOnly
                }) { chosen = chosen ?? duplicate.id }
                else { next.append(cursor); chosen = chosen ?? cursor.id }
            } catch { errors.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        do {
            if chosen != nil {
                try storage.save(next)
                importedCursors = next
                selectedImportedID = chosen
                diagnostic = "\(selectedTitle) is ready to preview. Choose \(applyActionTitle) to use it outside Octapuss."
            }
            if let first = errors.first { diagnostic = "\(errors.count) file(s) could not be imported. \(first)" }
        } catch { diagnostic = "Import was not saved: \(error.localizedDescription)" }
    }

    func removeSelectedImport() {
        guard let id = selectedImportedID, let storage else { return }
        do {
            let next = importedCursors.filter { $0.id != id }
            try storage.save(next)
            let setID = selectedImportedCursor?.setID
            importedCursors = next
            selectedImportedID = next.first { $0.setID == setID }?.id
            diagnostic = "Removed from your library. The applied cursor and original download are unchanged."
        } catch { diagnostic = error.localizedDescription }
    }

    func deleteCursorPack(id: UUID) {
        guard let storage, let collection = cursorCollections.first(where: { $0.id == id }) else { return }
        let next = importedCursors.filter { $0.setID != id }
        let deletedSelection = collection.cursors.contains { $0.id == selectedImportedID } ? selectedImportedID : nil
        do {
            try storage.save(next)
            lastDeletedPack = collection
            deletedPackSelection = deletedSelection
            importedCursors = next
            if deletedSelection != nil {
                selectedImportedID = cursorCollections.first?.cursors.first?.id
            }
            diagnostic = "Deleted “\(collection.name)” from your library. Your applied cursor and original files are unchanged."
        } catch {
            diagnostic = "The pack could not be deleted: \(error.localizedDescription). Your library is unchanged."
        }
    }

    func undoPackDeletion() {
        guard let storage, let deleted = lastDeletedPack else { return }
        let existingIDs = Set(importedCursors.map(\.id))
        let next = importedCursors + deleted.cursors.filter { !existingIDs.contains($0.id) }
        do {
            try storage.save(next)
            importedCursors = next
            if let selection = deletedPackSelection { selectedImportedID = selection }
            lastDeletedPack = nil
            deletedPackSelection = nil
            diagnostic = "“\(deleted.name)” is back in your library. Your applied cursor is unchanged."
        } catch {
            diagnostic = "The pack could not be restored: \(error.localizedDescription). Undo is still available."
        }
    }

}
