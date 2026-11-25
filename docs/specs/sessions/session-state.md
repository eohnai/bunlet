---
summary: One in-memory store turns events into per-session state, keeping requests, completions and unknown state apart.
---

# Track agent session state

## How it works

`SessionStore` receives events from the inbox and keeps one record per agent and session ID. Each session has a
status: idle, working, question needed, approval needed, response ready, unknown or ended. Turns are correlated by turn
ID, and pending requests are tracked by request identity. Previews, the current tool, running subagents and the
reported terminal are display-only extras. State lives in memory only, so after a restart sessions need fresh events.

A session becomes unknown, with a reason, when the evidence conflicts or stops: an event ID conflict, overlapping turns,
a reused session ID, a missing turn identity, capture-order ambiguity, capacity limits, or paused monitoring. A session
that goes quiet past its freshness deadline also becomes unknown. Unknown sessions keep their requests, marked as
unconfirmed.

## Requirements

- Concurrent sessions stay distinct, including two in the same project folder.
- A finished response produces a response-ready state. It never claims the task succeeded.
- Unknown and ended stay distinct from working and response ready.
- Sleep, wake and clock changes cannot let older events restore fresh state.
- The store follows decision 0008's ordering and the contract's limits, including at most 128 sessions.
- The store alone classifies requests, orders events and judges freshness. Adapters and views do not repeat these rules.

## Out of scope

- Which sessions the island lists and in what order: [notch/session-island](../notch/session-island.md).
- Delivery health: [integration-health](integration-health.md).
- Transcript parsing and process-liveness guesses.

## Open work

- `scripts/check-event-contract.py` lets a previously conflicting turn ID restore working state, but the store follows the
  stricter rule. Correct the script.
- Codex reports no interrupt event, so an approval can stay listed after the user interrupts. This is a known limit of
  the contract.

## Decisions

[0003](../../decisions/0003-store-state-without-a-database.md) memory only,
[0008](../../decisions/0008-define-event-ordering.md) ordering,
[0030](../../decisions/0030-keep-requests-visible-and-report-failures.md) failed turns.
