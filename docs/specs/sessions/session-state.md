---
summary: One in-memory store turns events into per-session state. The latest event decides, and there is no unknown state.
---

# Track agent session state

## How it works

`SessionStore` receives events from the inbox and keeps one record per agent and session ID. Each session has a
status: idle, working, question needed, approval needed, response ready or ended. Turns are correlated by turn ID, and
pending requests are tracked by request identity. Previews, the current tool, running subagents, the reported terminal
and a failed-turn flag are display-only extras. State lives in memory only, so after a restart sessions need fresh
events.

The latest event decides a session's state ([0035](../../decisions/0035-remove-the-unknown-session-state.md)):

- A prompt starts a new turn and shows working. It closes any request left from the previous turn, because an
  interrupted turn sends no stop.
- A tool event shows working, also after a stop. A request shows approval needed or question needed.
- A finished tool closes its request. A request without a tool-call ID is closed by a finished tool with the same name.
- A stop shows response ready and closes every open request. A stop that names another turn still counts.
- A start or prompt after an end reopens the session, because agents resume with the same session ID.
- A session first seen in the middle of a turn, for example after an app restart, takes its state from that event.

A session keeps its last state until a new event changes it. A quiet session is normal: a finished session, or one
waiting for the user, sends no events ([0034](../../decisions/0034-keep-the-last-session-state.md)).

Some events change nothing: an exact duplicate, a second event that reuses an event ID, an event captured before the
latest applied one, a late event from a retired turn, and anything except a start or prompt after an end. A wake or
clock change keeps every state and resets the capture times, so later events still apply. A full session forgets old
event and turn IDs instead of refusing events. Turning tracking off for a provider removes its sessions.

## Requirements

- Concurrent sessions stay distinct, including two in the same project folder.
- A finished response produces a response-ready state. It never claims the task succeeded.
- No session is ever shown as unknown. A new prompt always brings a session back to working.
- Elapsed time alone never changes a session's state.
- Sleep, wake and clock changes never freeze a session.
- The store follows the contract's limits, including at most 128 sessions.
- The store alone classifies requests and orders events. Adapters and views do not repeat these rules.

## Out of scope

- Which sessions the island lists and in what order: [notch/session-island](../notch/session-island.md).
- Delivery health: [integration-health](integration-health.md).
- Transcript parsing and process-liveness guesses.

## Open work

- Codex reports no interrupt event, so an approval stays listed after the user interrupts until the next prompt.
- Check on screen that a session interrupted with an open approval returns to working at its next prompt.

## Decisions

[0003](../../decisions/0003-store-state-without-a-database.md) memory only,
[0008](../../decisions/0008-define-event-ordering.md) ordering,
[0034](../../decisions/0034-keep-the-last-session-state.md) no expiry,
[0035](../../decisions/0035-remove-the-unknown-session-state.md) no unknown state, latest event decides,
[0030](../../decisions/0030-keep-requests-visible-and-report-failures.md) failed turns.
