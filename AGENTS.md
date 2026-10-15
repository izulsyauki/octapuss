# Repository Guidelines

## Project Structure & Module Organization

Octapuss is an app-local macOS pointer customization app. Current source is `Phase0/OctapussProof.swift`, with a minimal app target in `Octapuss.xcodeproj` and focused native checks in `OctapussTests/RegressionChecks.swift`. Start with `README.md`, `PRODUCT.md`, and `DESIGN.md`; current verification is in `docs/REPAIR_VERIFICATION.md`.

When implementation begins, follow the proposed layout: `Octapuss/App`, `Features`, `Cursor`, `Platform`, `Models`, `Persistence`, and `Resources`, with focused tests in `OctapussTests`. Keep the app-local preview independent from any across-app cursor backend.

## Build, Test, and Development Commands

The shared Octapuss scheme is available. With full Xcode selected:

```sh
xcodebuild -project Octapuss.xcodeproj -scheme Octapuss build
```

With Command Line Tools, run `rtk proxy zsh scripts/build-phase0.sh`; add `--check` for executable native regression checks. No XCTest target exists yet. Do not claim Xcode/XCTest validation from the Command Line Tools path. The historical Phase 0 evidence is in `docs/FEASIBILITY_RESULTS.md`; the chosen product scope is app-local and global cursor experiments are excluded.

## Coding Style & Naming Conventions

Use Swift and SwiftUI for application UI, AppKit at native cursor boundaries, and CoreGraphics only where the selected backend requires it. Follow standard Swift formatting with four-space indentation. Name types in `UpperCamelCase`, members in `lowerCamelCase`, and protocols by responsibility (`CursorBackend`, `PermissionService`). Prefer small protocols, typed errors, explicit runtime states, and system frameworks over new dependencies. Availability-check APIs newer than the deployment target.

## Testing Guidelines

Add XCTest coverage for geometry, manifest validation, preferences, state transitions, cancellation, and recovery ownership. Name tests by behavior, for example `testCancelledStartCannotReactivateSession()`. Use fake backends for lifecycle tests, but verify rendering, permissions, display changes, Force Quit recovery, accessibility, and performance on macOS using `docs/TEST_PLAN.md`. Mark unavailable hardware or OS cases as **untested**, never passed.

## Commit & Pull Request Guidelines

Use short, imperative commit subjects, optionally scoped (for example, `Cursor: reject invalid hotspots`). Keep commits reviewable and limited to one milestone concern. Pull requests should explain scope, link the relevant plan or issue, list test evidence and untested cases, include UI captures for visual changes, and call out compatibility or recovery risks.

## Security & Recovery

Request only permissions required by the proven backend. Never collect pointer history, typed content, screenshots, or app activity. Treat reliable restoration of Octapuss-owned effects as a release requirement.
