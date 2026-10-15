# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Users

Mac owners who enjoy desktop personalization and want a friendly, low-friction way to choose and try a distinctive pointer inside Octapuss. The primary workflow is occasional customization rather than continuous administration.

## Product Purpose

Octapuss makes app-local pointer customization playful, precise, and easy to reverse. Success means a user can choose a style, verify its real hotspot on ordinary controls, and return to the system pointer without granting unrelated permissions.

## Positioning

Octapuss combines a real AppKit cursor preview with an original cat-and-octopus character system. It treats cursor accuracy and restoration as part of the experience rather than hiding those details behind decorative mockups.

## Operating Context

- A native macOS utility with a main customization window, Settings, and menu-bar access.
- The first supported scope is **app-local customization inside Octapuss**.
- The preview includes light and dark test surfaces, text, and a normal button for visual and click-position checks.
- The app launches with across-app effects off and keeps Restore available.

## Capabilities and Constraints

- Three static pointer presets: Ink, Tide, and Blush.
- Small, Medium, and Large sizes with a hotspot that scales with the artwork.
- App-local cursor rectangles use public AppKit APIs.
- Across-app companion and cursor-hiding experiments have been removed from the app-local executable. Their historical findings remain in the feasibility report.
- System-wide cursor replacement is not established and must never be claimed.
- Store only selected appearance preferences. Do not collect pointer history, typing, screenshots, clicked content, or application activity.
- Use SwiftUI for the interface and AppKit at native cursor boundaries. The current proof builds with Command Line Tools; a full Xcode project remains future work.
- Animated pointers, trails, sound, import/export, editing, per-app rules, accounts, cloud sync, and automatic global cursor-role detection are deferred.

## Brand Commitments

- Product name: **Octapuss**.
- Identity: a cat and octopus hybrid expressed through ears, rounded forms, and small tentacle details.
- Emotional range: cute, engaging, joyful, reassuring, and never childish or distracting.
- Voice: warm and concise. Controls still name their actual action and scope.
- Familiar macOS controls and system typography remain part of the product identity.

## Evidence on Hand

- Runnable Phase 0 source: `Phase0/OctapussProof.swift`.
- Reproducible builder: `scripts/build-phase0.sh`.
- Platform findings and measured limits: `docs/FEASIBILITY_RESULTS.md`.
- Product architecture, implementation order, and test coverage are recorded in `docs/`.
- No final mascot illustration, production cursor asset set, customer evidence, or compatibility matrix exists yet; future work must not fabricate them.

## Product Principles

1. **Truth before magic.** Name app-local preview and experimental behavior exactly as implemented.
2. **The tip stays trustworthy.** Decoration grows away from the click point, and every size preserves hotspot alignment.
3. **Joy supports the task.** Character appears in selection, preview, first use, and recovery without replacing standard controls.
4. **Restoration is a feature.** Restore and Quit must unwind every effect owned by Octapuss.
5. **Private by default.** Personalization stays local and requires no activity collection.

## Accessibility & Inclusion

Support keyboard navigation, VoiceOver labels, visible focus, increased contrast, reduced motion, and status text that does not depend on color. Keep pointer silhouettes recognizable across supported sizes and light/dark preview surfaces.

## Open Decisions

- Minimum supported macOS version and Intel support after a matching full Xcode toolchain is available.
- Distribution route after an Xcode project, signing configuration, and complete manual verification exist.
