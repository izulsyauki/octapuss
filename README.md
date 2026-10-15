# Octapuss

A native macOS pointer playground with a joyful octopus-and-cat identity.

**Status: native cursor-pack experiment · 15 October 2026.** The SwiftUI/AppKit app supports explicit full-pack application and an independent local playground. The Minecraft fixture maps 13 roles across 56 system slots on this host, including animated loading cursors. See [full-pack behavior and verification](docs/FULL_PACKS.md).

The first idea is deliberately small: choose a static pointer style, try it at actual size, and enable or pause it from a native Mac app. The brand combines a cat-eared octopus mascot with clear, practical pointer artwork.

The requested product direction is **native system cursor customization**. The backend registers assigned cursor roles with macOS using private APIs. Cursor-hiding and pointer-following overlays are excluded. See [system backend findings and limits](docs/SYSTEM_CURSOR.md).

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
2. In Octapuss, choose **Add to your collection → Import cursor files…** (up to 64 files) or **Import unzipped set folder…**. Files imported together form one set.
3. Select a set in the left library, choose a cursor from its gallery, choose a size, and try it in the playground.
4. Check each file's **Use for** role, then click **Apply pack** to apply all mapped roles outside Octapuss. Built-ins and unnamed single imports use **Apply system arrow**. **Restore system pointer** returns to the saved baseline.

`.cur` files retain their click hotspot and aspect ratio. Valid `.ani` files retain animation; native playback uses up to 24 uniform steps. Recognizable filenames map text, link, resize, loading, and other roles; unknown names can be assigned manually. Windows handwriting and alternate-select have no equivalent global slot. Older first-frame imports can be updated from their original folder. The app stores local copies, so moving downloads does not break the library. Removing a file leaves its download and the applied system effect unchanged.

The redesigned library shows every imported cursor in the selected set. Built-in templates show their custom arrow plus native macOS shapes, clearly labeled as unchanged. See [the redesign and references](docs/UI_REDESIGN.md) and [import formats, limits, and verification](docs/CURSOR_IMPORT.md).

## Phase 0 proof

Choose a preset or imported set and size, then press Apply to register it outside Octapuss. Selection changes remain a preview until Apply is pressed again. Restore restores every owned slot and pauses the local preview; Resume reactivates only the local preview. A durable backup and temporary crash-recovery subprocess protect applied registrations. Nothing is installed at login.

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

**Selected scope:** native cursor-pack customization. This private-API experiment is for direct distribution; App Store compatibility and universal application/OS coverage are not claimed.

No system permissions, login items, helpers, or persistent system cursor changes are installed by the proof.
