# System arrow backend

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

The final UI detects nondefault pointer outline/fill colors and blocks Apply with setup instructions instead of reporting visible success. It does **not** reset the user's Accessibility colors. Follow Apple's [pointer appearance instructions](https://support.apple.com/guide/mac-help/mchlp2920/mac): System Settings → Accessibility → Display → Pointer → Reset Colors, then return to Octapuss and Apply. Defaults are a white outline and black fill. The override behavior is also described by [MaCursor upstream](https://github.com/writronic/MaCursor#your-cursor-goes-back-to-the-default-in-other-windows).

## Reproduce verification

- Safe/fake checks: `rtk proxy zsh scripts/build-phase0.sh --check`.
- Read-only host check: `rtk proxy zsh scripts/build-phase0.sh --probe-system`.
- **Opt-in real system mutation check:** `rtk proxy zsh scripts/build-phase0.sh --check-system-live`. It temporarily registers the arrow, restores it, then kills only its own test worker to exercise crash recovery. Do not run while another cursor utility is changing themes. It leaves Accessibility color settings untouched.

Full Xcode validation, physical hotspot/click observation across applications after Reset Colors, text/link/resize workflow observation, fullscreen, multiple displays, other OS/hardware combinations, sleep/session switching, and notarized distribution remain **untested**. This is an experimental native registration backend, not a claim that every pointer in every app is replaced.

The latest repair rerun verified normal Apply/Restore baseline pixels, dimensions, hotspot, and journal cleanup; SIGKILL recovery restored both slots and removed the journal. Final UI recapture was unavailable because the Mac was locked. Visual acceptance of the final controls, status, and pointer-color guidance is **blocked**, not passed.
