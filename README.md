# Octapuss

A native macOS pointer playground with a joyful octopus-and-cat identity.

**Status: system-arrow backend experiment · 15 October 2026.** The user has requested customization outside Octapuss. The native SwiftUI/AppKit app now includes an explicit Apply system arrow action and an independent local playground.

The first idea is deliberately small: choose a static pointer style, try it at actual size, and enable or pause it from a native Mac app. The brand combines a cat-eared octopus mascot with clear, practical pointer artwork.

The requested product direction is **native system arrow customization**. The new backend registers arrow images with macOS using private APIs and preserves other cursor roles. Cursor-hiding and pointer-following overlays are excluded. See [system backend findings and limits](docs/SYSTEM_CURSOR.md).

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

## Use downloaded cursors

1. Download a `.cur` or `.ani` file from [RW Designer's cursor library](https://www.rw-designer.com/cursor-library). If you download a ZIP set, unzip it first.
2. In Octapuss, choose **Import cursor…** or **+** under **Your cursors** and select up to 16 files.
3. Select an imported cursor, choose a size, and try it in the playground.
4. Click **Apply system arrow** to use it outside Octapuss. **Restore system pointer** returns to the saved baseline.

`.cur` files retain their click hotspot and aspect ratio. `.ani` files use their **first sequence frame only**; animation is not played. Importing a whole set does not map its hand/text/resize roles: the selected file replaces the system arrow only. The app stores its own local image copy, so moving the original download does not break the library. Remove from library leaves the download and any applied system arrow unchanged.

See [import formats, limits, and verification](docs/CURSOR_IMPORT.md).

## Phase 0 proof

Choose a preset and size, then press **Apply system arrow** to register it outside Octapuss. Changes to the selection remain a preview until Apply is pressed again. Restore restores the saved system-arrow baseline and pauses the local preview; Resume reactivates only the local preview. A durable backup and temporary crash-recovery subprocess protect applied registrations. Nothing is installed at login.

If Octapuss reports **Pointer color override**, open System Settings → Accessibility → Display → Pointer and choose **Reset Colors**, then Apply again. Custom macOS outline/fill colors can override cursor themes. Octapuss leaves those preferences unchanged and explains the conflict.

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

**Selected scope:** system-arrow customization, following the user's updated request. This private-API experiment is for direct distribution; App Store compatibility and universal application/OS coverage are not claimed.

No system permissions, login items, helpers, or persistent system cursor changes are installed by the proof.
