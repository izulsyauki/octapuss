# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Users

Mac owners who enjoy desktop personalization and want a friendly, low-friction way to choose and try a distinctive pointer inside Octapuss. The primary workflow is occasional customization rather than continuous administration.

## Product Purpose

Octapuss makes pointer customization playful, precise, and easy to reverse. On 15 October 2026 the user changed the requested scope to native system customization. The first system backend targets registered macOS arrow cursors while keeping the independent app-local preview.

## Positioning

Octapuss combines a real AppKit cursor preview with an original cat-and-octopus character system. It treats cursor accuracy and restoration as part of the experience rather than hiding those details behind decorative mockups.

## Operating Context

- A native macOS utility with a searchable cursor-set library, gallery of every imported cursor in the selected set, live playground, Settings, and menu-bar access.
- The requested scope is **system arrow customization outside Octapuss**, with an explicit Apply action. The local playground remains independent.
- The preview includes light and dark test surfaces, text, and a normal button for visual and click-position checks.
- The app launches with across-app effects off and keeps Restore available.

## Capabilities and Constraints

- Three static pointer presets: Ink, Tide, and Blush.
- Local import of Windows `.cur` files and `.ani` first-sequence-frame artwork, with persistent cursor sets, preserved hotspots/aspect ratio, preview, and explicit system-arrow application. Multi-file and unzipped-folder imports form sets; every member appears in the gallery. ZIP sets must be unzipped first. Imported roles are not automatically mapped to macOS roles.
- Small, Medium, and Large sizes with a hotspot that scales with the artwork.
- App-local cursor rectangles use public AppKit APIs.
- Across-app companion and cursor-hiding experiments have been removed from the app-local executable. Their historical findings remain in the feasibility report.
- The experimental native backend uses dynamically resolved private cursor-registration APIs. It targets Arrow and, on macOS 26, ArrowS. Text, link-hand, resize, application-drawn, and protected cursors are outside this first theme's replacement scope.
- Baseline backup, verified restoration, partial-failure rollback, and crash recovery are release requirements. Availability and registration success must be distinguished from human-visible cross-app verification.
- Store selected appearance preferences and local normalized copies of explicitly imported cursor artwork. Do not collect pointer history, typing, screenshots, clicked content, or application activity.
- Use SwiftUI for the interface and AppKit at native cursor boundaries. The current proof builds with Command Line Tools; a full Xcode project remains future work.
- Animated playback, trails, sound, export, editing, per-app rules, accounts, cloud sync, and automatic global cursor-role detection are deferred.

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

1. **Truth before magic.** Distinguish local preview, applied system-arrow registrations, and verified visible behavior. Do not promise every cursor in every application.
2. **The tip stays trustworthy.** Decoration grows away from the click point, and every size preserves hotspot alignment.
3. **Joy supports the task.** Character appears in selection, preview, first use, and recovery without replacing standard controls.
4. **Restoration is a feature.** Restore and Quit must unwind every effect owned by Octapuss.
5. **Private by default.** Personalization stays local and requires no activity collection.

## Accessibility & Inclusion

Support keyboard navigation, VoiceOver labels, visible focus, increased contrast, reduced motion, and status text that does not depend on color. Keep pointer silhouettes recognizable across supported sizes and light/dark preview surfaces.

## Open Decisions

- Minimum supported macOS version and Intel support after a matching full Xcode toolchain is available.
- Distribution route after an Xcode project, signing configuration, and complete manual verification exist.
