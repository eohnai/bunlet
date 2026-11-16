# 0024: Repair drifted hooks and connect Claude quota forwarding at launch

- Status: accepted
- Date: 2026-11-16

## Context

[0023](0023-connect-agents-automatically.md) added hooks at launch only when an agent had none. The reference island reinstalls its hooks
on every launch, which also repairs edits, and manages Claude's status-line wrapper for usage limits. The user asked for that parity
and said local responses stay manual.

## Decision

At launch, for each agent that is on, after the single setup check:

- **Lifecycle hooks:** run connect when Bunlet's entries are absent or recorded as owned. Connect on owned entries repairs drift and
  changes nothing when they already match. Conflicts, unfinished recoveries, a missing agent and unqualified versions are left alone.
- **Claude quota forwarding:** once the lifecycle hooks are owned, check and connect or repair the status-line wrapper, which keeps
  the existing status line's output. Removing quota forwarding by hand turns this off until you connect it again by hand.
- **Local responses (Allow, Deny, answers):** never automatic. They stay a manual connect with their own consent.

## Consequences

Each launch may run one more setup check per agent than 0023. Removing owned hooks or quota forwarding by hand still sticks across launches.
Nothing was run against a real installation.
