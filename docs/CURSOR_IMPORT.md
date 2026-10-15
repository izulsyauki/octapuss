# Downloaded cursor imports

Octapuss imports local Windows `.cur` and `.ani` files from sources such as [RW Designer](https://www.rw-designer.com/cursor-library). Download in your browser, unzip sets, choose Import cursor under Your cursors, preview, then Apply system arrow. No downloading, executable installation, role inference, or automatic system application occurs during import.

## Format and scope

- CUR: validate the directory and hotspot, choose the largest decodable representation, rebuild a single-image ICO container for ImageIO decoding, and normalize to an 8-bit RGBA PNG. Supported ImageIO encodings include monochrome/paletted DIB masks and embedded PNGs. Normalizing through an 8-bit CGContext avoids the nearly transparent alpha that a direct monochrome NSBitmapImageRep PNG conversion produced on this host.
- ANI: validate RIFF/ACON chunk lengths and padding, find embedded cursor frames, and use the first sequence entry (or first embedded frame without a sequence). The picker and import panel explicitly say **first frame only**. Animated playback is not implemented.
- The chosen file is an **arrow replacement**, even if its download name describes another Windows role. Native hand, text, resize, busy, application-owned, and protected cursors remain outside this scope.
- Aspect ratio and hotspot are scaled together; the chosen size sets the longest canvas side. Four system image representations are generated at 1×, 2×, 5×, and 10×, using nearest-neighbor interpolation for pixel artwork.
- Import never enables a paused playground or changes the system pointer. Explicit Apply uses the existing journal, ownership checks, rollback, and watchdog. Removing an import leaves both its original download and the currently applied system effect unchanged.

Microsoft documents the [DIB/PNG cursor resources and RIFF animated cursor containers](https://learn.microsoft.com/en-us/windows/win32/menurc/resource-file-formats). Apple's [NSOpenPanel multiple selection](https://developer.apple.com/documentation/appkit/nsopenpanel/allowsmultipleselection) supplies the native file chooser; current AppKit documentation was fetched through Context7.

## Storage and bounds

`~/Library/Application Support/Octapuss/imported-cursors.json` contains names, UUIDs, normalized PNG images, original dimensions, hotspots, and first-frame flags. Selection is stored in preferences. Paths to original downloads are not retained. Writes are atomic; failures preserve the previous in-memory selection/library. Identical normalized artwork/hotspot/first-frame mode is deduplicated. Corrupt libraries are preserved and are not overwritten by an attempted import.

Limits: 4 MB per source file (bounded read), 16 files per import, 64 CUR directory images, 256 ANI frames, 256 px per canvas dimension, 128 library entries, and 64 MB persisted library. Unsupported or malformed files report an actionable error. Valid files in a mixed selection can still be imported; the diagnostic reports failures. ZIP archives and ICO frames without CUR hotspot metadata are not supported.

## Verification on this host

`rtk proxy zsh scripts/build-phase0.sh --check` covers PNG-backed CUR, 1-bit DIB AND-mask transparency, non-square aspect ratios, scaled hotspots, ANI first sequence selection, truncated/invalid/oversized data, local persistence across a store relaunch, independence from deleted source files, duplicate imports, built-in selection, and removal.

Temporary public compatibility samples: [Boxy by fuzzystudios](https://www.rw-designer.com/cursor-set/boxy), `boxy.cur` and `boxy working in background.ani`. Both decoded at 32 × 32 px, hotspot (1, 1); ANI was marked first-frame-only. These third-party assets are not bundled or committed. They were downloaded to `/tmp` only for compatibility verification. The author lists an attribution-required license on the set page.

The native file panel imported the CUR sample into the app, it remained selected after app relaunch, Boop registered a click, and explicit Apply succeeded. With Finder selected outside Octapuss, a read-only `NSCursor.currentSystem` probe returned the imported artwork at 40 × 40 pt, hotspot (1.25, 1.25); its 80 × 80 rendered image exactly matched an applied representation. Apply and Restore remain in a fixed action area outside the scrolling workbench.

The imported-artwork live integration check passed Apply, baseline restoration, and recovery after SIGKILL of its own worker. This verifies the tested host and sample through the existing recovery backend; it does not establish compatibility with every downloaded cursor or macOS version.

An independent finish review inspected the rendered 840 × 560 pt window through CUA. The imported thumbnail and playground portrait were visible, as were the fixed Apply/Restore actions. The extension retained the established dark shell, cream playground, native controls, typography, and palette. Your cursors extends the existing selection column; choosing an import updates the preview while system application remains an explicit action. This default-window check does not constitute a minimum-window, all-state, contrast, or accessibility pass.

Optional checks: set `OCTAPUSS_REAL_CURSOR_FILES` to colon-separated local `.cur`/`.ani` paths with `--check`; set `OCTAPUSS_LIVE_CURSOR_FILE` to one file with `--check-system-live` to verify real registration/restore and owned-worker crash recovery using imported artwork. The latter temporarily mutates system arrow registrations.

Full Xcode/XCTest execution, animation, arbitrary cursor encodings, complete downloaded theme role mapping, other macOS/hardware combinations, and exhaustive keyboard/VoiceOver/window-size coverage are untested or outside this feature. Command Line Tools compilation is the tested build path.
