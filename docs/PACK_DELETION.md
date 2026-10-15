# Deleting cursor packs

Select an imported pack and choose **Delete pack…** beside its title, or right-click any imported pack in the sidebar and choose the same action. The native confirmation names the pack and cursor count. **Cancel** keeps the library unchanged; **Delete pack** removes every imported member of that collection. Ink, Tide, and Blush are built in and cannot be deleted.

Deletion removes Octapuss's saved library copies only. Original downloads remain in place. A currently applied system pack, its remembered sleep/unlock snapshots, and recovery ownership stay unchanged. Use **Restore system pointer** to stop that effect; deleting a pack is not a system reset.

**Undo deletion** appears in the bottom status area after a successful deletion. It restores the last deleted pack with its original IDs, images, animations, native mappings, and manual role assignments. Undo is available until another pack deletion replaces it or Octapuss quits. Deletion itself persists across relaunch; the Undo record is held in memory. A missing original download does not prevent Undo. After quitting, reimport the original files if you want the pack back.

Deleting the selected pack moves the preview to another imported set, or the current built-in preset when none remain. Deleting another pack leaves the selected preview intact. Undo restores the prior imported selection when that selection belonged to the deleted pack. Changes are saved atomically before the displayed library changes. Save failures retain the pack or Undo record and show an error.

## Verification — 16 October 2026

The safe executable checks cover whole-set deletion, untouched unrelated packs and source files, persisted removal, exact ID and role restoration, repeated Undo without duplicates, selected/unselected preview behavior, and a failed library save. Run `rtk proxy zsh scripts/build-phase0.sh --check`.

App-owned offscreen renders cover built-in, imported, and deleted/Undo states in light and dark appearances at 1080 × 760 and 900 × 640 pt. A fresh finish review returned **ship** at this extension's visual scope. This is a native macOS interface, so no HTML/CSS detector was run. Full Xcode/XCTest, other OS/hardware configurations, and exhaustive accessibility checks remain untested.

The running app's native confirmation, Cancel, Delete, Undo, and sidebar context menu were exercised through UI automation. Cancel retained all five user packs. Deleting the selected 16-cursor LuoXiaohei pack reduced the library to four packs and selected another preview while applied status remained LuoXiaohei. Undo restored all five packs, its 16 members, and its previous selection; the Undo control disappeared. The app was left with the user's original LuoXiaohei selection and applied status intact. This check does not establish exhaustive keyboard or VoiceOver behavior.
