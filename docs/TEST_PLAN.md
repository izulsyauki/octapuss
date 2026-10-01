# Octapuss verification plan

Planning targets, not completed test results. Prioritize engine behavior and recovery; static screenshot quality cannot prove cursor correctness.

## Focused automated checks

Use the app's native test target for behavior with real failure consequences:

- Hotspot scales with canvas size; coordinate conversion handles negative origins and mixed-scale displays.
- Manifest validation rejects nonfinite dimensions, missing representations, out-of-bounds hotspots, and invalid bundled paths.
- Unknown/corrupt preference values fall back safely.
- A failed start unwinds already acquired resources.
- Repeated start/stop/Restore does not leak monitors, overlays, or owned hide operations.
- A cancelled start or old callback cannot reactivate the engine.
- Permission loss and backend failure leave status consistent with actual effects.
- Incomplete cleanup retains ownership, blocks a new start, and enters RecoveryRequired until restoration is confirmed.

Use a fake backend for state transitions and resource ownership; validate actual rendering and permissions on macOS. Avoid tests that only restate view structure or token values.

## Manual native checks

| Area | Required cases | Evidence / pass condition |
| --- | --- | --- |
| Preview | All three variants and all sizes; enter/leave region | Visible tip matches clicks; normal pointer returns outside preview |
| Desktop | Finder, browser, editor, Dock, menus | Chosen scope behaves as labelled without stealing focus |
| Native roles | Arrow, text, link, resize, drag, prohibited operation | Interaction cues remain usable; document which roles are customized |
| Displays | Single Retina; available non-Retina; secondary display left/above primary; unplug/replug | No jump, clipped art, or hotspot drift |
| Workspaces | Spaces, Mission Control, fullscreen, Stage Manager | Exact supported behavior recorded; no universal coverage claim |
| Settings | Deny/grant/revoke access; corrupted preferences | Useful recovery, truthful state, no unrelated permission request |
| Lifecycle | Pause, Restore, repeated toggles, window close, Quit, sleep/wake, session switch; Restore/Quit while inside preview | Across-app effects stop; labeled preview remains after Restore; Quit removes preview cursor |
| Forced exit | Force Quit / process termination while active; relaunch | Pointer remains/restores usable; relaunch never auto-enables; unresolved effects enter recovery |
| UI | Light/dark; minimum/default sizes; every runtime state | Controls fit, messages reflect actual scope, no clipping |
| Accessibility | Keyboard-only, VoiceOver, increased contrast, reduced motion | Every action reachable; focus and state intelligible |

A locked session should retain native OS behavior; treat security/system surfaces outside the global customization promise unless explicitly verified. Do not attempt to draw over authentication UI as a feature.

If special hardware or an older OS is unavailable, mark that row **untested**. The release support matrix must reflect the evidence rather than the proposed deployment target.

## Permission testing

Use a fresh test account, Mac, or VM state when practical. A previously trusted development build is insufficient evidence of first-run behavior. Record bundle identity, signing mode, Sandbox status, selected event mask, and exact access required. Do not reset broad privacy settings on the user's ordinary account merely to make a test easier.

## Performance measurements

Record the Mac model, display refresh rates, selected backend, and measurement method. Measure Off, paused, idle active, continuous movement, and display transition. Use native profiling when available.

Provisional beta targets:

- Off/paused: no live tracking/timer loop and negligible background CPU.
- Overlay route: sustained movement should average below 5% CPU on the test Mac, with no accumulating event backlog.
- Tracking art must not visibly trail the real hotspot; investigate any lag of roughly one display frame or more.
- Memory/resources remain stable across 100 Enable/Pause/Restore cycles.

These are engineering goals, not existing benchmarks. Report observed values even if a target fails. A system cursor backend may have different performance characteristics and should be measured accordingly.

## Recovery contract

Restore means removing **Octapuss-owned across-app effects**, leaving a usable system pointer outside the labeled test region, and keeping pack/size preferences. Entering the preview still shows its custom cursor; Quit removes the preview region too. Verify Restore and Quit while the pointer is inside that region. For a private system-cursor route, define whether restoration means the captured pre-Octapuss baseline and how it behaves alongside another customization tool. Do not blindly overwrite somebody else's active theme.

Exercise Restore and Quit from Starting, NeedsPermission, Active, Paused, Suspended, Error, and RecoveryRequired. Inject a cleanup failure: retain the remaining resource/baseline ownership, show “Restoration incomplete,” prevent a new start, and verify Retry Restore. Off/Paused must require confirmed cleanup. If changes survive process exit, verify the durable recovery record was written before application and is checked on relaunch.

Forced termination cannot be verified through normal termination callbacks. If it leaves a hidden or permanently modified cursor, the backend fails release readiness until a concrete recovery strategy is demonstrated.

## Release blockers

An invisible/stuck pointer; wrong click hotspot; intercepted clicks; stolen focus; duplicate arrow in replacement mode; suppressed native interaction cues; unrecoverable cursor changes; runaway CPU/resource growth; misleading Active/permission state; or a claimed support case that was never tested.

For a companion product chosen by the user, both pointer and decoration being visible is intended. Keep this distinct from a replacement-mode defect.

## Beta evidence packet

Provide test commands/results, the manual matrix with pass/fail/untested entries, valid UI captures, measured performance, known limitations, build/run instructions, and an immediate recovery procedure. Do not announce all checks passed when manual or unavailable-platform cases remain unresolved.
