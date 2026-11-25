---
summary: Bunlet stays cheap at idle on a 16 GB M2 MacBook Air. Its budgets are proposed and not yet measured.
---

# Resource efficiency

## How it works

Low idle energy use is a release requirement ([D1](../../DECISIONS.md#d1-make-low-idle-energy-use-a-release-requirement)).
The event receiver waits on socket readiness and native notifications rather than polling. The inbox and session store
have capacity limits. Codex quota is read only while Codex is relevant, with retries after 5, 15, 30, 60 and 120
seconds and a 120-second loop while active. Hidden or sleeping surfaces stop their animation and countdown timers.

## Requirements

- With no sessions and no user action, nothing wakes up to check for work.
- A static pet pose schedules no animation tick. Optional animation is capped at 30 fps and stops when not visible.
- Reduce Motion shows a stable pose. Low Power Mode reduces optional motion.
- Queues, image resources and buffers have explicit bounds. Artwork is decoded once.
- Quota reads are shared per agent and account, never repeated per session or surface, and never overlap.
- A failed refresh shows stale or unavailable, never a guess. Reset times alone are not fresh usage.
- Sleep takes no keep-awake assertion. Wake does not replay history or fire a burst of catch-up requests.
- Hooks do no network upload, database scan or wait for an approval decision.

## Proposed budgets

These are targets to review against a first measurement, not results.

- Five-minute idle mean CPU below 1% of one core, across the app and its own processes.
- Warm idle memory at most 200 MiB combined.
- No steady growth in memory, queues, threads or descriptors over a 30-minute fixed workload.

## Open work

- Capture a release-build baseline on the M2 Air and review the budgets.
- Remove any idle timers or rendering the baseline finds, and check Low Power Mode.
- Profile idle, visible animation, hidden surfaces, active agents, failures and event bursts, then repeat the
  30-minute growth check.
