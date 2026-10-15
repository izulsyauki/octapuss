# Octapuss implementation plan

Execution status · **Phase 0 proof completed and app-local customization selected on 1 October 2026.** See [FEASIBILITY_RESULTS.md](FEASIBILITY_RESULTS.md). The app-local behavioral repair is recorded in [REPAIR_VERIFICATION.md](REPAIR_VERIFICATION.md). Global experiments have been removed from the executable; they remain historical evidence only. Phases below describe the remaining productization plan, not a claim that all exit criteria have passed.

Current implementation: a minimal `Octapuss.xcodeproj` with shared app scheme exists, but Xcode compilation, signing/capabilities, and XCTest remain untested; no XCTest target exists. Command Line Tools builds and isolated executable native regression checks are recorded in the repair verification. The native preview owns rendering, cursor rectangles, tracking, and the working Boop button, replacing the transparent overlay. Restore pauses the local custom cursor until Resume preview; preset changes and preference reset preserve pause. Style, size, and background persist. Relaunch starts the local preview active with a fresh click count. The window defaults to 840 × 560 pt, has a 760 × 500 pt minimum, and scrollable main content. Preserve existing visual tokens.

## Milestones

| Phase | Work | Exit criterion | Depends on |
| --- | --- | --- | --- |
| 0 | Toolchain check and native cursor feasibility proof | Evidence report completed; app-local scope selected | Completed proof |
| 1 | Xcode app shell, shared state, window, Settings, menu bar | Fresh app launches local preview only; Open/Settings/Quit work; closing window keeps utility accessible | Phase 0 route selected |
| 2 | Bundled pointer metadata, one arrow family, preview, size controls | All presets/sizes preview accurately; invalid assets fail safely | Phase 1 |
| 3 | Selected cursor backend, session lifecycle, Pause/Restore | Real scope works across its declared contexts; all runtime states truthful | Phase 0 + Phase 2 |
| 4 | Preference persistence, scope guidance, diagnostics | Relaunch begins with local preview active and preferences retained; no global permissions requested | Phase 3 |
| 5 | Compatibility, performance, accessibility, and local beta | Required checks pass; untested contexts disclosed; reproducible build available | Phase 4 |

Each phase should leave a runnable, reviewable result. Do not build all phases before testing the engine, and do not make a web demo the product implementation.

## Phase 0: prove the difficult part

Follow [FEASIBILITY.md](FEASIBILITY.md). Use one simple diagnostic cursor; branding polish can wait. Produce `FEASIBILITY_RESULTS.md` and a demo before the full app shell. Passing preview or movement tracking alone is insufficient.

If the selected developer directory remains Command Line Tools, locate an existing full Xcode installation and report what is needed. Do not silently download Xcode or change system settings. A toolchain limitation does not justify claiming a native build was verified.

If public global replacement fails, finish the evidence report and present the actual alternatives. Keep the existing product scope unresolved until the user chooses an alternative or a private-backend research route.

## Phase 1: native shell

- Retain the existing macOS app target and shared scheme; add a focused test target when full Xcode is available.
- Implement a single shared AppStore and the explicit runtime state vocabulary.
- Add Customize, Settings, and menu-bar commands with native controls.
- Keep launch app-local only, with Restore/Quit available and explicit Resume after Restore.
- Keep storage and cursor engine behind small boundaries.

Accept when the app runs as a utility, window/menu state stays consistent, and no global permission is requested simply on launch.

## Phase 2: pointer family and preview

- Produce the editable arrow master and transparent scaled representations.
- Add Ink, Tide, and Blush variants with a consistent hotspot.
- Validate pack metadata and keep unknown/corrupt selections on safe defaults.
- Add an AppKit preview region, Light/Dark test background, and three size presets.
- Apply the proposed design tokens through one native semantic source.

Accept when actual-size clicks land at the visible tip, borders look sharp on available backing scales, and entering/leaving the preview restores the normal pointer correctly.

## Phase 3: selected engine and recovery

- Implement only the backend selected by the feasibility decision.
- Serialize start/update/stop and reject late callbacks from cancelled sessions.
- Add accurate capability/status reporting and permission checks.
- Handle screen changes, sleep/session deactivation, and backend failures.
- Make preset updates transactional and restoration idempotent; expose incomplete restoration and retain ownership for recovery.
- If a system replacement route needs a helper, document why and verify baseline capture/restoration before adding automatic reapplication.

Accept when the user's chosen scope works in its declared contexts and recovery survives every required case. An invisible pointer, focus stealing, duplicate replacement arrow, or unusable text/resize cue is a release blocker.

## Phase 4: polish the utility behavior

- Persist style, size, and preview background without persisting runtime pause state or click count. Launch activates only the app-local preview.
- Explain only required permissions at the moment of need and recheck on return.
- Add concise local compatibility/error details and safe retry.
- Complete keyboard navigation, VoiceOver descriptions, focus, and appearance handling.
- Keep preference reset separate from Restore system pointer.

Accept when first launch, denied access, revoked access, corrupted settings, restart, and incomplete restoration all produce useful and truthful UI. A recovery record must never turn into automatic enable-on-launch behavior.

## Phase 5: beta readiness

Run [TEST_PLAN.md](TEST_PLAN.md), capture native UI evidence in light/dark at the proposed minimum/default sizes, and fix material findings. Record performance measurements and the exact support matrix.

Deliver a local build with build/run instructions, limitation notes, and recovery instructions. Configure external signing/notarization only when distribution is requested and credentials are available. Never mark other OS/hardware combinations supported merely because compilation targets them.

## Suggested work chunks for the implementation model

| Chunk | Reviewable deliverable |
| --- | --- |
| A | Phase 0 proof + evidence report |
| B | Native shell + state/persistence boundaries |
| C | Cursor assets + validation + actual-size preview |
| D | Chosen backend + lifecycle/recovery checks |
| E | Permission/settings UX + accessibility |
| F | Support matrix + measured beta build |

Estimate later phases after Chunk A. Private API maintenance, missing Xcode, unavailable test displays, and distribution setup can materially change the work; a full delivery-date promise before the engine proof would be unreliable.

## Completion definition

The first release is complete only when the chosen app-local scope, user controls, hotspot accuracy, runtime honesty, recovery, declared compatibility, and local build instructions all pass. The repair verification records the current evidence and untested cases; it does not establish global cursor replacement.

Later roadmap: animation only after static correctness; pack import/editor after validation boundaries; per-app rules after a trustworthy application-context mechanism; launch at login after restart/recovery; distribution and updates after a dependable beta.
