# Stability verification

Run date: 16 October 2026. This is an experimental local candidate, not a declaration of beta or external-release readiness. Current scope is native cursor-pack customization plus an independent AppKit playground. The original feasibility report is historical.

## Environment and build

- Host: Mac14,7, macOS 26.5.1, arm64; one built-in Retina display discovered. Other displays, Intel, and older macOS versions are unavailable here.
- Command Line Tools builder uses the installed macOS 15.4 SDK workaround. Deployment target 14.0 is not a compatibility certification.
- Xcode project and both bundle property lists pass `plutil -lint`. Local `xcodebuild` cannot run because full Xcode is absent. No XCTest target exists.
- A read-only hosted macOS workflow was added to validate Release with Xcode and run synthetic checks. [Run 38864881747](https://github.com/izulsyauki/octapuss/actions/runs/38864881747) did not start any build steps: GitHub's check annotation says, "The job was not started because your account is locked due to a billing issue." No hosted compilation result is claimed. The repository owner must resolve that account restriction before rerunning; no billing settings were changed.
- Current locally ad-hoc signed candidate: `.build/candidate/Octapuss.app`, built from source commit `2c19ed0`. Deep/strict signature and packaged-helper verification passed. `.build/stability/Octapuss.app` was used for the interactive/resource checks of the same timer fix before the final observer-ownership refinement.
- No Developer ID Application identity is available in the local signing query. Developer ID signing, hardened-runtime validation, notarization, stapling, and clean-machine Gatekeeper verification remain unavailable/pending. No credentials were requested or security settings changed.

## Checks

| Area | Result | Evidence / limitation |
| --- | --- | --- |
| Preferences/import/roles/deletion | Pass | Executable regression suite with Anya, Minecraft, and Son Goku fixtures; original downloads preserved |
| Transactions and ownership | Pass | Rollback, conflicts, stale generation, repeated restoration, journal retention/cleanup |
| Repetition | Pass in fake backend | 100 Apply/Restore cycles, baseline and journal checked each cycle; final all-fixture run 0.57 seconds; not a 100-cycle native leak test |
| Native full-pack recovery | Pass, existing matching engine evidence | 56-slot normal restoration and owned-worker SIGKILL recovery previously passed. A Git comparison verified backend, role planner and decoder unchanged since tested commit `b8fb857`; no competing live test was run during the user's physical lifecycle check |
| Helper packaging | Pass | Background-only policy, zero windows, invalid arguments, registry read, watchdog ready/EOF exit |
| Background/reopen/window close | Pass for app command | Same process becomes `UIElement`; pack retained on reopen; closing main window left the process and 53-slot journal alive; direct Dock/status-menu actions await human verification |
| Animation power behavior | Fixed and passed | Previously a repeating timer woke while inactive; now stops for inactive/hidden/occluded windows, Restore and detach, resumes when eligible, and observes accessibility display changes on the main run loop |
| Fullscreen | Partial pass | Native fullscreen entry and View → Exit Full Screen worked; gallery, action bar, selection, and Anya applied status survived. Human cursor appearance across Spaces/other fullscreen apps remains untested |
| UI sizes/appearance | Partial pass | 12 offscreen fixtures generated at 1080×760 and 900×640, light/dark, built-in/imported/deleted states; representative captures inspected. Native sample artwork unavailable in offscreen runner but visibly present in the actual app |
| Keyboard/accessibility | Partial pass | Tab focused labeled search; typing filtered sets; Settings opened/closed with consistent applied status; AX exposes role picker, selected cursors, Apply/Restore and named controls. Full traversal with Keyboard Navigation enabled and actual VoiceOver speech/order remain untested |
| Physical lock/sleep | Awaiting user result | User agreed to lock/unlock and sleep/wake; no pass inferred from agreement |
| Physical logout/restart | Untested | Synthetic system-Quit reason tests pass; do not establish actual OS shutdown behavior |
| Displays/contexts | Unavailable or untested | Multiple/mixed-scale displays, unplug/replug, Mission Control, Stage Manager, protected surfaces, and exhaustive external roles |
| Hotspots | Partial | Automated scaled geometry/click hit-testing passes; actual visible-tip precision Small/Large awaits user observation |

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

`rtk proxy zsh scripts/package-local-candidate.sh "$PWD/.build/candidate/Octapuss.app"` produces `.build/local-candidate/Octapuss-0.1.0-local-arm64.zip` with a SHA-256 file, source revision, validation report, and recovery instructions alongside it. Imported artwork is not bundled. The package is experimental, locally signed, and not notarized; its existence does not close the acceptance gates below.

## Remaining acceptance gates

Obtain physical lifecycle, Dock/status-menu Quit, and hotspot results; finish keyboard/VoiceOver and workspace checks; measure remaining performance states; test additional hardware/OS or narrow support; validate with full Xcode. External distribution additionally needs Developer ID/hardened runtime/notarization/Gatekeeper evidence. The local candidate stays experimental until these pass or the supported scope explicitly excludes unavailable cases.

## Recovery

Choose **Restore system pointer** to restore Octapuss-owned registrations and cancel resumption. Choose menu-bar **Quit Octapuss** to restore and exit; Dock Quit keeps running. A failed restoration leaves the app open with the error. After an unexpected exit, the bundled watchdog attempts the owned baseline, and relaunch checks unresolved recovery before a new Apply. Do not delete the journal at `~/Library/Application Support/Octapuss/system-arrow-session.json` to silence an error: it contains the recovery baseline. Stop other cursor utilities before retrying and preserve any archived backup.
