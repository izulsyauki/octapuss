# Native .cursor themes

Octapuss can import a single local `.cursor` property-list theme through **Import cursor files…**. Import is a preview operation; choose **Apply pack** to use the theme. It does not execute theme contents, download dependencies, or install another application.

The implemented format has a `Cursors` dictionary keyed by recognized native cursor identifiers. Entries contain `FrameCount`, per-frame `FrameDuration`, `PointsWide`, `PointsHigh`, `HotSpotX`, `HotSpotY`, and `Representations` containing vertically stacked PNG/TIFF artwork. This support follows the supplied Anya file's actual structure; it is not a claim to decode every format using the `.cursor` suffix.

The decoder validates file size, metadata, role identifiers, image dimensions, animation strip division, and hotspot bounds before importing. It chooses the highest-resolution valid representation up to 256 pixels per frame dimension, normalizes frames to RGBA PNG, and scales hotspots into the chosen pixel canvas. Fractional logical hotspots are represented at the normalized image's pixel precision. Native role families expand to available compatible aliases; distinct precision variants retain their exact slots. Explicit manual assignment can override that mapping, and overlapping assignments still block Apply.

The source limit is 4 MB, with at most 64 entries, 16 representations per entry, 256 frames per cursor, and 16 million decoded pixels across the theme. Existing library size and entry limits still apply. Unsupported metadata or entries reject the theme atomically. Reimporting a matching named set preserves its cursor IDs and manual assignments. The library stores normalized artwork and native slot metadata independently of the original file. The provided artwork remains local and is not committed or bundled with Octapuss.

## Anya verification — 16 October 2026

`cursor-example/Anya.cursor` decoded as **13 entries, 12 distinct roles, 53 mapped slots, and 6 animated entries**. Arrow has 5 frames, text 12, background-working 15, help 10, and two precision variants each have 16. Static busy, link, unavailable, and four resize variants are also present. The theme does not supply a move cursor or every macOS role; missing roles retain their baseline.

Safe checks verify vertical frame order, timing, hotspots, disjoint native precision slots, malformed hotspot rejection, actual Anya decoding, persistence, and stable reimport. Reproduce with `OCTAPUSS_NATIVE_THEME_PATH=/absolute/path/Anya.cursor rtk proxy zsh scripts/build-phase0.sh --check`. For an authorized native integration check use `OCTAPUSS_LIVE_NATIVE_THEME=/absolute/path/Anya.cursor rtk proxy zsh scripts/build-phase0.sh --check-system-live`; this temporarily applies the theme, restores it, and kills only its own worker to verify crash recovery.

Full Xcode/XCTest, other native theme schemas, hardware/OS combinations, and exhaustive visual observation of all animated roles remain untested.

Anya's non-square arrow exposed native float rounding during the first integration attempt: a height of `30.967741935483872` returned as `30.967741012573242`. Geometry ownership comparisons now tolerate differences below 0.00001 points while retaining exact decoded pixel checks. A regression verifies float rounding is accepted and a real 0.1-point hotspot change is rejected. This fixes the false ownership conflict without bypassing image ownership checks.

After that correction, real integration passed Apply/Restore for all 53 slots, including baseline pixel/geometry/hotspot verification and journal cleanup. SIGKILL of an owned worker also restored all 53 slots. The earlier interrupted test baseline was restored through the corrected ownership checks. The actual app then imported Anya and applied it at the selected Large size, reporting **System pack: Anya · 12 roles** and **53 system slots**. Native gallery/playground artwork was visually inspected upright in the app. This does not establish visible animation in every external application or protected context.
