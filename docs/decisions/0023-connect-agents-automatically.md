# 0023: Turn agents on and add their hooks at launch

- Status: accepted
- Date: 2026-11-16

## Context

Claude Code and Codex started off. Each needed a switch and a confirmation before Bunlet added hooks to the agent's settings.
The reference island enables every agent by default and reinstalls its hooks on each launch without asking.
The user chose the fully automatic behavior.

## Decision

- Both agents start on. A saved per-agent choice, and an earlier saved global off choice, still apply.
- At launch, for each agent that is on, Bunlet checks its setup once. If the agent is found and none of Bunlet's hooks are present,
  Bunlet connects it without a prompt. Other hooks are kept, as with a manual connect.
- Bunlet does not touch an agent that is already connected, missing, in conflict, unqualified, or mid-recovery. Settings → Agents
  shows the reason as before.
- Turning an agent off, Disconnect, Remove owned hooks and Remove all hook configuration pause the agent, so the next launch does not
  add the hooks back.
- Bunlet still does not bypass Codex's hook review. Codex may ask you to review the new hook.

## Consequences

This supersedes the confirmation step in [0021](0021-settings-scope.md). The confirmation stays for connecting by hand
after you have paused an agent. Nothing was run against a real agent installation.
