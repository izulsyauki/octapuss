import Foundation

/// Typed access to existing preference keys. Runtime activation is intentionally not persisted.
struct CursorPreferences {
    let defaults: UserDefaults

    var pack: PointerPack {
        get { PointerPack(rawValue: defaults.string(forKey: "selectedPack") ?? "") ?? .ink }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "selectedPack") }
    }

    var pointerSize: PointerSize {
        get { PointerSize(rawValue: defaults.string(forKey: "pointerSize") ?? "") ?? .medium }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "pointerSize") }
    }

    var darkPreview: Bool {
        get { defaults.bool(forKey: "darkPreview") }
        nonmutating set { defaults.set(newValue, forKey: "darkPreview") }
    }

    var selectedImportedID: UUID? {
        get { UUID(uuidString: defaults.string(forKey: "selectedImportedCursor") ?? "") }
        nonmutating set { defaults.set(newValue?.uuidString, forKey: "selectedImportedCursor") }
    }
}
