# Cursor-set library redesign

## Approved direction

The user requested MaCursor-inspired template browsing and visibility of every cursor, with a cuter Octapuss cat-and-octopus identity and Awwwards references. They confirmed **sets on the left, cursor gallery on the right**. This pinned composition replaces the old preset picker; the existing cream, lavender, mint, rose, native typography, and safe explicit Apply behavior remain the brand constraints.

Mode: Operate. Structure: searchable set library + adaptive cursor contact sheet + compact live playground + fixed action bar. Default content area: 1080 × 760 pt. Minimum: 900 × 640 pt. The sidebar and gallery scroll independently; Apply and Restore remain outside both scroll regions. No website navigation, marketing sections, hidden pointer overlay, or automatic application is introduced.

## References and translation

- [MaCursor](https://github.com/writronic/MaCursor): theme list, cursor inventory, preview, and explicit Apply. Its implementation and artwork are not copied, and Octapuss does not imply parity with its full-role theme engine.
- [Meow Mart — colorful and playful illustration](https://www.awwwards.com/inspiration/meow-mart-colorful-and-playful-illustration): character-led warmth and small illustrated identity details; translated into the original cat-eared, tentacled Octapuss mark with a tiny face. No reference artwork is bundled.
- [Comotion](https://www.awwwards.com/sites/comotion): playful color and spontaneous branding; translated into quiet pastel selection and a generous, legible native layout. Its scrolling effects and website structure are not transplanted into a utility.

## Delivered behavior

- Built-in sets: Ink, Tide, Blush. Each shows its custom arrow and eight native macOS cursor samples. Native samples are labeled **macOS · unchanged** and are informative; they are not presented as themed replacements.
- Imported sets: every successfully imported file is visible as an individual selectable thumbnail, with its filename and dimensions or ANI first-frame label. Selection updates the existing native cursor playground. Source aspect ratio/hotspot scaling is preserved.
- Search filters set names and imported cursor filenames. Sidebar rows show the actual cursor count. Clearing search restores the list without changing selection.
- Add to your collection offers file import and unzipped folder import. File → Import cursor files (`⌘O`) and Import unzipped set folder (`⇧⌘O`) offer native alternatives.
- Files imported together form one set. Folder import reads regular `.cur`/`.ani` files directly within the selected folder, skips hidden/non-cursor entries, and does not traverse nested folders. ZIP sets must be unzipped first. The limit is 64 files per import and 128 library entries total.
- A single imported file remains its own set. Libraries created before this redesign decode without collection metadata and retain their artwork, IDs, and selection. Removing a cursor through its context menu preserves other set members and selects another member when available. Original downloads and applied system effects are unchanged.
- Apply still replaces the selected system arrow only; native text/hand/resize and application-owned cursors remain outside the replacement scope. Restore, startup recovery, ownership checks, and crash watchdog continue through the existing backend.

## Verification

Safe regression checks now cover old-library decoding, folder grouping, selection within a set, removal of one member, set persistence across relaunch, and no automatic system application, in addition to prior decoding/hotspot/recovery checks.

`OCTAPUSS_IMPORT_FIXTURE_DIR=/tmp/octapuss-import-fixtures` with `--check` creates three clearly named synthetic cursor fixtures for visual QA. `--render-library` renders only Octapuss-owned views offscreen in light/dark appearances at default/minimum sizes, with built-in and three-cursor imported states. Set `OCTAPUSS_RENDER_DIR` to change the output folder. Native cursor artwork requires normal WindowServer access; sandbox-only renders can omit native samples and are not valid evidence for that artwork. The offscreen windows are inactive, so native action styling differs from the foreground app. No desktop or other application content is captured.

The running native app was inspected with the new set sidebar, imported selection, built-in cursor inventory, and fixed Apply/Restore. Eight app-only source renders at `/tmp/octapuss-library-review/{builtin,imported}-{light,dark}-{default,minimum}.png` cover both library states, appearances, and window sizes with native artwork present. These are inactive offscreen Octapuss windows, not desktop or other-app captures.

Live native UI checks also exercised the folder chooser through `⇧⌘O`, imported the three-file synthetic fixture set, reloaded the app, and observed three separate gallery buttons including the ANI first-frame label. Context-menu removal retained the remaining selected set and removed it when empty. A no-match search showed help; Clear search restored the list and prior selection. Temporary QA imports were removed, preserving the original Boxy entry. These checks do not establish exhaustive keyboard or accessibility coverage.

The bounded design review concluded **SHIP at the reviewed redesign scope** after two fixes: grouped imports retain distinct filenames even when artwork is identical, and explicit dynamic secondary-text colors replace low-contrast inherited metadata. Regression checks include identical-artwork `Arrow.cur` / `Select.cur` retention. The updated secondary-text samples measured approximately 6.22:1 in light appearance and 8.17:1 in dark appearance; this is not a whole-app accessibility certification. The confirmation pass checked corrected source/tests plus built-in/light/minimum and imported/dark/default captures; the initial pass inspected all eight layouts.

Inactive offscreen captures do not establish foreground action accents. Dark-preview selection variants, empty/error/recovery UI, exhaustive keyboard/VoiceOver traversal, live scrolling and minimum-window resizing, multiple monitors, full Xcode/XCTest, and other OS/hardware versions remain untested or incompletely covered. No system-live application was required for this visual review. Apply remains arrow-only and ANI imports remain first-frame-only.

`DESIGN.md` now records observed native tokens and canonical design-system sections; `.impeccable/design.json` carries schema-v2 metadata and portable panel specimens. The specimens approximate native controls for the panel; SwiftUI/AppKit is the rendering authority. Synthesized tonal ramps are panel aids rather than new application colors. The HTML/CSS detector does not inspect this native SwiftUI interface and was skipped. Product platform remains accurately recorded as macOS; documentation tooling limitations do not authorize relabeling it as iOS or web.

## Pack-role extension — 15 October 2026

The subsequent extension preserves this visual system and composition. Imported selections add a fixed inspector above the scrolling gallery with a manual **Use for** role picker, selected filename, click point, dimensions, and ANI frame information. **Apply pack** explicitly applies assigned, available roles; built-in sets and single unnamed imports retain arrow application. Tile metadata now identifies roles or an animation-upgrade prompt. The arrow-only and first-frame-only statements above describe the earlier redesign milestone; current behavior and integration evidence are recorded in `docs/FULL_PACKS.md`.

Fresh app-only captures at `/tmp/octapuss-pack-review/{builtin,imported}-{light,dark}-{default,minimum}.png` cover all eight combinations of library state, appearance, and window size. The bounded review found no material visual issue and concluded **SHIP** for this extension. Existing palette, typography, spacing, radii, mascot, YAML tokens, and `.impeccable/design.json` remain unchanged. The sidecar's arrow-action specimen remains an earlier illustrative control sample; source and `DESIGN.md` behavior prose describe the additional pack action. This visual disposition does not expand the keyboard, accessibility, foreground-animation, or hardware coverage stated above.

## Whole-pack deletion extension — 16 October 2026

Imported packs now offer **Delete pack…** in the workbench header and sidebar context menu. A native confirmation names the pack and cursor count, with Cancel and a destructive Delete pack action. Successful deletion removes the whole imported pack from the saved library; the original files and applied system cursor remain intact. Built-in packs remain protected. **Undo deletion** restores the last deleted pack and any prior selection within it, and stays beside the bottom diagnostic text until used, superseded by another deletion, or the app quits. The fixed Apply/Restore row, browsing composition, and incumbent visual identity remain intact. Persistence and recovery details are documented in `docs/PACK_DELETION.md`.

Fresh app-only captures at `/tmp/octapuss-delete-review/{builtin,imported,deleted}-{light,dark}-{default,minimum}.png` cover twelve combinations, including the post-deletion empty-library state and visible Undo. The bounded visual review concluded **SHIP** across all twelve. These inactive offscreen renders support layout and appearance review; they do not establish native confirmation interaction or foreground control behavior. Native SwiftUI/AppKit remains the rendering authority, so no HTML/CSS detector was applied. This extension changes behavior prose only in `DESIGN.md`; its YAML tokens and `.impeccable/design.json` remain unchanged, and prior accessibility, animation, and hardware coverage limits still apply.
