import AppKit
import SwiftUI

// Native library · playful-operate · set list + cursor contact sheet.
// Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V5

@MainActor
struct CursorLibraryView: View {
    @EnvironmentObject private var store: ProofStore
    @Environment(\.openSettings) private var openSettings
    @State private var search = ""
    @State private var packToDelete: CursorCollection?
    @State private var showingDeleteConfirmation = false

    private let columns = [GridItem(.adaptive(minimum: 126, maximum: 180), spacing: 12)]
    private var collections: [CursorCollection] {
        store.cursorCollections.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
            || $0.cursors.contains { $0.name.localizedCaseInsensitiveContains(search) } }
    }
    private var packs: [PointerPack] {
        PointerPack.allCases.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 232)
                Divider()
                workbench
            }
            Divider()
            actionBar
        }
        .frame(minWidth: 900, minHeight: 640)
        .background(Color(nsColor: AppPalette.background))
        .tint(Color(nsColor: AppPalette.lavender))
        .alert("Delete cursor pack?", isPresented: $showingDeleteConfirmation, presenting: packToDelete) { collection in
            Button("Cancel", role: .cancel) { }
            Button("Delete pack", role: .destructive) { store.deleteCursorPack(id: collection.id) }
        } message: { collection in
            Text("Remove “\(collection.name)” and its \(collection.cursors.count) cursor\(collection.cursors.count == 1 ? "" : "s") from your library?\n\nYour original files and applied system cursor stay unchanged. You can undo the last pack deletion until Octapuss quits.")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                OctapussMascot(compact: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Octapuss").font(.system(size: 21, weight: .bold, design: .rounded))
                    Text("Little cursors. Big personality.")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                }
            }
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                TextField("Find a cursor set", text: $search)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search cursor sets")
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }
            .padding(9)
            .background(Color(nsColor: AppPalette.surface), in: RoundedRectangle(cornerRadius: 8))

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Made for Octapuss").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                    ForEach(packs) { pack in
                        SetRow(title: pack.title, detail: pack.detail, count: "1 custom arrow",
                               image: PointerArtwork.pointerImage(pack: pack, size: 32),
                               selected: store.selectedImportedID == nil && store.pack == pack,
                               accent: pack.color) { store.pack = pack }
                    }
                    HStack {
                        Text("Your sets").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                        Spacer()
                        Text("\(store.cursorCollections.count)").font(.system(size: 11, weight: .medium)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                    }.padding(.top, 16)
                    ForEach(collections) { set in
                        SetRow(title: set.name, detail: "Imported · on this Mac",
                               count: "\(set.cursors.count) cursor\(set.cursors.count == 1 ? "" : "s")",
                               image: set.cursors[0].image(longestSide: 32),
                               selected: store.selectedCollection?.id == set.id,
                               accent: AppPalette.lavender) { store.selectedImportedID = set.cursors[0].id }
                            .contextMenu {
                                Button(role: .destructive) { requestDeletion(of: set) } label: {
                                    Label("Delete pack…", systemImage: "trash")
                                }
                            }
                    }
                    if store.cursorCollections.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("A new home for your finds.").font(.system(size: 12, weight: .medium))
                            Text("Import a cursor file or an unzipped set to start your collection.")
                                .font(.system(size: 11)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                            Button("Import your first set…") { store.chooseCursorFiles(asFolder: true) }
                                .controlSize(.small)
                        }.padding(.vertical, 8)
                    } else if collections.isEmpty && packs.isEmpty {
                        Text("No sets match “\(search)”. Try another name.")
                            .font(.system(size: 12)).foregroundStyle(Color(nsColor: AppPalette.secondaryText)).padding(.vertical, 8)
                    }
                }.padding(.trailing, 2)
            }

            Divider()
            Menu {
                Button("Import cursor files…") { store.chooseCursorFiles() }
                Button("Import unzipped set folder…") { store.chooseCursorFiles(asFolder: true) }
            } label: {
                Label("Add to your collection", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }.menuStyle(.borderlessButton)
                .padding(10)
                .background(Color(nsColor: AppPalette.surface), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Add to your collection")
            Link(destination: URL(string: "https://www.rw-designer.com/cursor-library")!) {
                Label("Find more cursor pals", systemImage: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .padding(18)
        .background(Color(nsColor: AppPalette.sidebar))
    }

    private var workbench: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.selectedCollection?.name ?? store.pack.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(1).truncationMode(.middle)
                        .help(store.selectedCollection?.name ?? store.pack.title)
                    Text(store.selectedCollection == nil ? store.pack.detail : "Your imported cursor collection")
                        .font(.system(size: 12)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                }
                Spacer(minLength: 8)
                if let collection = store.selectedCollection {
                    Button { requestDeletion(of: collection) } label: {
                        Label("Delete pack…", systemImage: "trash")
                    }
                    .controlSize(.small)
                    .help("Delete this imported pack from your library")
                    .accessibilityLabel("Delete \(collection.name) pack")
                }
                Button { openSettings() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
                    .help("Settings")
            }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
            Divider()
            if store.selectedImportedCursor != nil {
                selectionInspector.padding(.horizontal, 24).padding(.vertical, 12)
                Divider()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    gallery
                    playground
                }.padding(24)
            }
        }
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Inside this set").font(.system(size: 15, weight: .semibold))
                Text(store.selectedCollection.map { "\($0.cursors.count) custom" } ?? "1 custom · 8 native")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                Spacer()
                Picker("Preview background", selection: $store.darkPreview) {
                    Text("Light").tag(false)
                    Text("Dark").tag(true)
                }.labelsHidden().pickerStyle(.segmented).frame(width: 112)
                    .accessibilityLabel("Preview background")
            }
            Text(store.appliesPack ? "Preview any cursor below. Apply pack uses all assigned roles together." : "Pick a cursor to preview and use as your system arrow.")
                .font(.system(size: 12)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                if let set = store.selectedCollection {
                    ForEach(set.cursors) { cursor in
                        Button { store.selectedImportedID = cursor.id } label: {
                            CursorTile(image: cursor.image(longestSide: 34), title: cursor.name,
                                       detail: cursor.effectiveRole?.title ?? (cursor.needsAnimationUpgrade ? "Reimport for animation" : "Choose a role"),
                                       selected: cursor.id == store.selectedImportedID, dark: store.darkPreview)
                        }.buttonStyle(.plain)
                            .accessibilityLabel("Preview \(cursor.name), \(cursor.effectiveRole?.title ?? "unassigned")\(cursor.needsAnimationUpgrade ? ", reimport for animation" : "")")
                            .accessibilityAddTraits(cursor.id == store.selectedImportedID ? .isSelected : [])
                            .contextMenu {
                                Button("Remove cursor from library") {
                                    store.selectedImportedID = cursor.id
                                    store.removeSelectedImport()
                                }
                            }
                    }
                } else {
                    CursorTile(image: PointerArtwork.pointerImage(pack: store.pack, size: 34), title: "Arrow",
                               detail: "Octapuss original", selected: true, dark: store.darkPreview)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(store.pack.title) arrow, selected")
                    ForEach(NativeCursorSample.allCases) { sample in
                        CursorTile(image: sample.cursor.image, title: sample.title, detail: "macOS · unchanged",
                                   selected: false, dark: store.darkPreview)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(sample.title), native macOS cursor, unchanged")
                    }
                }
            }
        }
    }

    private var selectionInspector: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Label(store.appliesPack
                      ? "\(selectedRoleCount) roles mapped · \(store.selectedPackPlan.unmapped.count) files without a system slot"
                      : "Assign a role, or use this single cursor as your arrow", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                Spacer(minLength: 8)
                if store.selectedCollection?.cursors.contains(where: \.needsAnimationUpgrade) == true {
                    Button("Update set from folder…") { store.chooseCursorFiles(asFolder: true) }
                        .controlSize(.small)
                        .help("Reload this set's original folder to import all ANI animation frames.")
                }
            }
            if let cursor = store.selectedImportedCursor {
                HStack(spacing: 16) {
                    Text(cursor.name).font(.system(size: 12, weight: .semibold))
                        .lineLimit(1).truncationMode(.middle).help(cursor.name)
                    Spacer(minLength: 8)
                    Picker("Use for", selection: Binding(
                        get: { cursor.effectiveRole?.rawValue ?? "unassigned" },
                        set: { store.assignSelectedRole($0) }
                    )) {
                        Text("Unassigned").tag("unassigned")
                        ForEach(CursorRole.allCases) { role in Text(role.title).tag(role.rawValue) }
                    }.frame(width: 300)
                        .accessibilityLabel("Role for selected cursor")
                }
                HStack(spacing: 14) {
                    Text("Click point: \(cursor.hotspotX), \(cursor.hotspotY)")
                    Text("\(cursor.width) × \(cursor.height) px")
                    if let animation = cursor.animation { Text("\(animation.frames.count) animation frames") }
                    else if cursor.needsAnimationUpgrade { Text("Reimport for full ANI animation") }
                    else if cursor.firstFrameOnly { Text("ANI without animation header · first frame only") }
                }.font(.system(size: 11)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
            }
        }
    }

    private var playground: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Give it a little boop").font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Picker("Pointer size", selection: $store.pointerSize) {
                    ForEach(PointerSize.allCases) { size in Text(size.title).tag(size) }
                }.labelsHidden().pickerStyle(.segmented).frame(width: 220)
                    .accessibilityLabel("Pointer size")
            }
            CursorPreviewBridge(store: store).frame(height: 190)
        }
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: store.systemNeedsRecovery ? "exclamationmark.triangle" : "cursorarrow.rays")
                        .foregroundStyle(store.systemNeedsRecovery ? Color.primary : Color(nsColor: AppPalette.tide))
                    Text(store.statusTitle).font(.system(size: 11, weight: .medium))
                        .lineLimit(1).truncationMode(.middle).help(store.statusTitle)
                }
                Spacer(minLength: 12)
                if !store.previewEnabled {
                    Button("Resume preview") { store.resumePreview() }
                }
                Button("Restore system pointer") { store.restore() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button(store.applyActionTitle) { store.applySystemArrow() }
                    .buttonStyle(.borderedProminent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(store.diagnostic).font(.system(size: 11)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let deleted = store.lastDeletedPack {
                    Button("Undo deletion") { store.undoPackDeletion() }
                        .controlSize(.small)
                        .help("Restore “\(deleted.name)” to your library")
                        .accessibilityLabel("Undo deletion of \(deleted.name)")
                }
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(Color(nsColor: AppPalette.surface))
    }

    private var selectedRoleCount: Int {
        Set(store.selectedPackPlan.mapped.compactMap(\.effectiveRole)).count
    }

    private func requestDeletion(of collection: CursorCollection) {
        packToDelete = collection
        showingDeleteConfirmation = true
    }
}

private struct SetRow: View {
    let title: String
    let detail: String
    let count: String
    let image: NSImage
    let selected: Bool
    let accent: NSColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
                    .frame(width: 30, height: 34)
                    .frame(width: 40, height: 44)
                    .background(Color(nsColor: accent).opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                    Text(count).font(.system(size: 11)).foregroundStyle(Color(nsColor: AppPalette.secondaryText))
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(nsColor: AppPalette.lavender))
                }
            }
            .padding(9)
            .contentShape(Rectangle())
            .background(selected ? Color(nsColor: AppPalette.lavender).opacity(0.13) : .clear,
                        in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
            .help("\(title) · \(detail) · \(count)")
            .accessibilityLabel("\(title), \(count)")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct CursorTile: View {
    let image: NSImage
    let title: String
    let detail: String
    let selected: Bool
    let dark: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
                .frame(width: 36, height: 36)
                .frame(maxWidth: .infinity).frame(height: 48)
            Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
            Text(detail).font(.system(size: 10)).opacity(0.78).lineLimit(1)
        }
        .foregroundStyle(dark ? Color.white : Color(nsColor: AppPalette.ink))
        .padding(.horizontal, 10).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: dark ? AppPalette.previewDark : AppPalette.previewLight),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(nsColor: AppPalette.lavender))
                    .font(.system(size: 13)).padding(8)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? Color(nsColor: AppPalette.lavender) : Color.primary.opacity(0.10), lineWidth: selected ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .help("\(title) · \(detail)")
    }
}

enum NativeCursorSample: String, CaseIterable, Identifiable {
    case text, link, crosshair, openHand, closedHand, horizontalResize, verticalResize, unavailable
    var id: String { rawValue }
    var title: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .crosshair: "Precision"
        case .openHand: "Open hand"
        case .closedHand: "Grab"
        case .horizontalResize: "Resize sideways"
        case .verticalResize: "Resize up / down"
        case .unavailable: "Unavailable"
        }
    }
    var cursor: NSCursor {
        switch self {
        case .text: .iBeam
        case .link: .pointingHand
        case .crosshair: .crosshair
        case .openHand: .openHand
        case .closedHand: .closedHand
        case .horizontalResize: .resizeLeftRight
        case .verticalResize: .resizeUpDown
        case .unavailable: .operationNotAllowed
        }
    }
}
