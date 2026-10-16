# Repository Guidelines

## Project Structure & Module Organization

Octapuss has an independent app-local preview and an experimental native cursor-pack backend. Production source is in `Octapuss/`, with an app target in `Octapuss.xcodeproj`. Read `docs/ARCHITECTURE.md` for ownership and dependency rules, `docs/UI_REDESIGN.md` for the library/gallery design, `docs/SYSTEM_CURSOR.md` for backend safety, `docs/CURSOR_IMPORT.md` for imports, and `docs/FULL_PACKS.md` for role mapping, animation, and measured limits.

Use `Octapuss/App` for process lifecycle, `Application` for workflows and interfaces, `Features` for SwiftUI, `Models` for Foundation-only data, `Platform` for AppKit and native integration, `Persistence` for storage, and `Resources` for metadata. Keep the app-local preview independent from the across-app cursor backend. AppStore coordinates the UI; CursorLibraryController and CursorSessionController own their state. Preserve existing Codable fields, preference keys, journal ownership and queue isolation during refactors.

## Build, Test, and Development Commands

The shared Octapuss scheme is available. With full Xcode selected:

```sh
xcodebuild -project Octapuss.xcodeproj -scheme Octapuss build
```

With Command Line Tools, run `rtk proxy zsh scripts/build-phase0.sh`; add `--check` for safe/fake regression checks, `--render-library` for offscreen app-only visual fixtures (see `docs/UI_REDESIGN.md`), or `--probe-system` for read-only private API probing. `--check-system-live` intentionally changes system arrow registrations temporarily and kills only its own worker to test recovery; run it only for an authorized integration check. No XCTest target exists. Do not claim Xcode/XCTest validation from the Command Line Tools path. Global pointer hiding and overlays remain excluded.

Run `rtk proxy python3 scripts/check-architecture.py` after source changes. Add new Swift files to the Xcode target; this gate rejects source membership drift and basic boundary violations. The local builder discovers production sources recursively and retains its historical filename for compatibility.

## Coding Style & Naming Conventions

Use Swift and SwiftUI for application UI, AppKit at native cursor boundaries, and CoreGraphics only where the selected backend requires it. Follow standard Swift formatting with four-space indentation. Name types in `UpperCamelCase`, members in `lowerCamelCase`, and protocols by responsibility (`CursorBackend`, `PermissionService`). Prefer small protocols, typed errors, explicit runtime states, and system frameworks over new dependencies. Availability-check APIs newer than the deployment target.

## Testing Guidelines

Add XCTest coverage for geometry, manifest validation, preferences, state transitions, cancellation, and recovery ownership. Name tests by behavior, for example `testCancelledStartCannotReactivateSession()`. Use fake backends for lifecycle tests, but verify rendering, permissions, display changes, Force Quit recovery, accessibility, and performance on macOS using `docs/TEST_PLAN.md`. Mark unavailable hardware or OS cases as **untested**, never passed.

## Commit & Pull Request Guidelines

Use short, imperative commit subjects, optionally scoped (for example, `Cursor: reject invalid hotspots`). Keep commits reviewable and limited to one milestone concern. Pull requests should explain scope, link the relevant plan or issue, list test evidence and untested cases, include UI captures for visual changes, and call out compatibility or recovery risks.

## Security & Recovery

Request only permissions required by the proven backend. Never collect pointer history, typed content, screenshots, or app activity. Treat reliable restoration of Octapuss-owned effects as a release requirement.
