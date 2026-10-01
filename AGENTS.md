# Repository Guidelines

## Project Structure & Module Organization

Octapuss is currently a planning-only macOS project; no application target exists yet. Start with `README.md`, then use `PRODUCT.md` and `DESIGN.md` for product and interface decisions. Technical plans live in `docs/`: `ARCHITECTURE.md` defines boundaries, `FEASIBILITY.md` records platform constraints, `IMPLEMENTATION_PLAN.md` orders the work, and `TEST_PLAN.md` defines verification.

When implementation begins, follow the proposed layout: `Octapuss/App`, `Features`, `Cursor`, `Platform`, `Models`, `Persistence`, and `Resources`, with focused tests in `OctapussTests`. Keep the app-local preview independent from any across-app cursor backend.

## Build, Test, and Development Commands

There is no Xcode project or runnable command yet. Do not report builds or tests as passing until `Octapuss.xcodeproj` exists. After project creation, document reproducible commands here, expected to resemble:

```sh
xcodebuild -project Octapuss.xcodeproj -scheme Octapuss build
xcodebuild -project Octapuss.xcodeproj -scheme Octapuss test
```

Phase 0 is the next milestone: prove the cursor approach and record evidence in `FEASIBILITY_RESULTS.md` before building the full shell.

## Coding Style & Naming Conventions

Use Swift and SwiftUI for application UI, AppKit at native cursor boundaries, and CoreGraphics only where the selected backend requires it. Follow standard Swift formatting with four-space indentation. Name types in `UpperCamelCase`, members in `lowerCamelCase`, and protocols by responsibility (`CursorBackend`, `PermissionService`). Prefer small protocols, typed errors, explicit runtime states, and system frameworks over new dependencies. Availability-check APIs newer than the deployment target.

## Testing Guidelines

Add XCTest coverage for geometry, manifest validation, preferences, state transitions, cancellation, and recovery ownership. Name tests by behavior, for example `testCancelledStartCannotReactivateSession()`. Use fake backends for lifecycle tests, but verify rendering, permissions, display changes, Force Quit recovery, accessibility, and performance on macOS using `docs/TEST_PLAN.md`. Mark unavailable hardware or OS cases as **untested**, never passed.

## Commit & Pull Request Guidelines

No Git history is available in this checkout. Use short, imperative commit subjects, optionally scoped (for example, `Cursor: reject invalid hotspots`). Keep commits reviewable and limited to one milestone concern. Pull requests should explain scope, link the relevant plan or issue, list test evidence and untested cases, include UI captures for visual changes, and call out permission, compatibility, or recovery risks.

## Security & Recovery

Request only permissions required by the proven backend. Never collect pointer history, typed content, screenshots, or app activity. Treat reliable restoration of Octapuss-owned effects as a release requirement.
