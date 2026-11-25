---
summary: Each agent has its own switch that pauses or resumes monitoring without losing pending requests.
---

# Per-agent monitoring

## How it works

`ProviderMonitoringModel` saves one on or off choice per agent. Turning an agent off pauses it: its live sessions lose
confirmation, pending requests stay as unconfirmed, ended sessions are kept, and its quota reads stop at once. Events
from a paused agent are dropped before they reach the session store. Other agents keep running.

Turning an agent back on sets fresh receipt cutoffs, so queued events from before the pause or before sleep cannot
restore a session. Resuming never implies working, completion, approval or a resolved request.

Disconnect pauses first, then removes owned hooks after its own confirmation. An uncertain or partial removal stays
paused and needs an explicit Check. Opening Settings only reads state. It never runs Check, changes hooks or starts
monitoring.

## Requirements

- A saved choice per agent wins over the default. A failed or malformed preference write fails closed.
- Quota intake has its own generation, so a stopped receiver's queued readings cannot leak through.

## Open work

- Check per-agent pause and resume with concurrent sessions, and that stale evidence cannot come back.
- Check cancellation, queued delivery, sleep and clock boundaries, and failed preference writes.
- Check Disconnect with a missing CLI, partial removal, conflicts and journal recovery.

## Decisions

[0023](../../decisions/0023-connect-agents-automatically.md),
[0029](../../decisions/0029-automate-desktop-agent-setup.md).
