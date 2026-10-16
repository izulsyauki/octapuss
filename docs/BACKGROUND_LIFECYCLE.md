# Menu-bar background lifecycle

Dock Quit and the app menu's **Keep Running in Menu Bar** (⌘Q) cancel ordinary termination, hide the windows, and switch to AppKit's accessory activation policy. They leave the cursor store, applied registrations, continuation observers, and recovery helper alive. Closing the last window also leaves the process running.

**Open Octapuss** in the menu-bar menu restores regular activation, opens the library, and activates the app. Finder/Launchpad reopening uses the same activation path. **Quit Octapuss** in the menu-bar menu explicitly permits termination only after `prepareToQuit()` restores the cursor. A restoration failure cancels termination and brings the error window forward. This avoids restoring twice on a successful Quit.

System Quit events carrying logout, restart, shutdown, or Quit All reasons also use the restoration path. Their reason is read from the Apple event attribute, with a parameter fallback. Ordinary termination requests stay in the background. Force Quit and crashes still rely on the existing watchdog recovery. No login item is installed.

## Verification on 16 October 2026

The Command Line Tools regression checks passed: ordinary termination preserves preview state, closing the last window does not terminate, explicit termination restores, and synthetic system Quit events restore and allow termination. Existing import, pack, preference, continuation, rollback, deletion, and restoration checks also passed.

The built app applied the current Anya pack across 53 slots. The background menu action retained the same process ID and changed its Launch Services application type from `Foreground` to `UIElement`. Reopening retained **System pack: Anya · 12 roles**. The final build's background command goes through the same `NSApplication.terminate` delegate path as Dock Quit; it remained a `UIElement` with its 53-slot active recovery journal intact. The app was left running in that background state. UI automation automatically reopens hidden app windows when inspecting them, so background state was checked separately with read-only Launch Services inspection. The final app's deep, strict code-signature verification passed.

Direct Dock-context-menu interaction and clicking the status-menu Quit item could not be reached by this UI automation connection. Actual logout/restart/shutdown and other macOS versions remain untested; synthetic event checks do not perform those disruptive actions. Full Xcode/XCTest remains unavailable on this host.
