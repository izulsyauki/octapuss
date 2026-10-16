# Stability verification

Run date: 16 October 2026. This is an experimental local candidate, not a declaration of beta or external-release readiness. Current scope is native cursor-pack customization plus an independent AppKit playground. The original feasibility report is historical.

## Environment and build

- Host: Mac14,7, macOS 26.5.1, arm64; one built-in Retina display discovered. Other displays, Intel, and older macOS versions are unavailable here.
- Command Line Tools builder uses the installed macOS 15.4 SDK workaround. Deployment target 14.0 is not a compatibility certification.
- Xcode project and both bundle property lists pass `plutil -lint`. Local `xcodebuild` cannot run because full Xcode is absent. No XCTest target exists.
- A read-only hosted macOS workflow was added to validate Release with Xcode and run synthetic checks. [Run 38864881747](https://github.com/izulsyauki/octapuss/actions/runs/38864881747) did not start any build steps: GitHub's check annotation says, "The job was not started because your account is locked due to a billing issue." No hosted compilation result is claimed. The repository owner must resolve that account restriction before rerunning; no billing settings were changed.
- Initial locally ad-hoc signed candidate: `.build/candidate/Octapuss.app`, built from source commit `2c19ed0`. Deep/strict signature and packaged-helper verification passed. `.build/stability/Octapuss.app` was used for the initial interactive/resource checks. The subsequent `.build/quiet-registration/Octapuss.app` fixed forced role cycling. The latest candidate is `.build/apply-progress/Octapuss.app`, with responsive Apply feedback and a verified deep/strict signature; it supersedes earlier builds in the packaged ZIP.
- No Developer ID Application identity is available in the local signing query. Developer ID signing, hardened-runtime validation, notarization, stapling, and clean-machine Gatekeeper verification remain unavailable/pending. No credentials were requested or security settings changed.

## Checks

| Area | Result | Evidence / limitation |
| --- | --- | --- |
| Preferences/import/roles/deletion | Pass | Executable regression suite with Anya, Minecraft, and Son Goku fixtures; original downloads preserved |
| Transactions and ownership | Pass | Rollback, conflicts, stale generation, repeated restoration, journal retention/cleanup |
| Repetition | Pass in fake backend | 100 Apply/Restore cycles, baseline and journal checked each cycle; final all-fixture run 0.57 seconds; not a 100-cycle native leak test |
| Native full-pack recovery | Pass on host | Current serialized session passed Anya's 53-slot normal restoration and owned-worker SIGKILL recovery. Earlier Minecraft/Goku checks passed 56 slots; no broader OS/hardware claim |
| Helper packaging | Pass | Background-only policy, zero windows, invalid arguments, registry read, watchdog ready/EOF exit |
| Background/reopen/window close | Pass for app command | Same process becomes `UIElement`; pack retained on reopen; closing main window left the process and 53-slot journal alive; direct Dock/status-menu actions await human verification |
| Animation power behavior | Fixed and passed | Previously a repeating timer woke while inactive; now stops for inactive/hidden/occluded windows, Restore and detach, resumes when eligible, and observes accessibility display changes on the main run loop |
| Apply busy feedback | Pass | Real app displayed Anya Busy artwork, progress, Applying label, disabled Apply and Cancel and Restore; keyboard Restore cancelled Apply and returned to paused system-pointer status; final Anya application reported 12 roles / 53 slots |
| Fullscreen | Partial pass | Native fullscreen entry and View → Exit Full Screen worked; gallery, action bar, selection, and Anya applied status survived. Human cursor appearance across Spaces/other fullscreen apps remains untested |
| UI sizes/appearance | Partial pass | 12 offscreen fixtures generated at 1080×760 and 900×640, light/dark, built-in/imported/deleted states; representative captures inspected. Native sample artwork unavailable in offscreen runner but visibly present in the actual app |
| Keyboard/accessibility | Partial pass | Tab focused labeled search; typing filtered sets; Settings opened/closed with consistent applied status; AX exposes role picker, selected cursors, Apply/Restore and named controls. Full traversal with Keyboard Navigation enabled and actual VoiceOver speech/order remain untested |
| Physical lock/sleep | Awaiting user result | User agreed to lock/unlock and sleep/wake; no pass inferred from agreement |
| Physical logout/restart | Untested | Synthetic system-Quit reason tests pass; do not establish actual OS shutdown behavior |
| Displays/contexts | Unavailable or untested | Multiple/mixed-scale displays, unplug/replug, Mission Control, Stage Manager, protected surfaces, and exhaustive external roles |
| Hotspots | Partial | Automated scaled geometry/click hit-testing passes; actual visible-tip precision Small/Large awaits user observation |

### Loading-cursor follow-up

The user reported that the manual results were better overall, with an unexpected cursor during loading when Busy is absent. This is not an itemized pass for each lifecycle/hotspot case. Investigation found no random-role selection: unassigned roles retain their captured baseline. All five currently imported sets contain Busy artwork; built-in presets customize only the arrow. The affected set and whether the unexpected artwork is the macOS beachball or another theme remain to be identified.

A new fake-backend regression passed: apply a full pack, prepare the next transaction, then apply arrow plus Working without Busy. Busy returns to the original baseline, and final Restore recovers every baseline. Explicitly unassigning Busy also excludes that slot. These checks establish transition behavior; they do not reproduce an OS-controlled visible loading condition. Production fallback behavior has not been changed without a confirmed cause.

The user subsequently identified **Anya** and described resize, text, loading, and baseline macOS shapes appearing before application completed. Anya includes an explicit Busy entry, so the missing-role hypothesis does not explain that case. Inspection found that every native registration used `setGlobally = true, instantly = true`. The [primary ABI declaration](https://raw.githubusercontent.com/alexzielenski/Mousecape/master/Mousecape/mousecloak/CGSInternal/CGSCursor.h) distinguishes these flags. Forcing every registered role onto the live pointer during both baseline restoration and pack application is a credible mechanism for the reported cycling.

Registration now keeps global application enabled and sets `instantly = false`. The same boundary is used by Apply, Restore, resume, rollback, and watchdog recovery; it no longer explicitly displays every intermediate role. macOS remains responsible for selecting the appropriate semantic cursor. A test callback at the actual native-write boundary verifies both flags, image/frame/geometry metadata, and error propagation without real cursor writes.

The Anya fixture and complete safe suite passed. A new live Anya check passed **53-slot Apply/Restore and SIGKILL watchdog recovery**, including baseline pixels, sizes, hotspots, and journal cleanup. The signed repaired build at `.build/quiet-registration/Octapuss.app` was opened and Anya reapplied at Medium; the UI reported **12 roles across 53 slots**. The user confirmed that the unrelated-shape cycling stopped. This change fixes forced intermediate displays; it does not claim universal replacement of app-drawn/protected cursors or every OS loading condition.

The user then asked why Busy no longer appears while changing a pack. Anya's original Wait entry is one static frame; its Working entry has 15 frames at 100 ms. Pack application no longer forces the Busy role just to display its artwork. The clarification below establishes the request as explicit Apply feedback, rather than a demonstrated missing Busy mapping during OS waiting.

### Explicit Apply progress

The user clarified that Busy should appear while changing/applying a pack. The app now displays explicit app-local progress and loading artwork, using a captured selection, while snapshot preparation and serialized native registration run off the UI thread. Busy is preferred, then Working, with native progress as the final fallback. Cancel requests restoration after the in-flight native step; full Quit defers until cleanup. An interrupted Apply cannot reactivate after lock/return. See [Apply feedback and cancellation](APPLY_PROGRESS.md).

The safe suite passed with Anya and Son Goku, including injected registration barriers that prove main-actor responsiveness, duplicate prevention, success/error cleanup, cancellation, Quit waiting, and lock interruption with no late activation. Native Anya Apply/Restore verified all 53 baseline slots again. The old live check's five-second worker/recovery deadlines expired under load; worker readiness was observed at 10.49 seconds. Both test waits are now bounded at 20 seconds with phase-specific diagnostics. The complete passing run measured worker readiness at **6.09 s** and verified SIGKILL recovery/journal removal at **6.03 s**. Production watchdog startup/recovery logic was not weakened or bypassed.

Immediate native screenshots captured **Applying Anya…**, the static Busy artwork, an indeterminate indicator, disabled editing/Apply, and **Cancel and restore**. A real ⌘⇧R during Apply ended at **Cursor change cancelled. System pointer restored.** with preview paused. Anya was then reapplied at the user's Small size, ending with **12 roles across 53 system slots**. Actual menu-bar Quit during an in-flight Apply and physical sleep during Apply remain untested; fake state checks do not replace those observations.

### Playground cursor boundary

The user reported that the selected preview artwork remained over Octapuss's sidebar and buttons after leaving the playground. A native regression fixture reproduced a visible region larger than the view's bounds: `visibleRect` extended to 600 points wide for a 300-point-wide playground. Both cursor rectangles and direct cursor updates previously used that region without intersecting the actual bounds. The tracking area also used `.inVisibleRect`, and no exit handler released directly selected preview artwork.

Cursor registration, tracking and direct updates now use the intersection of the visible region and playground bounds. Exit, hide and detach release only the preview's current artwork while the pointer remains inside the same active window; another control's text cursor or an external app's cursor is preserved. Animation updates use the same bounded ownership check.

Native regression checks passed for leaving the playground, delayed updates outside it, preserving a text cursor, hiding/removing the view, inactive windows and outside-window ownership. The existing animation lifecycle and full safe suite also passed with the Anya and Son Goku fixtures. These controlled native tests do not establish a physical pointer traversal through the live window; that visual check remains untested by automation.

The repaired local build passed helper packaging and strict signature verification. The previous app's system pointer was restored before stopping its process. The UI automation launch timed out repeatedly, so reopening the repaired app and reapplying Anya could not be confirmed in this run.

## Resource measurements

Method: `scripts/measure-resources.py` samples only an explicitly selected Octapuss PID using cumulative process CPU time and RSS. Ten-second intervals, 11 samples each; percent is relative to one CPU core. CPU time has centisecond resolution (about 0.1 percentage point over these intervals), so displayed zero means no measurable CPU-time delta, not proof of absolutely no work. Helpers are not included in these parent-process samples. No pointer coordinates, input, screenshots, or unrelated process activity are recorded.

| State | Elapsed | CPU | RSS start → end | Peak RSS |
| --- | --- | --- | --- | --- |
| Anya applied, window open, idle | 10.205 s | 0.000% | 27.281 → 27.250 MiB | 27.281 MiB |
| Anya applied, menu-bar-only, idle | 10.218 s | 0.000% | 49.531 → 49.531 MiB | 49.531 MiB |

RSS can change with framework/image caches and memory compression; these short stable intervals do not prove absence of leaks. The first state does not prove continuous animation throughput: tools can deactivate the key window. Paused, continuous pointer movement, active animation, display transitions, and a prolonged native-session soak remain pending. An initial sample targeted an exited PID and was discarded rather than reported as zero usage.

Raw current-run measurements live under ignored `.build/stability-evidence/`; visual fixtures are at `/tmp/octapuss-stability-renders/`. They are local evidence, not shipped artwork.

## Reproduce

```sh
rtk proxy env OCTAPUSS_GOKU_FIXTURE_PATH="$PWD/cursor-example/son-goku" zsh scripts/build-phase0.sh --check
rtk proxy env OCTAPUSS_BUILD_DIR="$PWD/.build/stability" zsh scripts/build-phase0.sh
rtk proxy python3 OctapussTests/CursorHelperChecks.py .build/stability/Octapuss.app
rtk proxy codesign --verify --deep --strict .build/stability/Octapuss.app
rtk proxy python3 scripts/measure-resources.py --pid <OCTAPUSS_PID> --seconds 10 --label background-idle --output .build/stability-evidence/background.json
```

Native recovery check, only with the app's current pack restored and no competing cursor utility: set `OCTAPUSS_LIVE_PACK_FOLDER` to a fixture and run `rtk proxy zsh scripts/build-phase0.sh --check-system-live`. It temporarily changes registrations and kills only its own worker. Reapply the user's prior pack afterward. The hosted workflow deliberately runs no system-mutating recovery check.

## Local candidate

`rtk proxy zsh scripts/package-local-candidate.sh "$PWD/.build/preview-boundary/Octapuss.app"` produces `.build/local-candidate/Octapuss-0.1.0-local-arm64.zip` with a SHA-256 file, source revision, validation report, and recovery instructions alongside it. Imported artwork is not bundled. The package is experimental, locally signed, and not notarized; its existence does not close the acceptance gates below.

## Remaining acceptance gates

Obtain physical lifecycle, Dock/status-menu Quit, and hotspot results; finish keyboard/VoiceOver and workspace checks; measure remaining performance states; test additional hardware/OS or narrow support; validate with full Xcode. External distribution additionally needs Developer ID/hardened runtime/notarization/Gatekeeper evidence. The local candidate stays experimental until these pass or the supported scope explicitly excludes unavailable cases.

## Recovery

Choose **Restore system pointer** to restore Octapuss-owned registrations and cancel resumption. Choose menu-bar **Quit Octapuss** to restore and exit; Dock Quit keeps running. A failed restoration leaves the app open with the error. After an unexpected exit, the bundled watchdog attempts the owned baseline, and relaunch checks unresolved recovery before a new Apply. Do not delete the journal at `~/Library/Application Support/Octapuss/system-arrow-session.json` to silence an error: it contains the recovery baseline. Stop other cursor utilities before retrying and preserve any archived backup.
