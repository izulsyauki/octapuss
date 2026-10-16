# Phase 0 feasibility results

**Historical report, 1 October 2026.** The app-local repair on 15 October removed companion and cursor-hiding experiments from the executable. Current behavior and verification live in [REPAIR_VERIFICATION.md](REPAIR_VERIFICATION.md); statements below describe the earlier proof.

Run date: **1 October 2026**. Result scope: local native proof on the available Mac. This report separates code/build evidence, UI observation, and cases that still require human-visible pointer testing.

## Outcome

**Global replacement gate: inconclusive and not accepted.** App-local customization is implemented. A public pointer companion is implemented and truthfully leaves the native pointer visible. The documented foreground hide call succeeds and restores in this app, but cross-app replacement, semantic cursor roles, hotspot accuracy, forced termination, and multi-display behavior have not been established.

The user selected **app-local customization** on 1 October 2026. The product can proceed on that route without claiming system-wide replacement. Across-app experiments remain lab-only and still require the missing manual checks before any broader claim.

## Built proof

The paths below describe the historical proof. Current production source is organized under `Octapuss/`; see [architecture](ARCHITECTURE.md). Bundle metadata is now `Octapuss/Resources/Info.plist`.

- Source: `Phase0/OctapussProof.swift`
- Bundle metadata: `Phase0/Info.plist`
- Reproducible builder: `scripts/build-phase0.sh`
- Generated app: `/tmp/octapuss-phase0/Octapuss.app`

Implemented behavior:

- SwiftUI main window, Settings scene, and menu-bar utility.
- AppKit `NSView` cursor rectangle using `NSCursor(image:hotSpot:)`.
- Ink, Tide, and Blush pointer artwork generated with native vector paths.
- Small, Medium, and Large logical sizes with an arrow-tip hotspot scaled to match the artwork.
- Light and dark preview surfaces.
- Click-through nonactivating companion panel following `NSEvent.mouseLocation` at 60 Hz.
- Balanced two-second `CGDisplayHideCursor` / `CGDisplayShowCursor` foreground check.
- Idempotent Restore for the resources owned by this proof, including the standard app-termination path.
- Persistence only for pack and size. The proof does not persist automatic activation.

The proof records no pointer history, typing, screenshots, clicked content, or application activity.

## Environment

| Item | Observed value |
| --- | --- |
| Hardware | MacBook Pro `Mac14,7`, Apple M2, 8 GB RAM, arm64 |
| macOS | 26.5.1, build 25F80 |
| Active developer directory | `/Library/Developer/CommandLineTools` |
| Swift compiler | Apple Swift 6.3.2, `swiftlang-6.3.2.1.108`, target arm64 macOS 26.0 |
| Default SDK | macOS 26.5 |
| Swift module compile sysroot | Locally installed `MacOSX15.4.sdk`; the default SDK has a Swift patch-build mismatch |
| Binary SDK load command | macOS 26.5, as reported by `otool -l` after linking with the installed command-line tools |
| Minimum deployment target in binary | macOS 14.0 |
| Full Xcode in `/Applications` | Not found |
| Signing | Local ad-hoc signature |
| App Sandbox | Not enabled; no Xcode project/capabilities file exists |
| Event mask | None; the companion polls `NSEvent.mouseLocation` and does not install an event tap |
| Permissions requested | None |

The first build against the default macOS 26.5 SDK failed because its Swift interfaces were built with `swiftlang-6.3.2.1.2` while the installed compiler is `swiftlang-6.3.2.1.108`. The build script selects the installed 15.4 SDK, which compiles successfully with the current compiler. This is a local workaround for the proof, not a substitute for installing a matching full Xcode toolchain before product development.

## Verification performed

| Check | Result | Evidence and limit |
| --- | --- | --- |
| Source compilation | Pass | `scripts/build-phase0.sh` produced an arm64 Mach-O app with minimum macOS 14.0 |
| Bundle metadata | Pass | `plutil -lint Phase0/Info.plist` |
| Local signature | Pass | `codesign --verify --deep --strict` |
| Main UI layout | Pass on available display | Native render inspected at 780 × 520 pt; header, presets, dominant preview, size, Restore, and diagnostic row fit |
| Light/dark preview | Pass visually | Both segmented states rendered; dark content remained legible |
| Accessibility exposure | Partial pass | Controls, selected states, preview label/help, and status appeared in the macOS accessibility tree; VoiceOver was not manually run |
| Companion state | Pass for UI/lifecycle | Enable changed status to “Pointer companion active,” disabled the hide check, and Restore returned to Off |
| Companion pixels and tracking latency | Untested | The inspection capture excludes the companion panel/pointer; no motion recording or profiler run |
| Foreground hide/show balance | Pass | UI entered the hide-test state and automatically returned to Off after two seconds with one owned show call |
| App-local custom cursor appearance | Partial | Cursor artwork rendered in preset rows and the preview cursor rectangle is installed; screen captures omit the live pointer |
| Hotspot/click accuracy | Untested | The hotspot scales with the arrow tip and the preview cursor layer passes clicks through to sample controls; final accuracy still requires human-visible pointer/click observation |

## Required behavior matrix

| Context | Intended scope | Native pointer visible? | Hotspot/click accurate? | Restore works? | Result/evidence |
| --- | --- | --- | --- | --- | --- |
| Octapuss preview | App-local | Capture omits pointer | Untested | Cursor rectangle leaves with app | Partial |
| Pointer companion | Across apps, additive | Yes by design | Native click remains authoritative | Restore state passed | Partial; cross-app pixels unobserved |
| Finder / Safari / editor | Desired replacement | Untested | Untested | Untested | Not run |
| Text / links / resize / drag | Preserve native meaning | Untested | Untested | Untested | Not run |
| Other display / fullscreen | Declared supported scope | Untested | Untested | Untested | Only one built-in display was discoverable here |
| Quit / forced termination | Recovery | Untested | N/A | Normal Restore passed; Force Quit untested | Partial |

## Documentation/API findings applied

Context7 resolved Apple's current SwiftUI and AppKit documentation. The implementation follows these documented patterns:

- `MenuBarExtra` and `Settings` compose with the app's main Window scene; menu-bar styling is available on macOS 13+.
- A custom cursor is initialized from an `NSImage` and hotspot.
- An `NSView` installs cursor rectangles from `resetCursorRects()` with `addCursorRect`.
- `NSWindow.ignoresMouseEvents` makes the companion panel click-through.
- `NSEvent.mouseLocation` reports the pointer in screen coordinates.

These APIs support the proof's preview and companion. They do not establish public system-wide replacement. Apple's documented hide API normally requires the foreground application, as detailed in [FEASIBILITY.md](FEASIBILITY.md).

## Decision recorded

The selected route is **app-local customization**. The other researched routes remain documented alternatives:

1. **Actual global cursor themes:** research a separate private-API/direct-distribution backend with durable baseline recovery. This is the closest to the original product idea and carries the highest maintenance and distribution risk.
2. **Pointer companion:** build the polished app around an additive cat-octopus marker while preserving every native cursor role. This uses the implemented public approach but is a different product promise.
3. **App-local customization — selected:** ship a cursor preview/customization utility without promised across-app behavior. This has the lowest platform risk and matches the confirmed first-release scope.

Whichever route is selected must still complete the manual matrix, Force Quit recovery, performance measurement, and available accessibility checks in [TEST_PLAN.md](TEST_PLAN.md).
