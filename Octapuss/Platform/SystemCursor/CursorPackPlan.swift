import Foundation

struct CursorPackPlan {
    let cursors: [ImportedCursor]
    var mapped: [ImportedCursor] { cursors.filter { !$0.targetSlotNames.isEmpty } }
    var unmapped: [ImportedCursor] { cursors.filter { $0.targetSlotNames.isEmpty } }

    func replacements(using api: SystemCursorAccess, size: CGFloat) throws -> (snapshots: [CursorSnapshot], roleCount: Int, unavailable: [String]) {
        guard !mapped.isEmpty else { throw CursorImportError.invalid("No system roles are assigned. Choose a role for each cursor, then Apply pack.") }
        let groups = Dictionary(grouping: mapped, by: { $0.effectiveRole! })
        if let duplicate = groups.first(where: { group in
            let names = group.value.flatMap(\.targetSlotNames)
            return names.count != Set(names).count
        }) {
            throw CursorImportError.invalid("Two cursors use \(duplicate.key.title). Assign distinct roles before applying this pack.")
        }
        let requested = Set(mapped.flatMap(\.targetSlotNames)).sorted()
        let available = Set(try api.readAvailable(requested).map(\.name))
        var snapshots: [CursorSnapshot] = []
        var unavailable: [String] = []
        var roles = Set<CursorRole>()
        var owners: [String: UUID] = [:]
        // Keep arrow aliases last; registration itself does not select a live role.
        for cursor in mapped.sorted(by: { ($0.effectiveRole == .arrow ? 1 : 0) < ($1.effectiveRole == .arrow ? 1 : 0) }) {
            let names = cursor.targetSlotNames.filter { available.contains($0) }
            if names.isEmpty { unavailable.append(cursor.effectiveRole!.title); continue }
            roles.insert(cursor.effectiveRole!)
            for name in names {
                if owners[name] != nil {
                    throw CursorImportError.invalid("Two assigned roles share the macOS slot \(name). Unassign one before applying.")
                }
                owners[name] = cursor.id
                snapshots.append(try cursor.snapshot(name: name, longestSide: size))
            }
        }
        guard !snapshots.isEmpty else { throw CursorImportError.invalid("No mapped cursor slots are available in this macOS session. Nothing was applied.") }
        return (snapshots, roles.count, unavailable)
    }
}
