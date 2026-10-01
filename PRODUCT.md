# Octapuss product brief

Product brief · Phase 0 proof implemented on 1 October 2026.

## Product intent

Give Mac users a simple way to personalize their mouse pointer with tasteful octopus-and-cat styles while retaining a clear click location and an immediate way to return to the system pointer.

Primary user: an individual Mac owner who enjoys desktop personalization and wants a utility that stays out of the way. The first surface is an **Operate** interface: choosing, trying, and controlling a pointer takes precedence over decoration.

## Confirmed and assumed

| Item | Status |
| --- | --- |
| Name: Octapuss | User supplied |
| Platform: macOS | User supplied |
| Initial feature: custom mouse pointer appearance | User supplied |
| Theme: octopus + cat | User supplied |
| Plan before implementation | User supplied; Phase 0 is now implemented |
| Pointer should work across other apps | Working assumption; clarification requested |
| Static pointer first; animation later | Proposed scope to keep version one small |
| Native SwiftUI/AppKit, local data, no account | Architecture recommendation |
| macOS 14+ deployment target | Provisional; retain only if tested and needed |
| Direct local beta before choosing a store route | Recommendation, dependent on cursor backend |

## First release

One arrow family with three color presets: **Ink**, **Tide**, and **Blush**. A recognizable arrow apex is the click hotspot; small cat-ear or tentacle details sit behind it.

The release includes:

- An actual-size preview inside Octapuss, with light and dark test surfaces.
- Pointer selection and Small / Medium / Large sizes; proposed artwork canvas sizes are 24 / 32 / 40 logical points, subject to visual testing.
- A clearly scoped Enable action, Pause/Resume, and Restore system pointer.
- A persistent menu-bar control and a small customization window.
- Saved pack, size, and appearance preferences.
- Permission guidance only when the selected engine needs it.
- Clear runtime status, safe shutdown, and an off-by-default first launch.

**Release scope depends on Phase 0.** True system-wide replacement is the desired assumption. An overlay with the native pointer still visible is a pointer companion and must be named that way. A preview-only app or companion is an alternative requiring a product decision, not a completed version of the assumed global-pointer feature.

## Deferred

Animated pointers, trails, sound, pack import/export, a pointer editor, per-app rules, cloud sync, accounts, payments, automatic updates, theme scheduling, Windows/Linux versions, and global automatic arrow/I-beam/resize detection.

Launch at login can follow the first dependable beta. Reopening Octapuss must initially restore preferences without automatically activating the effect.

## Success criteria

These are targets, not measured results:

1. A new user can select and preview a pointer without granting unrelated permissions.
2. Every supported size keeps the visible arrow apex aligned with the real click position.
3. The enabled effect remains accurate during the explicitly tested cross-app workflow.
4. Pause and Restore stop across-app effects and leave a usable system pointer outside the labeled preview. Quit also removes the preview cursor.
5. Runtime status never claims global replacement when only preview or companion behavior is available.
6. The app handles the compatibility and recovery cases in [the test plan](docs/TEST_PLAN.md).

## Decisions still open

- Confirm whether the first release needs actual global replacement, animation, or only in-app customization.
- If public APIs cannot deliver global replacement, choose whether to investigate an isolated private-API backend, accept a pointer companion, or pause that feature.
- Confirm minimum macOS version, Intel support, and distribution route after the first experiment.
- Review the proposed visual direction and pointer sketches before final asset production.

Restore preserves the in-app preview so the user can continue trying styles. Its status must make that scope clear. If restoration fails, retain recovery ownership and show an explicit recovery state rather than claiming customization is off.

The implementation model should resolve open decisions through evidence or user direction, rather than silently expanding or reducing the scope.
