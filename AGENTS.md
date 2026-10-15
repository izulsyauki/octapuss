# Repository Guidelines

## Project Structure & Module Organization

Octapuss has an independent app-local preview and an experimental native system-arrow backend requested on 15 October 2026. Source is `Phase0/OctapussProof.swift` and `Phase0/SystemCursorBackend.swift`, with an app target in `Octapuss.xcodeproj`. Read `docs/SYSTEM_CURSOR.md` for the current scope, safety boundaries, and measured limits; `docs/REPAIR_VERIFICATION.md` records the earlier local repair.

When implementation begins, follow the proposed layout: `Octapuss/App`, `Features`, `Cursor`, `Platform`, `Models`, `Persistence`, and `Resources`, with focused tests in `OctapussTests`. Keep the app-local preview independent from any across-app cursor backend.

## Build, Test, and Development Commands

The shared Octapuss scheme is available. With full Xcode selected:

```sh
xcodebuild -project Octapuss.xcodeproj -scheme Octapuss build
```

With Command Line Tools, run `rtk proxy zsh scripts/build-phase0.sh`; add `--check` for safe/fake regression checks or `--probe-system` for read-only private API probing. `--check-system-live` intentionally changes system arrow registrations temporarily and kills only its own worker to test recovery; run it only for an authorized integration check. No XCTest target exists. Do not claim Xcode/XCTest validation from the Command Line Tools path. Global pointer hiding and overlays remain excluded.

## Coding Style & Naming Conventions

Use Swift and SwiftUI for application UI, AppKit at native cursor boundaries, and CoreGraphics only where the selected backend requires it. Follow standard Swift formatting with four-space indentation. Name types in `UpperCamelCase`, members in `lowerCamelCase`, and protocols by responsibility (`CursorBackend`, `PermissionService`). Prefer small protocols, typed errors, explicit runtime states, and system frameworks over new dependencies. Availability-check APIs newer than the deployment target.

## Testing Guidelines

Add XCTest coverage for geometry, manifest validation, preferences, state transitions, cancellation, and recovery ownership. Name tests by behavior, for example `testCancelledStartCannotReactivateSession()`. Use fake backends for lifecycle tests, but verify rendering, permissions, display changes, Force Quit recovery, accessibility, and performance on macOS using `docs/TEST_PLAN.md`. Mark unavailable hardware or OS cases as **untested**, never passed.

## Commit & Pull Request Guidelines

Use short, imperative commit subjects, optionally scoped (for example, `Cursor: reject invalid hotspots`). Keep commits reviewable and limited to one milestone concern. Pull requests should explain scope, link the relevant plan or issue, list test evidence and untested cases, include UI captures for visual changes, and call out compatibility or recovery risks.

## Security & Recovery

Request only permissions required by the proven backend. Never collect pointer history, typed content, screenshots, or app activity. Treat reliable restoration of Octapuss-owned effects as a release requirement.
