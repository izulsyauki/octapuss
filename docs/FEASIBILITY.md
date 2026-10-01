# macOS cursor feasibility

Research date: **1 October 2026**. These are documentation findings and a proposed experiment, not measured Octapuss behavior.

## What is established

| Route | Evidence | Planning consequence |
| --- | --- | --- |
| Custom cursor in Octapuss | AppKit has image/hotspot cursors and view cursor regions | Use for the preview baseline |
| Drawing beside the real pointer | Click-through windows and pointer observation are available | A companion experiment is plausible; compatibility still needs testing |
| Replacing the global pointer through overlay + public hide APIs | Foreground restrictions apply to documented cursor hiding | Unproven as a background utility; do not promise it |
| Private system cursor APIs | Mousecape documents this approach | An alternative requiring an explicit backend/distribution decision |

### App-local cursor scope

Apple describes `NSCursor.current` as the application's own cursor; it can differ from the visible cursor when another app is active. Treat custom `NSCursor` artwork as a supported in-app mechanism, not an API contract for global themes. [NSCursor](https://developer.apple.com/documentation/appkit/nscursor), [current](https://developer.apple.com/documentation/appkit/nscursor/current).

### Public hide and overlay limits

`CGDisplayHideCursor` increments a hide count, and Apple says the caller normally needs to be foreground. Its display argument does not select a screen. This is the central risk for a background overlay pretending to replace the system pointer. [Hide cursor](https://developer.apple.com/documentation/coregraphics/cgdisplayhidecursor%28_%3A%29).

Owned hide/show operations must balance; cleanup cannot indiscriminately reset another app's cursor state. [Apple's cursor control overview](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html), [Show cursor](https://developer.apple.com/documentation/coregraphics/cgdisplayshowcursor(_:)).

An overlay window can pass clicks through with `ignoresMouseEvents`. Space/fullscreen collection behaviors are available, but do not establish universal access to system UI, security surfaces, or every fullscreen application. Verify the chosen behaviors instead of stacking arbitrary window flags. [Click-through windows](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents), [Collection behaviors](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct).

**Inference from these sources:** a public overlay prototype is useful to measure behavior, but it is not a dependable assumption for real global replacement. The small feasibility test should confirm the expected limit, not spend days attempting to defeat it by stealing focus.

### Permissions

An `NSEvent` global monitor observes other apps asynchronously, cannot alter their events, and excludes Octapuss's own events. Combine appropriate local observation if this route is selected. Keyboard trust requirements do not justify automatically requesting Accessibility for mouse-only behavior. [Global monitor](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)).

Apple DTS confirms a supported sandboxed `CGEventTap` path using Input Monitoring on modern macOS. Test on a fresh permission state, because a development machine's prior grants can conceal requirements. Prefer passive listening and only necessary event types. [Apple DTS, January 2026](https://developer.apple.com/forums/thread/811443), [listen-only option](https://developer.apple.com/documentation/coregraphics/cgeventtapoptions/listenonly).

Do not request Screen Recording for this MVP. `NSCursor.currentSystem` is deprecated, and the research did not establish a reliable public global cursor-role notification. Do not promise automatic cross-app arrow/I-beam/resize recognition. [currentSystem](https://developer.apple.com/documentation/appkit/nscursor/currentsystem).

### Existing replacement approach

Mousecape's upstream README describes private CoreGraphics calls and a daemon for actual system cursor replacement. That demonstrates a possible technical family, not current compatibility for Octapuss or a public API guarantee. The repository's reuse conditions include a noncommercial restriction; do not copy its code or assets into Octapuss under an assumption of unrestricted reuse. [Mousecape upstream](https://github.com/alexzielenski/Mousecape).

Apple's App Review guideline 2.5.1 requires public APIs. A private replacement route needs a direct-distribution strategy and explicit maintenance/recovery work; direct distribution does not prove compatibility or successful notarization. [App Review guidelines](https://developer.apple.com/app-store/review/guidelines/).

### Coordinates and lifecycle

Use a documented coordinate convention and test secondary screens with negative origins. AppKit's mouse position uses screen coordinates; backing scale varies by screen and must not become one global multiplier. Screen configuration can change while the app runs. [mouseLocation](https://developer.apple.com/documentation/appkit/nsevent/mouselocation), [NSScreen.screens](https://developer.apple.com/documentation/appkit/nsscreen/screens), [backingScaleFactor](https://developer.apple.com/documentation/appkit/nsscreen/backingscalefactor).

Session deactivation and event-tap timeout are concrete lifecycle events to handle. Do not claim normal termination handlers run after forced termination. [Session deactivation](https://developer.apple.com/documentation/appkit/nsworkspace/sessiondidresignactivenotification), [Tap timeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout).

## Phase 0 experiment

**Timebox: up to two focused engineering days after developer tools are ready.** This is a planning allocation, not a delivery estimate. Stop early when decisive evidence rules out a route.

1. **Environment:** locate full Xcode, verify SDK/deployment target, and record OS/hardware. Create a minimal native proof, separate from a polished product shell.
2. **Preview baseline:** one static cursor, an explicit hotspot, a test region, and correct restoration when leaving it.
3. **Companion baseline:** click-through pointer-following artwork with the native pointer visible. Establish geometry, event coverage, focus behavior, and minimal permissions.
4. **Public replacement check:** briefly test balanced documented hiding while Octapuss is active, then in the background over Finder, Safari, and an editor. Observe the screen as well as return codes. Do not repeatedly activate Octapuss to manufacture success.
5. **Early recovery check:** Pause, Restore, Quit, failed start, and forced termination. Run dangerous-to-usability cases only with a concrete manual recovery method available.
6. **Record limitations:** test available displays, dragging, text selection, menus, Spaces/fullscreen, sleep/wake, and permission denial. Mark unavailable hardware/OS cases untested.

Use manual visual inspection or authorized computer-use observation for cross-app behavior; unit tests alone cannot prove global rendering. Do not install a helper, apply private system cursor changes, or alter global permissions just to bypass a failed public check.

## Gate report required from the implementation model

Create `docs/FEASIBILITY_RESULTS.md` during implementation, containing:

- Exact OS, hardware, SDK, app signing/sandbox mode, backend, and event mask.
- Required permissions, tested from a fresh state where possible.
- Per-context observations and screenshots or recordings when available.
- Whether the native pointer remained visible, returned after switching apps, or lost its semantic behavior.
- Restoration results for normal and forced termination.
- A conclusion of **pass**, **fail**, or **inconclusive**, plus untested cases.
- A concrete recommendation and the smallest next milestone.

Template for the behavior table:

| Context | Intended scope | Native pointer visible? | Hotspot/click accurate? | Restore works? | Result/evidence |
| --- | --- | --- | --- | --- | --- |
| Octapuss preview | App-local | To test | To test | To test | Not run |
| Finder / Safari / editor | Desired replacement | To test | To test | To test | Not run |
| Text / links / resize / drag | Preserve native meaning | To test | To test | To test | Not run |
| Other display / fullscreen | Declared supported scope | To test | To test | To test | Not run |
| Quit / forced termination | Recovery | To test | N/A | To test | Not run |

## Route decision after evidence

- **Public replacement passes:** define a narrow tested support matrix and preserve native interaction cues. Proceed only if the acceptance criteria below are met.
- **Public replacement fails:** present a named pointer companion as an alternative, with screenshots and exact behavior. Do not silently ship it as replacement.
- **Actual global themes remain required:** prepare an isolated private-backend research proposal with recovery and distribution consequences, then use the user's scope decision before implementation of that route.
- **User wants only in-app customization:** omit global monitoring/overlay entirely and build the preview/editor utility scope they selected.

For a replacement pass, a static arrow must remain accurate in the supported normal desktop workflow, avoid a duplicate arrow, keep text/link/resize cues usable, require no focus stealing, and restore reliably. If an arrow-only overlay hides those cues and cannot identify when to yield, it fails this MVP gate.

## Planning environment snapshot

Read-only checks found macOS **26.5.1** and active developer directory **`/Library/Developer/CommandLineTools`**. `xcodebuild -version` reported that full Xcode is required for that command. This establishes the active toolchain, not whether an Xcode app is installed elsewhere. Recheck when implementation begins; nothing was installed or reconfigured during planning.
