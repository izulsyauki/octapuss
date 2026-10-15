# Native system cursor backend

**Current extension:** imported packs now apply all assigned, available roles, including animation. See [full-pack scope and current evidence](FULL_PACKS.md). The arrow-only milestone and its historical evidence below are retained for context. Text/link operation has since been confirmed by the user; 56-slot Apply/Restore and owned-worker crash recovery passed on this host.

## Background helper packaging

Registry reads and crash recovery run through `Contents/Helpers/OctapussCursorHelper.app`, a bundled child executable with its own identifier and `LSBackgroundOnly = true`. Previously these modes launched the regular Octapuss executable, whose AppKit initialization could register another Dock application. The helper starts with prohibited activation policy, cannot create windows, and rejects invalid arguments without entering SwiftUI. A missing packaged helper fails explicitly rather than launching the interactive app as a fallback. Standalone test runners retain their command-line dispatch.

Both the Command Line Tools builder and the Xcode app build phase package and sign the helper before signing the parent app. It is not a login item or independently installed app. Reproduce packaged read-only checks with `rtk proxy python3 OctapussTests/CursorHelperChecks.py /tmp/octapuss-phase0/Octapuss.app`: policy and zero windows, invalid arguments, a real registry read, and watchdog readiness/EOF exit without a cursor journal or system mutation. Full Xcode execution remains untested on this host.

The user changed the requested scope from app-local preview to system-wide native-style customization on 15 October 2026. The first backend milestone replaces registered standard arrow slots while preserving native text, hand, resize, busy, and application-owned cursors.

## API research

- Apple's [NSCursor.current](https://developer.apple.com/documentation/appkit/nscursor/current) documents application-local cursor scope; setting it cannot establish a theme across other applications.
- Private CoreGraphics/SkyLight registration entry points exist in reverse-engineered [CGSCursor ABI declarations](https://github.com/alexzielenski/Mousecape/blob/master/Mousecape/mousecloak/CGSInternal/CGSCursor.h). Octapuss dynamically resolves only the functions it needs; no upstream implementation or artwork is bundled.
- [MaCursor's upstream README](https://github.com/writronic/MaCursor) identifies ArrowS as an additional macOS 26 arrow slot. Availability and behavior must be checked on the actual host.
- Apple's [App Review guideline 2.5.1](https://developer.apple.com/app-store/review/guidelines/#software-requirements) requires public APIs. This backend is a direct-distribution experiment; it is not an App Store implementation.

## Required safety boundary

Never write a registered system cursor unless all affected slots can first be backed up and the baseline is saved durably. A failure must retain recovery ownership rather than claim Off. Restore must target only Octapuss-owned registrations and preserve another cursor utility's later changes. No focus stealing, pointer hiding, security-setting changes, screenshot collection, privileged installation, or login item is part of this backend.

Private API availability alone does not prove visible cross-app behavior, click accuracy, or recovery. Record each separately. No claim of universal application, fullscreen, secure-surface, OS-version, or hardware support is justified by one host.

## Read-only compatibility probe

`rtk proxy zsh scripts/build-phase0.sh --probe-system` resolves the required entry points and reads existing Arrow/ArrowS registration metadata and image representations. It performs no cursor registration or global theme change.

## Implemented behavior

- Explicit Apply system arrow registers the chosen style and size for Arrow and ArrowS. Selection changes remain a preview until Apply is pressed again.
- Applied status retains the preset and size actually registered, independent of later preview selection. Recovery and pointer-color warnings take precedence in status. Nondefault macOS pointer outline/fill colors block Apply before registration; Settings provides Open System Settings and Reset Colors guidance.
- Baselines for every affected slot are read before mutation and stored atomically under `~/Library/Application Support/Octapuss/system-arrow-session.json`.
- A temporary recovery subprocess starts and acknowledges readiness before any registration. It watches a pipe, restores on EOF after a parent crash, and exits. No privileged helper or login item is installed.
- File locking serializes changes and recovery. Pixel comparison detects ownership changes by another utility; the backup is retained on conflict. A conflict in one slot does not prevent restoration of other owned slots.
- Each new journal and recovery subprocess share a UUID session generation. Under the journal lock, a retired subprocess restores or removes only a journal with its own UUID, preventing a previous watcher from reverting a newer session.
- The private read API can retain stale registrations within a process, including across newly created WindowServer connections. One-shot reader subprocesses provide independent global-registry reads for backup and verification. They collect only cursor image/metadata; no pointer movement, screen content, or app activity is captured.
- Restore and Quit restore the saved baseline; sleep and session deactivation request restoration. Startup attempts recovery before further application.
- Explicit Apply reconciles a stale session after external changes such as Reset Colors: restore still-owned slots, archive the conflicting journal as `system-arrow-backup-<UUID>.json`, and use the current system cursor as the next baseline. External changes are never overwritten during reconciliation. Actual restoration/verification failures continue to block Apply and retain the active journal.
- Restore also pauses the independent app-local preview. Resume preview affects only that playground; applying a system arrow is always explicit. Incomplete restoration retains recovery status and prevents ordinary Quit.

## Host evidence: 15 October 2026

| Check | Observed result |
| --- | --- |
| Read-only compatibility probe | Required private entry points resolved; Arrow and ArrowS both readable with four representations |
| Original registration | Both slots: 28 × 40 pt, hotspot (4, 2), one frame |
| Blush/Large application | Both slots: 40 × 40 pt, hotspot (2.5, 2.5), four representations matching the generated images |
| Background registration persistence | Both modified registrations remained after Finder was raised |
| Normal Apply/Restore integration check | Passed: decoded baseline pixels, dimensions, hotspot, and journal removal verified using fresh reader processes |
| SIGKILL integration check | Passed: only an owned worker was killed; the recovery subprocess restored both slots and removed the journal |
| Fake-backend regression checks | Passed: partial rollback, repeated Restore, ownership conflict, restoration of unaffected owned slots despite a conflict, and a retired watcher leaving a newer session untouched |
| Actual visible theme with this host's pointer color override | Not accepted: macOS currently has a custom turquoise pointer outline, and the displayed cursor retained the system shape despite changed registrations |

The UI detects nondefault pointer outline/fill colors and blocks Apply with setup instructions. It does **not** reset the user's Accessibility colors. Follow Apple's [pointer appearance instructions](https://support.apple.com/guide/mac-help/mchlp2920/mac): System Settings → Accessibility → Display → Pointer → Reset Colors, then return to Octapuss and Apply. Defaults are a white outline and black fill. The override behavior is also described by [MaCursor upstream](https://github.com/writronic/MaCursor#your-cursor-goes-back-to-the-default-in-other-windows).

### Follow-up repair after Reset Colors

The user reset colors, but Apply was blocked by an old journal: the reset changed both arrow registrations to a new native baseline (28 × 40 pt, hotspot 4.5, 4), which correctly failed the old ownership check. The UI reported restoration needed. Explicit Apply now reconciles that conflict without losing the old backup or replacing external artwork during reconciliation.

Verified on the unlocked host: Apply reported Tide/Large, System Settings showed default white outline/black fill, and the actual displayed system cursor returned by `NSCursor.currentSystem` was the mint Tide artwork, 40 × 40 pt with hotspot (2.5, 2.5), outside the playground. Its rendered image was 122 × 122 pixels because the existing Accessibility pointer size was 1.524757 on a Retina display; this scaling prevents exact comparison with unscaled source representations. The read-only probe supports optional `OCTAPUSS_CURSOR_DIAGNOSTIC_PATH` export of the cursor image alone for visual inspection. Restore succeeded in the UI; normal Apply/Restore and owned-worker SIGKILL recovery passed again. Regression coverage includes stale-journal archival, preservation of external changes, restoration to the new baseline, and refusal to archive on a write failure.

## Reproduce verification

- Safe/fake checks: `rtk proxy zsh scripts/build-phase0.sh --check`.
- Read-only host check: `rtk proxy zsh scripts/build-phase0.sh --probe-system`.
- **Opt-in real system mutation check:** `rtk proxy zsh scripts/build-phase0.sh --check-system-live`. It temporarily registers the arrow, restores it, then kills only its own test worker to exercise crash recovery. Do not run while another cursor utility is changing themes. It leaves Accessibility color settings untouched.

Full Xcode validation, physical hotspot/click observation across applications after Reset Colors, text/link/resize workflow observation, fullscreen, multiple displays, other OS/hardware combinations, sleep/session switching, and notarized distribution remain **untested**. This is an experimental native registration backend, not a claim that every pointer in every app is replaced.

The initial implementation's final UI recapture was blocked by a locked Mac. The follow-up repair above supersedes that blocker for this host's system-arrow rendering and Apply/Restore controls; the broader untested cases remain untested.
