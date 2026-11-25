---
summary: Settings shows version, hook configuration, helper, receiver and last delivery as separate evidence per agent.
---

# Report integration health

## How it works

For each agent, Settings → Agents → Advanced shows separate values: the agent's version, whether Bunlet's hooks are
installed and match its record, whether the bundled helper is usable, the receiver's state and the time of the last
delivered event. There is no single connected flag. **Check** runs bounded, read-only probes for version, configuration
and helper. Receiver and delivery values come from the running app, so a probe never overwrites them.

## Requirements

- A running receiver or a successful helper run is not proof of delivery. Delivery is shown only after an event reaches
  the app.
- An empty session list or a quiet period is not reported as a broken integration.
- Delivery times come from the inbox, so they survive a session becoming unknown or ended.
- Probes never change configuration, run the helper or show file contents. Diagnostics contain no prompts, tool input,
  transcripts or credentials.
- Probes run only from an explicit Check or a setup operation, never in the background.

## Out of scope

- Installing and removing hooks: [codex-setup](codex-setup.md), [claude-setup](claude-setup.md).
- Quota receiver health: [usage/claude-allowance](../usage/claude-allowance.md).
- Whether replies to the agent are possible: lifecycle hooks do not prove it.

## Open work

- Check on screen that receiver and delivery values follow real bridge start, stop and receipt.
- `versionProbeBoundsItsProcessAndOutput` sometimes times out when the full suite runs in parallel.

## Decisions

[0004](../../decisions/0004-receive-agent-hook-events.md) hooks,
[0012](../../decisions/0012-support-terminal-independent-operation.md) navigation is not health.
