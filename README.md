# Octapuss

A native macOS pointer playground with a joyful octopus-and-cat identity.

**Status: app-local repair · 15 October 2026.** The repository contains a native SwiftUI/AppKit app, a minimal Xcode app project, and focused executable regression checks.

The first idea is deliberately small: choose a static pointer style, try it at actual size, and enable or pause it from a native Mac app. The brand combines a cat-eared octopus mascot with clear, practical pointer artwork.

The supported product direction is **app-local customization inside Octapuss**. Cursor-hiding and across-app companion experiments have been removed from the executable. See [historical feasibility](docs/FEASIBILITY_RESULTS.md).

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

The app includes three cursor colors, three sizes, saved light/dark preview backgrounds, menu-bar access, and working Restore/Resume controls. A native preview view owns its cursor rectangle and real Boop button. Each click updates visible feedback. Restore disables the custom cursor inside the playground; choosing a preset while paused preserves that state. No global polling timer, overlay panel, or cursor-hide call runs.

Build with the installed Command Line Tools:

```sh
rtk proxy zsh scripts/build-phase0.sh
```

The script prints `/tmp/octapuss-phase0/Octapuss.app`. It uses the locally installed macOS 15.4 SDK as a workaround for the installed Command Line Tools mismatch, with an `OCTAPUSS_SDK_PATH` override. It cleans its temporary module cache on exit.

Run focused regression checks with `rtk proxy zsh scripts/build-phase0.sh --check`. These exercise the real native view and isolated preferences; they are executable checks, not an XCTest suite.

`Octapuss.xcodeproj` contains the shared Octapuss app scheme. With full Xcode selected, use `xcodebuild -project Octapuss.xcodeproj -scheme Octapuss build CODE_SIGNING_ALLOWED=NO`. Full Xcode is unavailable on this host, so that route and XCTest execution remain **untested**. See [repair verification](docs/REPAIR_VERIFICATION.md) for the exact evidence and limits.

See [the measured Phase 0 result](docs/FEASIBILITY_RESULTS.md) before choosing the next backend.

## Build sequence

1. Verify the developer tools and prove the cursor approach on this Mac.
2. Decide the supported product scope from that evidence.
3. Build the native app shell and one pointer family.
4. Add the proven engine, recovery, and settings.
5. Test the declared support matrix and prepare a local beta.

**Selected scope:** app-local customization. Across-app behavior requires a future explicit scope decision.

No system permissions, login items, helpers, or persistent system cursor changes are installed by the proof.
