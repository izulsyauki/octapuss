# App-local repair verification

Date: 15 October 2026. Scope: the app-local Octapuss executable, not global cursor replacement.

## Defects corrected

- The sample button had an empty action. Boop now registers clicks and updates both the playground count and accessible diagnostic text.
- Restore stopped only global lab effects, leaving the actual app-local cursor active. Restore now disables the custom cursor in the playground; Resume explicitly reactivates it. Style changes and preference reset preserve the paused state.
- A separate transparent view owned cursor rectangles while underlying SwiftUI views owned input. A single native AppKit preview now owns its cursor region, tracking area, rendering, and native NSButton. There is no hit-test overlay.
- Light preview text relied on the ambient system appearance, causing weak secondary text contrast under dark macOS appearance. The native preview resolves its own foreground and secondary colors and control appearance.
- Preview background preference was lost on relaunch. It is now stored with style and size.
- Global polling, companion panels, and cursor hiding were unrelated to the selected scope. They have been removed from the executable, leaving no tracking timer or global cursor hide/show ownership to recover.
- The window now defaults to 840 × 560 pt, with a 760 × 500 pt minimum and scrollable main content.

## Automated evidence

`rtk proxy zsh scripts/build-phase0.sh --check` compiles the same app source with an isolated regression entry point. On the available Mac it completed checks for:

- Invalid saved style/size fallback and saved style/size/background reload.
- All nine style/size cursor combinations, image dimensions, and scaled hotspots.
- Native click-target hit testing at 480, 560, and 760 pt preview widths.
- Twenty native button actions, each registering exactly once.
- Repeated Restore, preset changes while paused, Resume, reset while paused, and quit preparation.

These are executable native regression checks, not an XCTest suite. They use isolated UserDefaults and leave the user's preferences untouched.

## Live checks

Using the actual macOS app UI:

- Boop updated the count and footer.
- Restore showed the paused state and Resume action.
- Selecting Blush, Large, and Dark while paused kept the preview paused.
- Resume and Settings reflected the same state; Settings Restore updated both.
- Standard Command-Q exited. Relaunch retained Blush, Large, and Dark, with a fresh local preview and click count.
- Light and dark playground renders were inspected in the available dark macOS appearance.

## Toolchain and limits

The Command Line Tools compiler produced the app using the script's installed macOS 15.4 sysroot workaround. `Octapuss.xcodeproj` now provides a minimal shared app scheme; its project syntax is valid according to `plutil`. Running xcodebuild reports that full Xcode is required, so Xcode compilation, signing/capabilities, and XCTest execution remain **untested**.

Human-visible pointer edge/hotspot inspection, sustained CPU/frame profiling, minimum-size whole-window interaction, light macOS appearance, VoiceOver speech, multiple displays, older macOS releases, Intel hardware, and Force Quit/reopen remain **untested**. No zero-defect or cross-device compatibility claim is made.
