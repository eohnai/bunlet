---
summary: Each session row shows its agent, folder, prompt timer and previews. A request with no reply channel gets its own card.
---

# Session rows

## How it works

A row has a 32-point phase icon, the agent badge in its color, the project folder name, a short session ID chip when
two sessions share a folder, and a timer chip. Below it are "You: {prompt preview}", then "Using {tool}" while working
or the reply preview when done ([0019](../../decisions/0019-show-prompt-and-reply-previews.md)). Paths inside the session
folder are shown relative to it. A failed Claude turn shows **Failed**.

The phase icon is a hare: blue while working, orange while waiting for an approval or answer, green when the response
is ready, and red when the turn failed ([0035](../../decisions/0035-remove-the-unknown-session-state.md)). Status
words appear only for failed (red) and ended. Every state is still in the row's accessibility label.

Clicking a row jumps to the session's terminal or app ([pane navigation](../sessions/pane-navigation.md)) and collapses
the island. A **⋯** chip shows the full path, session ID and refresh time.

A request with no local reply channel shows a card with the tool name, "Pending approval" or "Pending question",
terminal guidance and **Jump to terminal**. A request with a verified channel shows only its [action card](../README.md#actions).

## Requirements

- The timer starts at the turn's `UserPromptSubmit` and stops at its final duration on `Stop`. It is computed from
  millisecond timestamps and hidden for idle, ended and turnless sessions.
- The timer ticks once a second only while the panel is open and a timer is running, using a conditional `TimelineView`.
- Rows show only the tool name from a request, never command or tool input.

## Open work

- Check on screen: two same-folder sessions, running and stopped timers, a request card and a failed turn's red hare.

## Decisions

[0017](../../decisions/0017-match-reference-island-ui.md),
[0019](../../decisions/0019-show-prompt-and-reply-previews.md),
[D3](../../DECISIONS.md#d3-add-view-models-only-where-a-view-owns-state).
