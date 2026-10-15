---
name: Octapuss
description: A playful native macOS cursor library with precise previews and explicit system-arrow application.
colors:
  ink: "rgb(17.6% 14.1% 25.1%)"
  tide: "rgb(24.7% 60.8% 56.9%)"
  blush: "rgb(87.5% 42.4% 57.3%)"
  lavender: "rgb(54.9% 42% 84.7%)"
  sunshine: "rgb(95.7% 72.2% 37.6%)"
  preview-light: "rgb(100% 97.3% 91.4%)"
  preview-dark: "rgb(10.2% 8.6% 15.3%)"
  surface-light: "rgb(100% 99.2% 97.3%)"
  surface-dark: "rgb(14.5% 12.5% 20.4%)"
  background-light: "rgb(99.6% 96.1% 90.6%)"
  sidebar-light: "rgb(95.7% 92.9% 96.9%)"
  secondary-light: "rgb(39.6% 33.7% 43.5%)"
  secondary-dark: "rgb(71.4% 67.5% 79.2%)"
  pointer-outline: "rgb(100% 100% 100% / 0.96)"
  pointer-detail: "rgb(100% 100% 100% / 0.8)"
typography:
  headline:
    fontFamily: "-apple-system"
    fontSize: "28pt"
    fontWeight: 700
  brand:
    fontFamily: "-apple-system"
    fontSize: "21pt"
    fontWeight: 700
  title:
    fontFamily: "-apple-system"
    fontSize: "15pt"
    fontWeight: 600
  body:
    fontFamily: "-apple-system"
    fontSize: "13pt"
    fontWeight: 400
  label:
    fontFamily: "-apple-system"
    fontSize: "12pt"
    fontWeight: 500
  caption:
    fontFamily: "-apple-system"
    fontSize: "11pt"
    fontWeight: 400
  micro:
    fontFamily: "-apple-system"
    fontSize: "10pt"
    fontWeight: 400
rounded:
  field: "8pt"
  thumbnail: "9pt"
  import: "10pt"
  tile: "12pt"
spacing:
  step-8: "8pt"
  step-9: "9pt"
  step-10: "10pt"
  step-12: "12pt"
  step-14: "14pt"
  step-16: "16pt"
  step-18: "18pt"
  step-20: "20pt"
  step-22: "22pt"
  step-24: "24pt"
components:
  search-field:
    backgroundColor: "{colors.surface-light}"
    rounded: "{rounded.field}"
    padding: "{spacing.step-9}"
  set-row:
    rounded: "{rounded.tile}"
    padding: "{spacing.step-9}"
  cursor-tile:
    backgroundColor: "{colors.preview-light}"
    textColor: "{colors.ink}"
    rounded: "{rounded.tile}"
    padding: "12pt 10pt"
  cursor-tile-dark:
    backgroundColor: "{colors.preview-dark}"
    rounded: "{rounded.tile}"
    padding: "12pt 10pt"
  import-menu:
    backgroundColor: "{colors.surface-light}"
    rounded: "{rounded.import}"
    padding: "{spacing.step-10}"
  action-bar:
    backgroundColor: "{colors.surface-light}"
    padding: "14pt 22pt"
---
# Design System: Octapuss

## Overview

**Creative North Star: "A pocket collection of pointer pals"**

A pocket collection of pointer pals, grounded in a dependable Mac utility. Warm cream, pale lavender, mint, and rose give the cursor artwork room to feel personal. The original cat-eared octopus brings a small face and rounded tentacles to the brand mark.

Native macOS controls, system type, direct selection, and readable status keep the work calm and precise. Character supports browsing and previewing; explicit Apply and visible Restore make the scope understandable.

**Key Characteristics:**
- Warm pastel surfaces with lavender selection.
- Native system typography and familiar controls.
- Original cat-and-octopus mark; cursor artwork stays the focal object.
- Tonal separation with restrained outlines.

This refresh records the approved, implemented native cursor library. Source authority: `Phase0/OctapussProof.swift` (`AppPalette`, mascot, window) and `Phase0/CursorLibraryView.swift` (layout and controls). Surface-specific references, behavior, and review evidence live in `docs/UI_REDESIGN.md`.

## Colors

Cream and lavender set a gentle backdrop; ink anchors artwork while mint, rose, and sunshine carry personality. Frontmatter values preserve the source's exact sRGB percentages rather than rounded hex approximations.

### Primary

- **Lavender** (`lavender`): the constant application tint, selected outlines, checkmarks, and translucent selected set rows. The source uses the same lavender in both appearances.

### Secondary

- **Lagoon mint** (`tide`): Tide artwork and ordinary status icon accent.
- **Berry rose** (`blush`): Blush artwork and the mascot body.

### Tertiary

- **Sunshine** (`sunshine`): the mascot's translucent circular halo and small preview accents.

### Neutral

- **Cozy ink** (`ink`): original Ink pointer, mascot face, and light-preview tile text. Main SwiftUI labels otherwise inherit native primary text.
- **Warm paper** (`background-light`), **cream surface** (`surface-light`), and **lavender mist** (`sidebar-light`): light canvas, grouped surfaces, and sidebar respectively.
- **Night purple** (`preview-dark`) and **plum surface** (`surface-dark`): dark canvas/preview and dark surface/sidebar respectively.
- **Preview cream** (`preview-light`): light cursor test tiles, independent of application appearance.
- **Secondary ink / lilac** (`secondary-light`, `secondary-dark`): explicit dynamic metadata and help text in the library. Settings may still use native secondary labels.
- **Pointer outline / detail**: translucent white edges and artwork detail. Dark-preview tile text is white; metadata is reduced to 78% opacity within tiles.

**The Preview Surface Rule.** The Light/Dark picker changes the cursor test surfaces independently of the application's macOS appearance.

Native error, disabled, keyboard-focus, and button treatment remain semantic. Brand mint alone must not signal recovery success; every runtime status has text.

## Typography

**Display and body font:** macOS system font through SwiftUI/AppKit. The portable `-apple-system` token names this family; it does not introduce a browser font dependency. SwiftUI's rounded system design applies to collection headings, the brand, and the playground title. Other text uses the standard system design. Line heights remain native defaults.

### Hierarchy

- **Headline:** bold rounded (28 pt), selected collection name, single line with middle truncation and full-name help.
- **Brand:** bold rounded (21 pt), sidebar product name.
- **Title:** semibold (15 pt), gallery and playground section titles.
- **Body:** regular (13 pt), standard labels; set names use semibold at the same size.
- **Label:** medium (12 pt), tile filenames; explanatory lines use regular weight and group labels use semibold.
- **Caption:** regular (11 pt), counts and help; runtime status uses medium weight.
- **Micro:** regular (10 pt), tile metadata; the sidebar tagline uses medium weight.

Do not replace the macOS system family with a downloaded display font. Small metadata supplements a named control or image; it must not carry an otherwise invisible action.

## Layout

The current library uses a fixed-width left set sidebar and a flexible right workbench. Sidebar and workbench scroll independently, and a full-width action bar stays outside both scroll areas. The main window defaults to 1080 × 760 pt and has a 900 × 640 pt minimum content size.

The sidebar is 232 pt wide including 18 pt padding. The workbench uses 24 pt content padding and an adaptive contact sheet: tiles have a 126–180 pt target width with 12 pt gaps. Its header uses 24 pt horizontal padding, 22 pt top padding, and 18 pt bottom padding. Gallery and playground groups are separated by 20 pt. The native playground is 190 pt high; size and background pickers are 220 pt and 112 pt wide. The action bar uses 22 pt horizontal and 14 pt vertical padding.

Imported selections add a compact inspector between the workbench header and scrolling gallery. It stays visible while browsing the contact sheet, uses the existing horizontal content padding, and keeps the selected filename, role picker, click point, dimensions, and animation information together. Long filenames truncate in the middle with full-name help. The role picker remains a native control (300 pt wide); this extension preserves the existing sidebar, window sizes, palette, and mascot.

Spacing tokens record reused observed steps, including 9 pt padding in the search field and set rows. Native layout adapts the gallery column count to available width; there are no website breakpoints or mobile layouts. Retain scrolling and readable actions when content grows.

## Elevation & Depth

The library uses tonal layering and fine borders rather than custom drop shadows. Native controls and window chrome keep their platform-owned depth. Selected set rows use lavender at 13% opacity; the thumbnail well uses the set accent at 12%. Gallery tiles use a 1 pt native primary border at 10% opacity, rising to a 2 pt lavender border for selection. Focus and button press feedback remain native.

## Shapes

Rounded rectangles soften the collection without obscuring control roles: search fields use the field radius, thumbnail wells use the thumbnail radius, import menus use the import radius, and rows/tiles use the tile radius. The mascot combines cat ears, a rounded head, four small curved tentacles, two eyes, and a smile. Its sidebar footprint is 34 × 34 pt with a sunshine halo at 24% opacity. Decorative artwork is hidden from accessibility traversal.

## Components

### Buttons

Apply pack and Apply system arrow share the native bordered-prominent button tinted lavender. The label reflects whether the current selection applies assigned pack roles or a single arrow. Restore, Resume preview, and Settings retain native macOS behavior. No custom button radius, shadow, or animation token is asserted: those are platform-owned. Apply is explicit; selecting a set, tile, size, or test background changes the local preview, and editing a role saves the mapping for the next Apply.

### Search field

A plain native text field and magnifying-glass symbol share a rounded surface. A named clear button appears while search has content. Search matches set names and imported filenames. Focus is native; the field's accessibility label is Search cursor sets.

### Set navigation

Rows pair a 40 × 44 pt thumbnail well with a name, count, and selected checkmark. Artwork is fitted within a 30 × 34 pt box. Rows use plain native buttons, selected accessibility traits, and full-name help. Imported files with identical pixels remain separate named gallery members.

### Cursor tiles

Tiles fit artwork into a 36 × 36 pt image box within a 48 pt high art area. Filename and metadata sit below with 8 pt spacing. Background follows the preview picker; selection adds a checkmark and stronger outline. Imported tiles are selectable and offer removal through a context menu. Built-in packs show one custom arrow and eight informative native macOS samples labeled macOS · unchanged.

Imported tile metadata names the assigned role or prompts for a role or animation upgrade. The selected-file inspector provides the native **Use for** picker, including **Unassigned**, and summarizes mapped roles and files without a system slot. Keep these states explicit in text; a gallery selection alone must not imply a global replacement. Duplicate role assignments block Apply with an explanation. Windows-only roles without a global equivalent remain visible for manual reassignment.

### Import menu

Add to your collection offers native file and unzipped-folder import. Empty collections supply a first-import action; empty search results explain the absence. The external cursor-library link is a small text affordance, not a bundled marketplace.

### Playground and action bar

The AppKit preview owns cursor rectangles and the Boop button in one view. It preserves hotspot scaling and uses real cursor feedback. The action bar gives status, diagnostic text, explicit Apply, Restore, and paused-preview recovery a stable location. Applied status must describe the arrow or pack actually applied, even after browsing changes.

ANI playback in the local playground retains the imported sequence and timing. It pauses for Reduce Motion, hidden or detached views, and an inactive window. The inspector shows frame count, an upgrade action for older first-frame imports, or a labeled first-frame fallback for incomplete ANI files. Native pack application uses at most 24 uniform animation steps; describe that limit without implying the local original sequence is reduced. Animation belongs to the cursor artwork and must not change pointer movement or introduce mascot motion.

Native system controls supply keyboard focus and interaction feedback. No looping mascot motion or custom transition timing is implemented. Keep reduced-motion support and immediate pointer tracking as constraints.

## Do's and Don'ts

### Do:
- Do use the native macOS system font and rounded system headings.
- Do preserve each imported filename, aspect ratio, and click point.
- Do distinguish selected artwork, local preview, and the arrow actually applied.
- Do show selection with an outline and checkmark as well as color.
- Do keep Apply and Restore reachable outside scrolling content.

### Don't:
- Don't turn ordinary buttons or focus affordances into mascot anatomy.
- Don't imply that native text, hand, or resize samples are custom replacements.
- Don't copy reference artwork or add website chrome to the native utility.
- Don't animate or smooth pointer tracking; the click point must follow immediately.
