# Octapuss

A proposed macOS pointer personalization app with an octopus-and-cat identity.

**Status: Phase 0 cursor proof implemented · 1 October 2026.** The repository now contains a native SwiftUI/AppKit feasibility app. The full product and Xcode project have not started because system-wide replacement remains an explicit scope gate.

The first idea is deliberately small: choose a static pointer style, try it at actual size, and enable or pause it from a native Mac app. The brand combines a cat-eared octopus mascot with clear, practical pointer artwork.

The working assumption is customization **across other macOS apps**. That scope has not yet been confirmed by the user. Genuine system-wide replacement is the first technical gate: Apple's public app cursor APIs and a pointer-following overlay do not by themselves establish a reliable global replacement mechanism. See [feasibility](docs/FEASIBILITY.md).

## Read the plan

| Document | Purpose |
| --- | --- |
| [PRODUCT.md](PRODUCT.md) | Intent, first release, assumptions, and boundaries |
| [DESIGN.md](DESIGN.md) | Octopus/cat identity, window layout, interactions, and visual tokens |
| [Architecture](docs/ARCHITECTURE.md) | Native stack, modules, data, state, and recovery |
| [Feasibility](docs/FEASIBILITY.md) | Verified macOS constraints, sources, and the first experiment |
| [Implementation plan](docs/IMPLEMENTATION_PLAN.md) | Ordered milestones, dependencies, and acceptance criteria |
| [Test plan](docs/TEST_PLAN.md) | Pointer correctness, compatibility, permissions, and release checks |
| [Model handoff](docs/MODEL_HANDOFF.md) | A ready-to-use prompt for the model that will implement the plan |

## Phase 0 proof

The proof includes the three planned cursor colors, Small/Medium/Large app-local preview, light/dark test surfaces, a menu-bar utility, a click-through pointer companion, Restore, and a balanced foreground cursor-hide check. Its arrow-tip hotspot scales with the selected size, the preview cursor layer passes clicks through to its sample controls, and the standard Command-Q path runs owned-effect cleanup. The build produces an arm64 app with a macOS 14.0 minimum deployment target; human-visible hotspot accuracy, cross-app behavior, other displays, performance, VoiceOver, and Force Quit recovery remain **untested**. The companion deliberately leaves the native pointer visible and is not labelled as replacement.

Build with the installed Command Line Tools:

```sh
rtk proxy zsh scripts/build-phase0.sh
```

The script prints the generated ad-hoc signed app path, currently `/tmp/octapuss-phase0/Octapuss Cursor Lab.app`. It uses the locally installed macOS 15.4 SDK to avoid a patch mismatch in the default 26.5 Command Line Tools SDK and cleans its temporary module cache on exit. Full Xcode is not installed in `/Applications`, so there is no `.xcodeproj` or `xcodebuild test` result yet.

See [the measured Phase 0 result](docs/FEASIBILITY_RESULTS.md) before choosing the next backend.

## Build sequence

1. Verify the developer tools and prove the cursor approach on this Mac.
2. Decide the supported product scope from that evidence.
3. Build the native app shell and one pointer family.
4. Add the proven engine, recovery, and settings.
5. Test the declared support matrix and prepare a local beta.

**Next decision:** choose actual global-theme research, the honest pointer companion, or an app-local customization scope. A polished preview does not count as proof that custom pointers work across macOS.

No system permissions, login items, helpers, or persistent system cursor changes are installed by the proof.
