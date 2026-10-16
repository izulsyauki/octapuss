import Foundation

/// A value captured before async work starts; later selection changes cannot alter an Apply.
struct CursorApplicationRequest {
    let pack: PointerPack
    let size: PointerSize
    let imported: ImportedCursor?
    let collection: CursorCollection?

    var plan: CursorPackPlan? {
        guard let collection,
              collection.cursors.count > 1 || collection.cursors.first?.effectiveRole != nil else { return nil }
        return CursorPackPlan(cursors: collection.cursors)
    }
    var title: String { collection?.name ?? imported?.name ?? pack.title }
    var label: String { plan == nil ? "\(imported?.name ?? pack.title) · \(size.title)" : title }
}
