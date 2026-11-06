# Native controls and focus

Status: implementation merged in PR #16; feature acceptance remains deferred.

Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

Keep native SwiftUI buttons, fields, labels, keyboard controls and focus states. Menu/Settings Open
Sessions explicitly expands and focuses the island. Respond explicitly focuses its composer; incoming
observations never activate the app. Escape collapses and returns focus only while this app owns it;
Done Editing resigns editing focus without changing session/request state. Settings uses its normal
key window and Escape behavior. Reduce Motion disables panel geometry transitions and frame animation.

Transparent Notch corners follow a rounded-shape mouse pass-through policy; native mouse gestures
remain owned until mouse-up. Pet uses artwork alpha for pointer input. Hidden/asleep presentations
cancel periodic animation/countdown work without stopping independently enabled monitoring.

- [ ] Inspect native Tab/Space/Return/Escape, field focus, explicit editing and focus return.
- [ ] Inspect Reduce Motion, visible labels, corner hit behavior, and hidden/asleep scheduling.

Source: NotchPanelController, NotchSessionView, LocalActionView, PetPanelController, PetWindowPlayback
and PetSettingsController. These source paths do not replace actual native acceptance.
