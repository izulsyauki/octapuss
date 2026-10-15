<!-- Hallmark implementation self-critique: Philosophy 5 · Hierarchy 5 · Execution 4 · Specificity 5 · Restraint 4 · Variety 4. -->
# Octapuss design direction

Phase 0 implements this direction as a native SwiftUI/AppKit pointer playground with an independent, experimental system-arrow backend. The 15 October 2026 scope extension adds explicit system application while preserving the existing visual identity and tokens. See `docs/SYSTEM_CURSOR.md` for backend boundaries and host evidence.

## Direction

**A pocket pointer playground with a dependable Mac utility underneath.** The pointer remains the focal object, surrounded by warm cream, berry, mint, lavender, and sunshine accents. Familiar macOS controls, clear status, and precise cursor behavior keep the joy trustworthy.

The mascot is an abstract rounded cat head, two ears, and simplified tentacle feet. It welcomes the user once in the window header and may become the app icon. The menu-bar version stays a monochrome system symbol until a production template asset exists. Avoid turning ordinary controls into paws or tentacles.

This is a native workbench layout, rather than a marketing page. It has no hero, site navigation, or footer. Standard window chrome, buttons, menus, and focus affordances remain part of the design.

## Main customization window

Current default: **840 × 560 pt**. Minimum: **760 × 500 pt**, with scrollable main content. Whole-window interaction at the minimum size remains untested.

```text
[mascot] Octapuss               App-local preview
  Dress up your pointer. Keep every click precise.

Pointer pals          Pointer playground        Light / Dark
                      ┌──────────────────────────────────────┐
● Ink                 │  Large pointer portrait              │
○ Tide                │  Bring your pointer in               │
○ Blush               │  Tiny click test          [Boop!]    │
                      └──────────────────────────────────────┘
                      Test background: Light / Dark

                      Size: Small / Medium / Large
                      [Apply system arrow] [Restore system pointer]
```

This is a content schematic, not a screenshot. The preview should dominate the window; the short preset list needs no full application sidebar. At the minimum size, retain a usable preview and allow settings content to scroll. Do not crop actions or depend on a fixed screenshot layout.

One native AppKit preview owns rendering, cursor rectangles, tracking, and the Boop NSButton. It replaces the transparent cursor overlay so input and cursor ownership share the same region. Outside that region, Octapuss's controls retain their normal cursor behavior. A larger art sample supplements testing at actual size.

For an arrow-only pack, sample text and buttons demonstrate clicks and legibility; they do not promise custom global I-beam or hand shapes.

## Pointer artwork

| Preset | Treatment |
| --- | --- |
| Ink | Dark arrow, contrasting light outline, subtle cat-ear detail at the tail |
| Tide | Same silhouette and hotspot, teal body or small tentacle detail |
| Blush | Same silhouette and hotspot, rose accent and restrained tail detail |

Keep one consistent arrow tip across presets. Decoration extends away from the hotspot. Every variant must remain recognizable on white, black, photographs, and patterned backgrounds. Use a contrasting inner/outer edge where needed; app dark mode does not automatically determine pointer colors.

Proposed production assets: an editable vector master and bundled transparent images at appropriate backing scales. Metadata defines logical canvas dimensions and hotspot. Scaling the canvas must scale the hotspot by the same factor. No final mascot or cursor asset has been produced in this planning pass.

## Appearance tokens

Use a single semantic token source during implementation. Hex values below specify the proposed sRGB colors for native assets; web-specific CSS conventions are not an implementation requirement.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| background | `#FEF5E7` | `#1A1627` | Main canvas |
| surface | `#FFFDF8` | `#251F34` | Status and grouped settings |
| preview | `#FFF8E9` | `#1A1627` | Pointer playground |
| textPrimary | `#2D2440` | `#FAF7FF` | Main labels |
| textSecondary | native semantic | native semantic | Help and metadata |
| lavender | `#8C6BD8` | `#9D7BE8` | Focus, tint, active control |
| tide | `#3F9B91` | `#66C3B6` | Ready status and Tide preset |
| blush | `#DF6C92` | `#EC86A8` | Blush preset and warm detail |
| sunshine | `#F4B860` | `#F4B860` | Mascot halo and preview depth |

Errors, warnings, selection behavior, disabled content, and focus should use appropriate native semantic treatment. Do not infer error/success from the brand colors. Validate contrast in rendered controls, including selected, hover, and disabled states.

Typography uses the macOS system font through native APIs. The 24 pt bold rounded title carries character; 15–16 pt semibold section and preview labels, 13 pt body/control text, and 11–12 pt help keep the workbench familiar. Use native control sizing and adapt to accessibility settings.

Spacing follows a 4 pt scale: 8 pt related controls, 12 pt control groups, 16 pt panel padding, 24 pt major separation. Keep corners and borders consistent with native components rather than drawing ornamental containers around every setting.

## Interaction and states

| Runtime state | Message | Main action |
| --- | --- | --- |
| Preview active | App-local preview active | Restore system pointer |
| Preview paused | System pointer · preview paused | Resume preview |
| System arrow applied | System arrow: actual applied preset · size | Restore system pointer |
| Pointer colors overridden | Pointer color override | Open System Settings; Reset Colors, then Apply |
| Recovery incomplete | System restoration needed | Restore system pointer |

The current app starts with the local preview active and attempts recovery of any saved system session before further application. Preview mode is runtime state, not a saved enable preference. The system backend uses native arrow registrations and a temporary recovery subprocess; no cursor hiding or permission flow is introduced.

Apply system arrow is an explicit primary action. It changes registered macOS arrow slots; text, hand, resize, app-drawn, and protected cursors can differ. Keep local preview behavior independent of that action. Status records the preset and size actually applied, so changing the selection does not relabel the active system arrow. Recovery and pointer-color warnings take precedence over applied status.

Preset and size changes update the preview immediately without resuming a paused preview or applying another system arrow. Style, size, and Light/Dark background persist across relaunch. Boop increments the visible click count and updates diagnostic text; the count resets on relaunch.

Restore restores the saved system baseline, pauses the custom cursor inside the playground, and preserves selected preferences. The system pointer is used there until Resume preview is chosen. Reset preferences is a separate Settings action and preserves preview mode. Quit restores the pointer before exiting; an incomplete restoration retains recovery status and prevents ordinary Quit.

Custom macOS pointer outline/fill colors block Apply before registration. Explain System Settings → Accessibility → Display → Pointer → Reset Colors, then Apply again; Settings offers Open System Settings. Octapuss does not reset those colors itself.

Restore is idempotent and remains reachable from the main window, Settings, app menu, and menu bar.

## Onboarding and menu bar

First launch opens the usable local preview. Explain that system-arrow application is explicit and can affect other apps. No global permission is needed.

The menu bar contains status, Open Octapuss, preset selection, Apply system arrow, Restore system pointer, Resume local preview when paused, Settings, and Quit. Closing the customization window keeps the menu-bar utility running.

Settings (`⌘,`) contains system scope and applied status, Apply/Restore, pointer-color guidance when needed, preview Restore/Resume, privacy, and reset preferences. Launch at login remains deferred. Diagnostics report preview and system actions without collecting browsing or typing activity.

## Accessibility and motion

Support keyboard navigation, VoiceOver names, visible focus, text status, reduced motion, and increased contrast. Status cannot rely on color alone. The preview announces its purpose, not every pointer coordinate. Do not smooth or animate pointer tracking: the visual hotspot must follow the real position immediately.

Version one uses static pointers. Native control feedback may take roughly 150–200 ms; skip trails, wobble, looping mascot animation, and launch choreography.

Implementation review must inspect light/dark appearances at minimum/default window sizes, all runtime states, actual-size pointer edges, and keyboard/VoiceOver operation. No rendered accessibility or contrast pass is claimed by this proposal.

The final system-arrow UI could not be recaptured because the Mac was locked. Visual acceptance of these behavioral additions is blocked, not passed; existing visual identity and tokens remain the reference.
