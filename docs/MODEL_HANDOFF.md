# Handoff after the Phase 0 proof

The native Phase 0 feasibility app is implemented. The full product has not begun because the global replacement gate remains inconclusive. Read `docs/FEASIBILITY_RESULTS.md` before continuing.

## Copy this prompt when ready

```text
Work in /Users/satmac/work/my_project/octapuss.

Read the user/repository instructions, including /Users/satmac/.codex/RTK.md.
Prefix every shell command with rtk; use rtk proxy for unsupported commands.
Read README.md, PRODUCT.md, DESIGN.md, docs/ARCHITECTURE.md,
docs/FEASIBILITY.md, docs/IMPLEMENTATION_PLAN.md, and docs/TEST_PLAN.md.
Honor any newer user decisions over the proposal's assumptions.

Review the completed Phase 0 proof and docs/FEASIBILITY_RESULTS.md. The
intended working scope was a static custom pointer across other macOS
apps, but public global replacement is not established. Do not call
preview-only or companion behavior successful global replacement.

Inspect the existing SwiftUI/AppKit proof before changing it. Preserve its
independent app-local preview, truthful click-through companion, documented
hiding limitation, normal input and focus, cursor roles, and recovery.
Avoid unrelated permissions, focus stealing, private cursor changes,
unjustified helpers, and copying upstream code/assets with reuse limits.

Check full Xcode before claiming a build. At planning time the selected
developer directory was /Library/Developer/CommandLineTools and the host
was macOS 26.5.1. Recheck; this is not proof Xcode is absent elsewhere.
Do not silently download Xcode or change system configuration.

Get the user's product-scope decision before implementing a private
backend or substituting a companion. The choices are actual global-theme
research, an honest additive pointer companion, or app-local cursor
customization. After the choice, update PRODUCT.md and the result report,
then implement only the selected route through Phases 1–5.
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
- Global Restore keeps the labeled preview available; Quit removes it. Incomplete cleanup must remain a recovery state with owned baseline/resources retained.
- No public system-wide replacement contract was established by research.
- Private replacement is a separate route decision; companion mode is a distinct scope.
- The Phase 0 app builds and its native UI was inspected. Final assets, an Xcode project, automated tests, and a full support matrix have not been completed.
