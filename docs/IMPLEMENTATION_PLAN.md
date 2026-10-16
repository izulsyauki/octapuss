# Octapuss implementation plan

Updated 16 October 2026. The selected product is a native macOS cursor-pack utility with an independent app-local playground. The original app-local decision was superseded by the system-customization request on 15 October. Historical proof remains in [FEASIBILITY_RESULTS.md](FEASIBILITY_RESULTS.md); current evidence is in [STABILITY_REPORT.md](STABILITY_REPORT.md).

## Milestone status

| Milestone | Current result | Remaining gate |
| --- | --- | --- |
| 0: Feasibility | Complete on this Mac: native registration, restoration, owned-worker crash recovery | No universal OS/hardware claim |
| 1: Native shell | Library, Settings, menu bar, background operation, reopen and full Quit implemented | Direct status-menu/Dock and accessibility verification |
| 2: Artwork and preview | Presets, sizes, CUR/ANI/native-theme import, gallery, manual roles, deletion/Undo implemented | Human hotspot checks across sizes/displays |
| 3: Engine and recovery | Full-pack Apply, durable journal, ownership checks, rollback, helper, suspension/resumption implemented | Physical lifecycle and workspace matrix |
| 4: Persistence and guidance | Local library/preferences, explicit Apply, recovery/color diagnostics, preview pause implemented | Complete keyboard and VoiceOver workflows |
| 5: Local beta verification | In progress | Performance, manual matrix, toolchain and support evidence |
| External distribution | Deferred until candidate verification and signing | Developer ID, hardened-runtime compatibility, notarization, Gatekeeper |

## Stability milestone

1. Run regression checks with available fixtures and 100 isolated Apply/Restore cycles, verifying baseline/journal cleanup.
2. Build the app and validate the packaged helper, metadata, and local signature.
3. Verify full-pack restoration and owned-worker crash recovery without competing with an active user session.
4. Measure app-only CPU and resident memory in paused, active, and background states. Distinguish idle samples from movement and long-duration evidence.
5. Inspect the native UI at minimum/default sizes in both appearances. Check keyboard focus, labels, search, roles, Apply/Restore, import, deletion/Undo, Settings, and menu access.
6. Check sleep/lock return, logout/restart, fullscreen/Spaces, and display changes. Coordinate disruptive tests; unavailable hardware stays untested.
7. Fix demonstrated defects, rerun affected checks, and record limitations in one evidence report.
8. Prepare a local experimental candidate with reproducible build and recovery instructions. External release readiness requires the remaining gates.

## Behavior contract

- Launch starts the local preview and recovers unresolved prior registrations; system Apply remains explicit.
- Selection, size, and role edits do not silently replace the applied pack.
- Restore cancels resumption, restores owned registrations, and pauses the playground.
- Dock Quit and ⌘Q keep the cursor session running in the menu bar. Menu-bar **Quit Octapuss** restores and exits; restoration errors keep the app open.
- Sleep, lock, and session deactivation temporarily restore registrations. Return reapplies the exact remembered pack after all suspension reasons clear. No login item or reboot persistence is installed.
- The private API backend can differ for app-drawn/protected cursors and Windows-only roles. Native animation has a 24-step uniform limit; the preview retains the original sequence.

## Build and acceptance

The reproducible local route is `rtk proxy zsh scripts/build-phase0.sh`; `--check` runs executable checks. `--check-system-live` is an explicit system-mutating recovery check. The Xcode target and shared scheme exist, but full Xcode is absent and no XCTest target exists. A hosted macOS validation workflow is configured; its first runs were blocked before execution by a GitHub account billing restriction. Command Line Tools success is not Xcode/XCTest validation.

A local beta requires a truthful support matrix, usable cues/hotspots, reliable restoration, accessible controls, stable resources, and recovery instructions. [TEST_PLAN.md](TEST_PLAN.md) defines cases; [STABILITY_REPORT.md](STABILITY_REPORT.md) distinguishes passed, failed, unavailable, and pending work.

Deferred: launch at login, per-app rules, artwork editing/export, cloud sync, updates.
