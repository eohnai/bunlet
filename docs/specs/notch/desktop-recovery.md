# Native desktop recovery

Status: implementation merged in PR #16; feature acceptance remains deferred.

Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

The app owns the Notch panel and shared session/action services. Keeping its hosting view alive across
hide/return, display changes, sleep and Spaces preserves card selection, field focus and drafts.
Geometry is observable app state: update header height, cutout width and frame for the current display
without replacing the view. Prefer a display with a physical notch, then the previous display if still
present, then main. Apply the existing bounded NotchPlacement calculation, including small displays.

Use native canJoinAllSpaces/fullScreenAuxiliary behavior. Screen and active-Space notifications update
geometry/visibility without activation; willSleep hides the panel and wake restores allowed visibility.
Pet detachment suppresses Notch until explicit Show/Return. Hidden/asleep Notch cancels its periodic
prompt/allowance presentation timers, while app-owned services retain their independent lifecycle.
Respect Reduce Motion for panel geometry and SwiftUI presentation.

Only explicit Open Sessions or Respond acquires keyboard focus. Native Tab/Space/Return works through
normal controls. Escape collapses and returns focus only to the still-running previous application if
this app still owns focus; automatic recovery never activates it. Settings remains separately available.
A pointer-driven pass-through policy follows the visible rounded shape; transparent corner regions do
not intercept another app's clicks. Preserve an active mouse drag until its mouse-up.

- [ ] Inspect real display add/remove, size/cutout changes, fullscreen/Spaces and sleep/wake.
- [ ] Inspect keyboard entry, Escape/focus return, draft/selection retention and transparent corner clicks.
- [ ] Inspect hidden/asleep timers and Reduce Motion in the actual app.

These are deferred acceptance tasks, not new runtime checks authorized by the implementation goal.

Source: NotchWindowState and the existing hosting view → NotchPanelController native notifications/geometry/focus/hit policy → visibility-aware prompt/allowance views. PetSettingsController clamps Settings on display changes/wake. Menu and Settings expose Open Sessions. No native verification has run.
