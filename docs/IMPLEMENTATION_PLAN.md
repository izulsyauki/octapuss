# Octapuss implementation plan

Execution status · **Phase 0 proof completed on 1 October 2026.** Its global-replacement conclusion is inconclusive and not accepted; see [FEASIBILITY_RESULTS.md](FEASIBILITY_RESULTS.md). Phases 1–5 are not started and require the user's backend/scope choice.

## Milestones

| Phase | Work | Exit criterion | Depends on |
| --- | --- | --- | --- |
| 0 | Toolchain check and native cursor feasibility proof | Evidence report completed; backend/scope decision remains open | Completed proof |
| 1 | Xcode app shell, shared state, window, Settings, menu bar | Fresh app launches Off; Open/Settings/Quit work; closing window keeps utility accessible | Phase 0 route selected |
| 2 | Bundled pointer metadata, one arrow family, preview, size controls | All presets/sizes preview accurately; invalid assets fail safely | Phase 1 |
| 3 | Selected cursor backend, session lifecycle, Pause/Restore | Real scope works across its declared contexts; all runtime states truthful | Phase 0 + Phase 2 |
| 4 | Preference persistence, permission guidance, diagnostics | Denial/revocation/failure recover; relaunch begins Off or RecoveryRequired according to unresolved effects, with preferences retained | Phase 3 |
| 5 | Compatibility, performance, accessibility, and local beta | Required checks pass; untested contexts disclosed; reproducible build available | Phase 4 |

Each phase should leave a runnable, reviewable result. Do not build all phases before testing the engine, and do not make a web demo the product implementation.

## Phase 0: prove the difficult part

Follow [FEASIBILITY.md](FEASIBILITY.md). Use one simple diagnostic cursor; branding polish can wait. Produce `FEASIBILITY_RESULTS.md` and a demo before the full app shell. Passing preview or movement tracking alone is insufficient.

If the selected developer directory remains Command Line Tools, locate an existing full Xcode installation and report what is needed. Do not silently download Xcode or change system settings. A toolchain limitation does not justify claiming a native build was verified.

If public global replacement fails, finish the evidence report and present the actual alternatives. Keep the existing product scope unresolved until the user chooses an alternative or a private-backend research route.

## Phase 1: native shell

- Create one macOS app target and a focused test target.
- Implement a single shared AppStore and the explicit runtime state vocabulary.
- Add Customize, Settings, and menu-bar commands with native controls.
- Make the initial state Off and Restore/Quit available in every runtime state.
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

- Persist typed settings without persisting automatic enable-on-launch behavior.
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

The first release is complete only when the chosen scope, user controls, hotspot accuracy, runtime honesty, recovery, declared compatibility, and local build instructions all pass. A design mockup, app-local preview, or unverified global overlay is a milestone result, not a completed global-pointer app.

Later roadmap: animation only after static correctness; pack import/editor after validation boundaries; per-app rules after a trustworthy application-context mechanism; launch at login after restart/recovery; distribution and updates after a dependable beta.
