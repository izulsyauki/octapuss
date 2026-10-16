# Apply feedback and cancellation

The user requested explicit Busy feedback while applying a pack. This is separate from macOS choosing a semantic loading cursor during real application waiting. It must not reintroduce the intermediate resize/text/loading flashes fixed by non-instant native registration.

## User behavior

- Apply immediately publishes **Applying <pack>…**. The action bar shows a native indeterminate progress indicator and the selected pack's Busy artwork. Working artwork is the fallback; without either, only the native progress indicator appears.
- The playground temporarily previews the same loading artwork, including its actual custom cursor inside that region. It returns to the selected cursor when Apply finishes. Anya's Busy image is static; Goku's Busy sequence is animated.
- Animation pauses for Reduce Motion or an inactive window. No global cursor is forced just to display progress.
- Apply and selection/edit/import controls are disabled during the transaction; repeated Apply requests are ignored. The captured pack, size and label cannot drift to a different selection mid-operation.
- **Cancel and restore** requests cancellation immediately. A native write cannot be interrupted safely, so cleanup follows the in-flight step. Status changes to **Restoring pointer…**. The task restores the baseline, disables preview, and cannot publish a late successful Apply.
- Full menu-bar Quit during Apply waits for cancellation/restoration using AppKit's deferred termination reply. Dock Quit still keeps the task running in the menu bar. A restoration failure cancels full Quit and exposes recovery.
- Lock/sleep/session interruption during Apply cancels that transaction and restores. It does not later activate the interrupted pack; Apply again after returning. An already completed pack retains its existing normal suspension/resumption behavior.

## Implementation boundary

ProofStore captures immutable Apply input on the main actor. Artwork decoding/pack snapshot preparation runs in a detached task. SystemCursorSession confines instance mutations, helper lifetime and native writes to one private serial queue. Async replacement holds the journal lock across reconciliation and new application. Synchronous recovery callers use the same queue; the existing generation UUID protects against an old watchdog.

The `@unchecked Sendable` session annotation is justified by that queue confinement; mutable session state must not be accessed outside its operation methods. `hasPendingRecovery` only reads journal existence. Images are decoded into private bitmap contexts without background NSView drawing. Main-actor state publication and app-local animation remain separate from native registrations.

## Verification

Executable checks passed with injected native access and a registration barrier: busy artwork/status is available while the main actor continues running; duplicate Apply is ignored; success clears progress; Cancel restores every baseline and removes the journal; write failure clears progress and rolls back; Quit waits for cleanup; a lock/return interruption cannot cause late activation. Existing transaction, import, role, deletion, preview-animation and lifecycle checks passed, including Anya and Son Goku fixtures.

Native integration and interactive visual evidence are recorded in [STABILITY_REPORT.md](STABILITY_REPORT.md). Full Xcode is unavailable locally, and hosted validation remains blocked by the previously recorded GitHub account restriction.

The live Anya check passed 53-slot Apply/Restore and owned-worker SIGKILL recovery. Native UI inspection captured the Applying label, Busy artwork, progress indicator and Cancel button; a real Restore shortcut during Apply completed cancellation with preview paused. The app was left with Anya reapplied at Small. Actual in-flight menu-bar Quit and physical sleep interruption remain untested.
