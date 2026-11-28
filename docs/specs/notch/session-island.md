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
- **Opening:** hovering the pill for 200 ms or clicking it opens the panel.
- **Closing:** a click anywhere outside the island closes it, whether hover-to-open is on or off. This includes clicks
  in other apps, in Settings and on the island's transparent corners. A click while typing closes it too, and the
  unsent reply text stays as a draft. With **Collapse when the pointer leaves** on, leaving for 300 ms closes it unless
  a text field is being edited. Keyboard focus alone, as after **Open Sessions**, does not count as typing. Escape
  collapses it.
- **Open:** the panel is 680 to 704 points wide (46% of the screen width) and grows with its content up to 280 points by
  default. A saved maximum height wins. The top row has the [quota badges](allowance-strip.md) left of the notch, and
  today's tokens, **Clear all sessions** and **Settings** on the right. Each side keeps its width when it is empty,
  so the buttons stay at the right edge when no quota badge shows.
- **Alerts:** new approvals, questions and completions open the panel without taking focus. Completions, and requests
  with no local reply channel, close after the reminder duration (5 seconds by default) unless the pointer is inside. A completion does not open the panel
  while another listed session waits for an answer. Focus-aware suppression applies only when the session's own app
  is in front.
- **Pet:** dragging the closed pill down more than 50 points pulls the pet out.

**Which sessions are listed** ([0032](../../decisions/0032-list-sessions-like-the-reference.md)). A session waiting for
an approval or answer is always listed. Otherwise an ended session leaves at once, an idle session stays out until its
first accepted prompt, and any session quiet longer than **Clear quiet sessions after** (7 days by default)
leaves. Hovering a row shows **✕**. Removed rows stay hidden until the session reports new activity. The pet panel,
the pet's mood and the switch-session shortcut use the same list.

**Order.** Sessions waiting for an approval or answer come first, then response ready, working, idle, and ended last.
There is no unknown state ([0035](../../decisions/0035-remove-the-unknown-session-state.md)). The selected session stays selected while updates arrive.

## Requirements

- New alerts never take keyboard focus. Only Open Sessions and Respond do.
- Transparent areas pass clicks through to the windows below.
- Sessions without terminal metadata are listed normally.
- Views render store snapshots through `NotchPresentation`. Session meaning stays in the store.

## Open work

- Check on screen: focus, click-through, keyboard expansion, hover-open and notification-open.
- Check on screen: a click outside closes the island with hover-to-open off, and leaving closes it after
  **Open Sessions**.
- Check on screen: the closed pill's height on the 13-inch MacBook Air and with an auto-hidden menu bar.
- Check on screen: response-ready, failed and ended states, and the listing rules from decision 0032.

## Decisions

[0017](../../decisions/0017-match-reference-island-ui.md) island UI,
[0030](../../decisions/0030-keep-requests-visible-and-report-failures.md) requests stay visible,
[0032](../../decisions/0032-list-sessions-like-the-reference.md) listing rules.
