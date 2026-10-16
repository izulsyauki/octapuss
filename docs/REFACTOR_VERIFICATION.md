# Maintainability refactor verification

16 October 2026. This work reorganizes the existing native app; it does not add product features, change storage formats, expand cursor support or establish release readiness.

## Changes

- Replaced the five mixed-responsibility `Phase0` source files with focused files under `Octapuss/`.
- Replaced the 480-line ProofStore with a 123-line AppStore coordinator, a 200-line library controller and a 224-line cursor controller. Controllers remain main-actor isolated and AppStore forwards their changes to SwiftUI.
- Added CursorLibraryStorage for injected storage, retained SystemCursorAccess for fake native access, captured immutable Apply requests, and centralized typed preferences and application-support paths.
- Kept Foundation-only Codable models separate from AppKit conversion, rendering, native slots and pixel comparison. Existing IDs, optional legacy fields, preference keys, paths and journal schema remain compatible.
- Removed unused preview/badge wrappers, clarified Apply and JSON storage names, consolidated compiler setup, and synchronized the Xcode source tree and metadata. The historical builder/executable names remain compatible with existing tooling.
- Added a CI architecture gate for model isolation, basic UI/infrastructure boundaries, duplicate/missing Xcode sources and executable metadata.

## Evidence

| Check | Result and scope |
| --- | --- |
| Baseline safe suite before edits | Passed with Anya and Son Goku fixtures |
| Safe suite after initial file extraction | Passed |
| Safe suite after controller extraction and final preview guard | Passed, including 100 isolated Apply/Restore cycles, import/role/deletion/Undo, ownership, continuation, cancellation and menu-bar lifecycle logic |
| New storage/observation checks | Passed: failed save leaves artwork/roles intact, failed Undo retains recovery, failed load cannot overwrite saved data, selection retains preference compatibility, controller edits notify AppStore observers |
| New captured-request check | Passed: changing selection/size while registration is blocked does not change loading artwork, applied label or captured snapshot size |
| Foundation-only model typecheck | Passed independently of application, UI, persistence and platform source |
| Architecture gate | Passed; temporary fixture violations confirmed rejection of missing/duplicate sources, UI backend access, model UI imports and mismatched executable metadata |
| Local native app build | Passed with Command Line Tools, arm64 and macOS 14 deployment target |
| Helper packaging and startup | Passed: background-only policy, no windows, invalid arguments, registry read, readiness and clean exit |
| Plist and signature verification | Passed, including deep/strict local app signature |
| Offscreen rendering | All 12 built-in/imported/deleted, light/dark, default/minimum fixtures completed; imported light/default and deleted dark/minimum captures inspected |
| Native parsing, pack planning and ABI algorithms | Compared directly with their pre-refactor source: unchanged |

The offscreen runner initially exposed a real preview crash: a fully clipped playground produced a null rectangle with an infinite origin, which AppKit rejected when registering cursor rectangles. The view now normalizes an empty/null intersection and registers no cursor/tracking area. A native geometry regression and the complete render run pass after this repair. This is the intentional behavioral correction found during the refactor.

Render artifacts are local at `/tmp/octapuss-refactor-renders/`. The built app is `.build/architecture/Octapuss.app`. Imported user artwork is not bundled or committed.

## Reproduce

```sh
rtk proxy python3 scripts/check-architecture.py
rtk proxy env OCTAPUSS_NATIVE_THEME_PATH="$PWD/cursor-example/Anya.cursor" OCTAPUSS_GOKU_FIXTURE_PATH="$PWD/cursor-example/son-goku" zsh scripts/build-phase0.sh --check
rtk proxy env OCTAPUSS_BUILD_DIR="$PWD/.build/architecture" zsh scripts/build-phase0.sh
rtk proxy python3 OctapussTests/CursorHelperChecks.py .build/architecture/Octapuss.app
rtk proxy codesign --verify --deep --strict .build/architecture/Octapuss.app
rtk proxy env OCTAPUSS_RENDER_DIR=/tmp/octapuss-refactor-renders OCTAPUSS_RENDER_PACK_PATH="$PWD/cursor-example/Anya.cursor" zsh scripts/build-phase0.sh --render-library
```

Downloaded fixture paths are optional for the general safe suite; those additional real-pack cases require the local downloads. No test here imports artwork into the user's actual saved library.

## Limits

Full Xcode is absent; no Xcode build or XCTest pass is claimed. Project syntax and source membership were checked locally, and the hosted workflow is configured; the previously reported GitHub billing restriction is not resolved by this work. Native UI launch could not be confirmed because desktop control timed out. Offscreen captures omit native cursor samples on this host and do not prove physical pointer behavior. Physical sleep/lock, VoiceOver, multi-display, protected surfaces, long-run performance, signing/notarization and other OS versions retain their previous untested gates in [STABILITY_REPORT.md](STABILITY_REPORT.md).

The system-mutating Apply/SIGKILL test was not rerun for this structural change. Existing backend algorithms were preserved and fake transactions plus packaged read-only helper checks passed; earlier native recovery evidence remains separately recorded. See [ARCHITECTURE.md](ARCHITECTURE.md) for ongoing ownership and extension rules.
