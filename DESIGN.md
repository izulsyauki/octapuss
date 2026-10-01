<!-- Hallmark implementation self-critique: Philosophy 4 · Hierarchy 4 · Execution 4 · Specificity 5 · Restraint 5 · Variety 4. -->
# Octapuss design direction

Phase 0 implements this direction as a native SwiftUI/AppKit feasibility app. Product-scale screens remain proposed until the cursor route is selected.

## Direction

**A playful character in a calm native utility.** The pointer is the focal object. The interface uses familiar macOS controls, system typography, generous test space, and a small amount of brand color.

The mascot is an abstract rounded cat head, two ears, and simplified tentacle feet. It appears once in onboarding or an empty state and in the app icon. The menu-bar version becomes a monochrome silhouette with no tiny eyes or cheeks. Avoid making every control a paw or tentacle.

This is a native workbench layout, rather than a marketing page. It has no hero, site navigation, or footer. Standard window chrome, buttons, menus, and focus affordances remain part of the design.

## Main customization window

Phase 0 default: **780 × 520 pt**. Minimum: **680 × 440 pt**. Later product screens should validate these dimensions again when their content exists.

```text
Octapuss                         Customization off         [Enable…]

Pointer presets       Preview inside Octapuss
                      ┌──────────────────────────────────────┐
● Ink                 │ Move here to try the actual pointer. │
○ Tide                │                                      │
○ Blush               │ Sample text       [Sample button]    │
                      │                                      │
                      └──────────────────────────────────────┘
                      Test background: Light / Dark

                      Size: Small / Medium / Large
                      [Restore system pointer]   Compatibility
```

This is a content schematic, not a screenshot. The preview should dominate the window; the short preset list needs no full application sidebar. At the minimum size, retain a usable preview and allow settings content to scroll. Do not crop actions or depend on a fixed screenshot layout.

Use an AppKit-backed preview region for the real cursor. Outside that region, Octapuss's controls retain their normal cursor behavior. A larger art sample may supplement the preview, but cannot replace testing at actual size.

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
| background | `#F6F1E6` | `#151D22` | Main canvas |
| surface | `#FFFCF5` | `#202B32` | Preview surround and grouped settings |
| textPrimary | `#202A31` | `#F5F1E8` | Main labels |
| textSecondary | `#5B6B72` | `#9CADB6` | Help and metadata |
| accent | `#16766D` | `#6EC9BB` | Primary action and selection |
| onAccent | `#FFFFFF` | `#151D22` | Primary action label |
| brandDetail | `#A44760` | `#ECA1B7` | Small mascot/pack detail |

Errors, warnings, selection behavior, disabled content, and focus should use appropriate native semantic treatment. Do not infer error/success from the brand colors. Validate contrast in rendered controls, including selected, hover, and disabled states.

Typography uses the macOS system font through native APIs. Proposed hierarchy: 22 pt semibold title, 15 pt semibold section labels, 13 pt body/control text, 12 pt help. Use native control sizing and adapt to accessibility settings.

Spacing follows a 4 pt scale: 8 pt related controls, 12 pt control groups, 16 pt panel padding, 24 pt major separation. Keep corners and borders consistent with native components rather than drawing ornamental containers around every setting.

## Interaction and states

| Runtime state | Message | Main action |
| --- | --- | --- |
| Off | Customization off · preview available | Enable with the backend's actual scope |
| Starting | Starting Octapuss… | Cancel |
| Active replacement | Octapuss active across supported apps | Pause |
| Active companion | Pointer companion active | Pause |
| Permission needed | Permission required | Explain permission / Open System Settings |
| Paused | Customization paused · preview available | Resume |
| Known suspension | Using system pointer here | Details / Restore |
| Error | Customization stopped | Retry / Restore |
| Recovery required | Restoration incomplete | Retry Restore / recovery instructions |

Never show Active merely because an enabled preference was saved. Only offer a suspension message for a condition the backend can actually detect. Do not invent reliable detection of secure surfaces, cursor roles, or every unsupported application.

The Enable label must be specific: **Enable across supported apps**, **Enable pointer companion**, or no global action for a preview-only build. The actual scope should remain visible beside status.

Preset and size changes update the preview immediately. When active, pre-validate a new asset before swapping it; a failed swap leaves the old valid setting running or safely stops the engine and reports the error.

Restore stops across-app effects and preserves selected preferences. The labeled test region continues showing the chosen preview cursor when entered; the system pointer is restored outside it. Reset preferences is a separate Settings action. Quit removes both the global effect and the preview region.

Show Off, Paused, or “Customization stopped” only after cleanup is confirmed. If restoration is incomplete, keep the recovery state visible and provide backend-specific instructions. Restore works from every state, including Starting, Permission needed, and Suspended; cancelling an in-progress start must also unwind any acquired effects.

## Onboarding and menu bar

First launch opens the usable preview with customization off. Explain the pointer scope in one sentence. Request a permission only after the action requiring it, with a purpose-specific explanation. Returning from System Settings rechecks access before offering Resume.

The menu bar contains status, Pause/Resume, Restore system pointer, Open Octapuss, Settings, and Quit. Restore and Quit remain reachable even when the engine has failed. Closing the customization window keeps the menu-bar utility running; make that behavior clear once.

Settings (`⌘,`) contains appearance, permissions and compatibility, and reset preferences. Launch at login is deferred until recovery is dependable. Diagnostics show the OS/backend and errors without collecting browsing or typing activity.

## Accessibility and motion

Support keyboard navigation, VoiceOver names, visible focus, text status, reduced motion, and increased contrast. Status cannot rely on color alone. The preview announces its purpose, not every pointer coordinate. Do not smooth or animate pointer tracking: the visual hotspot must follow the real position immediately.

Version one uses static pointers. Native control feedback may take roughly 150–200 ms; skip trails, wobble, looping mascot animation, and launch choreography.

Implementation review must inspect light/dark appearances at minimum/default window sizes, all runtime states, actual-size pointer edges, and keyboard/VoiceOver operation. No rendered accessibility or contrast pass is claimed by this proposal.
