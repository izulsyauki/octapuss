# Octapuss

A native macOS pointer playground with a joyful octopus-and-cat identity.

**Status: stability verification in progress · 16 October 2026.** The SwiftUI/AppKit app supports explicit native cursor-pack application and an independent local playground. The Minecraft fixture maps 13 roles across 56 system slots on this host, including animated loading cursors. See [the current stability report and remaining gates](docs/STABILITY_REPORT.md) and [full-pack verification](docs/FULL_PACKS.md).

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

During Apply, Octapuss shows **Applying…**, a progress indicator, and the pack's Busy artwork in the action bar and playground. If Busy is missing, it uses Working artwork when available, otherwise the standard progress indicator. Animated artwork keeps playing while registration runs off the UI thread; Reduce Motion keeps artwork static. **Cancel and restore** waits for the current native step, restores the captured baseline, and pauses preview. Selecting a cursor for immediate preview does not manufacture a loading delay. See [Apply feedback and cancellation](docs/APPLY_PROGRESS.md).

`.cur` files retain their click hotspot and aspect ratio. Valid `.ani` files retain animation; native playback uses up to 24 uniform steps. Recognizable filenames map text, link, resize, loading, and other roles; unknown names can be assigned manually. Windows handwriting and alternate-select have no equivalent global slot. Older first-frame imports can be updated from their original folder. The app stores local copies, so moving downloads does not break the library. Removing a file leaves its download and the applied system effect unchanged.

Native property-list `.cursor` themes such as **Anya.cursor** can also be imported through **Import cursor files…**, one theme at a time. Their animations and supported native roles become one selectable set. See [native theme support and verification](docs/NATIVE_THEMES.md).

### Assign cursor roles manually

Select an imported pack, click a cursor tile, then choose its role from **Use for** above the gallery. For example, assign the normal pointer to **Normal select**, the text pointer to **Text select**, and the hand to **Link select**. Choose **Unassigned** to exclude a file. Assignments save immediately and survive relaunch and matching folder updates; click **Apply pack** when ready to update the system cursor.

Filename detection recognizes exact role names and theme prefixes separated by ` - `, such as `goku - normal`, `goku - text`, `goku - horizontal`, `goku - vertical`, `goku - d1` (NW–SE), and `goku - d2` (NE–SW). Unknown filenames stay unassigned. Manual choices always take priority. Avoid assigning two files to the same role: overlapping system slots block Apply with an explanation. Windows handwriting and alternate-select lack global macOS slots; choose a supported role if you want to repurpose their artwork.

The redesigned library shows every imported cursor in the selected set. Built-in templates show their custom arrow plus native macOS shapes, clearly labeled as unchanged. See [the redesign and references](docs/UI_REDESIGN.md) and [import formats, limits, and verification](docs/CURSOR_IMPORT.md).

## Delete a cursor pack

Select an imported pack and click **Delete pack…** beside its title, or right-click its sidebar entry. Confirm the named pack and cursor count. **Undo deletion** restores the last deleted pack until another deletion or app quit. Built-in packs cannot be deleted.

This removes the pack from Octapuss's library; original files and any applied system cursor stay unchanged. Use **Restore system pointer** to turn off the applied effect. See [deletion and Undo behavior](docs/PACK_DELETION.md).

## Phase 0 proof

Choose a preset or imported set and size, then press Apply to register it outside Octapuss. Selection changes remain a preview until Apply is pressed again. Restore restores every owned slot and pauses the local preview; Resume reactivates only the local preview. A durable backup and temporary crash-recovery subprocess protect applied registrations. Nothing is installed at login.

While Octapuss is running, the applied artwork resumes after sleep or unlock. Manual Restore cancels automatic resumption. Choose **Quit Octapuss** from its menu-bar icon to restore the system pointer and fully exit; this does not install persistence across logout or reboot.

### Keep the cursor running in the background

Choosing **Quit** from the Dock keeps Octapuss running in the menu bar with your applied cursor active. The app hides its windows and removes its running Dock icon. **⌘Q** does the same; the app menu labels this action **Keep Running in Menu Bar**.

Click the Octapuss icon in the macOS menu bar and choose **Open Octapuss** to return to the library. Reopening the app also brings it back. Choose **Quit Octapuss** in that menu to fully exit and restore your pointer. If restoration fails, the app stays open and shows the recovery error. Closing a window also keeps the app running. macOS logout, restart, and shutdown can still terminate it normally. See [background behavior and verification](docs/BACKGROUND_LIFECYCLE.md).

### Lock screen and persistence limits

Custom cursors are not guaranteed on the macOS lock screen or protected authentication surfaces. macOS can force its own system cursor there; this is a platform limitation, also documented by [MaCursor](https://github.com/writronic/MaCursor#cursors-macursor-cannot-replace). Seeing the default cursor while locked does not mean your saved pack was removed.

Octapuss temporarily restores its owned cursor registrations before sleep, screen lock, or session deactivation, remembers the exact applied pack, and automatically reapplies it after you return while the app remains running. Closing the main window or choosing Dock Quit keeps Octapuss running in the menu bar. **Restore system pointer** cancels automatic reapplication. Fully quitting from the menu-bar icon or crashing restores the baseline; automatic startup and persistence across logout or reboot are not implemented. Physical lock-screen behavior and notification delivery across macOS versions remain unverified; see [sleep and lock persistence](docs/FULL_PACKS.md#sleep-and-lock-persistence).

If Octapuss reports **Pointer color override**, open System Settings → Accessibility → Display → Pointer and choose **Reset Colors**, then Apply again. Custom macOS outline/fill colors can override cursor themes. Octapuss leaves those preferences unchanged and explains the conflict.

Build with the installed Command Line Tools:

```sh
rtk proxy zsh scripts/build-phase0.sh
```

The script prints `/tmp/octapuss-phase0/Octapuss.app`. It uses the locally installed macOS 15.4 SDK as a workaround for the installed Command Line Tools mismatch, with an `OCTAPUSS_SDK_PATH` override. It cleans its temporary module cache on exit.

Run focused regression checks with `rtk proxy zsh scripts/build-phase0.sh --check`. These exercise the real native view and isolated preferences; they are executable checks, not an XCTest suite.

Production code lives in `Octapuss/`, separated into application workflows, Foundation-only models, UI features, native platform integration, and persistence. `AppStore` coordinates the UI; dedicated controllers own the library and cursor runtime. See [architecture and extension guidelines](docs/ARCHITECTURE.md) for where to make changes. Run `rtk proxy python3 scripts/check-architecture.py` to check dependency rules and Xcode/CLI source membership before submitting changes. Saved packs, preference keys and recovery journals retain their existing formats.

The [refactor verification report](docs/REFACTOR_VERIFICATION.md) records baseline/post-change checks, storage and concurrency regression cases, render evidence, and remaining limitations.

`Octapuss.xcodeproj` contains the shared Octapuss app scheme. With full Xcode selected, use `xcodebuild -project Octapuss.xcodeproj -scheme Octapuss build CODE_SIGNING_ALLOWED=NO`. Full Xcode is unavailable on this host, so that route and XCTest execution remain **untested**. See [repair verification](docs/REPAIR_VERIFICATION.md) for the exact evidence and limits.

See [the measured Phase 0 result](docs/FEASIBILITY_RESULTS.md) before choosing the next backend.

## Build sequence

The original feasibility milestone is complete on the available Mac. The implementation has progressed through the library, imports, role mapping, recovery, and background utility features; current work is stability verification before a local beta. See [the updated milestone plan](docs/IMPLEMENTATION_PLAN.md). The sequence below describes delivery order, not unimplemented features.

1. Verify the developer tools and prove the cursor approach on this Mac.
2. Decide the supported product scope from that evidence.
3. Build the native app shell and one pointer family.
4. Add the proven engine, recovery, and settings.
5. Test the declared support matrix and prepare a local beta.

**Selected scope:** native cursor-pack customization. This private-API experiment is for direct distribution; App Store compatibility and universal application/OS coverage are not claimed.

No system permissions, login items, helpers, or persistent system cursor changes are installed by the proof.

## Local candidate

Build and package an experimental local candidate:

```sh
rtk proxy env OCTAPUSS_BUILD_DIR="$PWD/.build/stability" zsh scripts/build-phase0.sh
rtk proxy zsh scripts/package-local-candidate.sh
```

The ZIP, checksum, validation report, and recovery instructions are written to `.build/local-candidate/`. This is an ad-hoc signed development candidate. Developer ID signing, notarization, full Xcode validation, and the remaining manual checks are required before an external-release claim. No security settings are bypassed by these scripts.
