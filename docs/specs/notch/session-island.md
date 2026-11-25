---
summary: A pill around the camera notch that opens into a panel listing agent sessions, without taking keyboard focus.
---

# Session island

## How it works

One fixed transparent window, 740 points wide, sits at the top center of the notched screen. Only the black shape
inside it takes the pointer. `IslandGeometry` computes the frame. Exact values are in the
[island UI reference](../../notes/reference-ui.md).

- **Closed:** a pill as tall as the notch with the phase icon, the session count, and a label on screens without a
  notch. On a notched screen it reaches up to 1 pt below the safe area, to hide the step where the cutout meets the
  sides. Edges align to display pixels at the screen's backing scale.
- **Opening:** hovering the pill for 200 ms or clicking it opens the panel. Leaving for 300 ms closes it unless the user
  is typing. Escape collapses it.
- **Open:** the panel is 680 to 704 points wide (46% of the screen width) and grows with its content up to 280 points by
  default. A saved maximum height wins. The top row has the [quota badges](allowance-strip.md) left of the notch, and
  today's tokens, **Clear all sessions** and **Settings** on the right.
- **Alerts:** new approvals, questions and completions open the panel without taking focus. Completions, and requests
  with no local reply channel, close after the reminder duration (5 seconds by default) unless the pointer is inside. A completion does not open the panel
  while another listed session waits for an answer. Focus-aware suppression applies only when the session's own app
  is in front.
- **Pet:** dragging the closed pill down more than 50 points pulls the pet out.

**Which sessions are listed** ([0032](../../decisions/0032-list-sessions-like-the-reference.md)). A session waiting for
an approval or answer is always listed. Otherwise an ended session leaves at once, an idle or unknown session stays out
until its first accepted prompt, and any session quiet longer than **Clear quiet sessions after** (7 days by default)
leaves. Hovering a row shows **✕**. Removed rows stay hidden until the session reports new activity.

**Order.** Confirmed requests come first, then response ready, working, idle, unknown sessions and unconfirmed
requests, and ended last. The selected session stays selected while updates arrive.

## Requirements

- New alerts never take keyboard focus. Only Open Sessions and Respond do.
- Transparent areas pass clicks through to the windows below.
- Sessions without terminal metadata are listed normally.
- Views render store snapshots through `NotchPresentation`. Session meaning stays in the store.

## Open work

- Check on screen: focus, click-through, keyboard expansion, hover-open and notification-open.
- Check on screen: the closed pill's height on the 13-inch MacBook Air and with an auto-hidden menu bar.
- Check on screen: response-ready, ended and unknown states, and the listing rules from decision 0032.

## Decisions

[0017](../../decisions/0017-match-reference-island-ui.md) island UI,
[0030](../../decisions/0030-keep-requests-visible-and-report-failures.md) requests stay visible,
[0032](../../decisions/0032-list-sessions-like-the-reference.md) listing rules.
