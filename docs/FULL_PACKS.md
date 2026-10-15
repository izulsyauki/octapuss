# Full cursor packs

On 15 October 2026, Octapuss expanded imported sets from one arrow replacement to explicit application of every assigned, available macOS cursor role. Select a set, inspect its gallery, adjust a file's **Use for** role when necessary, then choose **Apply pack**. Selection and role edits remain previews until Apply. Duplicate assignments block Apply before changing the existing session.

## Mapping and platform limits

Recognizable Windows filenames map conservatively to arrow, help, working in background, busy, precision, text, unavailable, four resize directions, move, and link. Numeric filename prefixes are ignored. Unknown names stay unassigned; the inspector allows explicit assignment or exclusion. Additional macOS roles include open/closed hand, copy, alias, contextual menu, zoom, cell, and vertical text. A lone unnamed import retains arrow replacement compatibility.

Windows handwriting and alternate-select have no equivalent global slot in this backend. They remain visible and can be assigned another role. Unavailable host slots are skipped and reported. Application-drawn or protected cursors can remain unchanged; this private-API experiment does not promise every pointer in every application.

The Minecraft Diamond fixture contains 15 files. On the tested host it produces **13 roles across 56 registered slots**, including distinct background-working and busy slots. Identifier facts were checked against [MaCursor's definitions](https://github.com/writronic/MaCursor/blob/main/CursorEngine/MACCursorDefinitions.swift); no implementation or artwork was copied into the product.

## Animation and existing imports

ANI decoding retains embedded frames, sequence order, rates, and hotspots. Frames must share a canvas and hotspot. The native registration format uses vertical image strips and one duration per frame. Uniform animations up to 24 steps retain their exact timeline; variable rates or longer sequences are sampled into at most 24 uniform steps over the original cycle. The library and local playground retain the original sequence. Local animation pauses for Reduce Motion, detached/hidden views, or an inactive window. Pointer movement itself is never smoothed.

Older imports containing only a first frame require **Update set from folder…** to recover animation. Reimporting one matching folder (same set name and exact unique filenames) updates that set while preserving its collection ID, cursor IDs, and manual assignments. Ambiguous matches form a new set. Headerless incomplete ANI files retain a labeled first-frame fallback without repeatedly requesting an upgrade.

## Verification

- Safe executable checks passed: filename mapping, duplicate/conflicting assignments, ANI sequence and rates, sprite order, role persistence, in-place folder updates, full-pack rollback, and baseline restoration.
- The supplied Minecraft fixture decoded all 15 files, including 18 background-working frames and 24 busy frames, each at 100 ms.
- Real integration checks passed normal Apply/Restore and SIGKILL recovery of an owned worker for all 56 slots. Fresh reader processes verified baseline pixels, dimensions, hotspots, and journal removal. Floating-point duration comparisons tolerate native rounding below one microsecond.
- The actual app upgraded the user's existing set and applied 13 roles. The user confirmed the pack's text and webpage-link shapes both change in real use. Registered loading slots contain the full 18/24-frame strips; triggering every OS-controlled busy condition visually remains untested.
- App-owned offscreen renders were inspected for built-in/imported sets in light/dark appearances at 1080 × 760 and 900 × 640 pt. These are native view renders, not desktop captures.

Reproduce safe checks with `rtk proxy zsh scripts/build-phase0.sh --check`. Set `OCTAPUSS_PACK_FIXTURE_PATH` to an unzipped fixture folder to add its decode checks. For an authorized live test, set `OCTAPUSS_LIVE_PACK_FOLDER` and use `--check-system-live`; it temporarily changes system registrations, restores them, and kills only its own test worker. Set `OCTAPUSS_RENDER_PACK_PATH` and use `--render-library` for app-owned visual fixtures.

Full Xcode/XCTest, other hardware/OS versions, exhaustive VoiceOver/keyboard operation, multiple displays, fullscreen/protected contexts, sleep/session transitions, and notarized distribution remain **untested**. The tested build path is Command Line Tools. Fixture artwork remains user-owned local input and is not bundled or committed.
