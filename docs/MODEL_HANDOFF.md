# Handoff after the Phase 0 proof

**Latest user direction, 15 October 2026:** system-arrow customization outside Octapuss is now requested. Read `docs/SYSTEM_CURSOR.md` and `Phase0/SystemCursorBackend.swift` before using the older app-local handoff below. Preserve baseline backup, explicit Apply/Restore, the independent preview, and crash recovery; never substitute an overlay for native registration.

The native Phase 0 feasibility app is implemented, and the user selected app-local customization as the product direction on 1 October 2026. The 15 October behavioral repair is recorded in `docs/REPAIR_VERIFICATION.md`; read it alongside the historical `docs/FEASIBILITY_RESULTS.md` before continuing.

## Copy this prompt when ready

```text
Work in /Users/satmac/work/my_project/octapuss.

Read the user/repository instructions, including /Users/satmac/.codex/RTK.md.
Prefix every shell command with rtk; use rtk proxy for unsupported commands.
Read README.md, PRODUCT.md, DESIGN.md, docs/ARCHITECTURE.md,
docs/FEASIBILITY.md, docs/IMPLEMENTATION_PLAN.md, and docs/TEST_PLAN.md.
Honor any newer user decisions over the proposal's assumptions.

Review the current app-local proof and docs/REPAIR_VERIFICATION.md.
Global polling, companion panels, and cursor-hiding experiments have
been removed from the executable. Their historical evidence remains in
docs/FEASIBILITY_RESULTS.md. Public global replacement is not established.

Inspect the existing SwiftUI/AppKit proof before changing it. Preserve its
native app-local preview, normal input and focus, cursor roles, and recovery.
The native preview owns rendering, cursor rectangles, tracking, and its
working Boop button; do not reintroduce the transparent hit-test overlay.
Restore pauses the local custom cursor until Resume preview. Style/size
changes and preference reset preserve pause. Style, size, and background
persist; local preview starts active with a fresh click count on relaunch.
Preserve the existing design tokens, 840x560 pt default window, 760x500 pt
minimum, and scrollable main content.
Avoid unrelated permissions, focus stealing, private cursor changes,
unjustified helpers, and copying upstream code/assets with reuse limits.

Check full Xcode before claiming a build. At planning time the selected
developer directory was /Library/Developer/CommandLineTools and the host
was macOS 26.5.1. Recheck; this is not proof Xcode is absent elsewhere.
Do not silently download Xcode or change system configuration.

Continue through Phases 1–5 with the app-local cursor backend. Keep the
removed global experiments as historical evidence only.
Do not implement a private backend or turn either experiment into the
product promise without a new explicit user decision.
```

## Execution instruction after the choice

After the feasibility result and scope are accepted, the next instruction can be:

```text
Continue Octapuss using the selected backend and support scope recorded
in docs/FEASIBILITY_RESULTS.md. Implement Phases 1–5 in
docs/IMPLEMENTATION_PLAN.md, preserving the agreed product/design scope.
Deliver a runnable native app, meaningful automated and manual checks,
truthful compatibility notes, and build/recovery instructions. Keep
animation, import/editor, per-app rules, and cloud features deferred.
```

## Planning decisions to preserve

- Octapuss is a native macOS utility with an octopus-and-cat identity.
- First release proposes a static arrow family, three colors, three sizes, and actual-size preview.
- Preview is independent of global engine capability and permission.
- Runtime status comes from the backend, not a saved Enable flag.
- Pause/Restore/Quit and recovery are part of the first release.
- Restore pauses the custom cursor in the labeled playground; only Resume preview reactivates it. Quit restores before exiting.
- No public system-wide replacement contract was established by research.
- Private replacement is a separate route decision; companion mode is a distinct scope.
- The Command Line Tools build, executable native regression checks, and bounded live UI checks are recorded in `docs/REPAIR_VERIFICATION.md`. A minimal `Octapuss.xcodeproj` with shared scheme exists, but full Xcode compilation, signing/capabilities, and XCTest are untested. No XCTest target exists. Final assets and a full support matrix remain incomplete.
