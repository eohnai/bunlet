---
summary: Clicking a session jumps to the pane or app it runs in. Navigation is optional and never needed for monitoring.
---

# Jump to a session's terminal

## How it works

The helper reports where the agent runs: a tmux, Otty, iTerm2, WezTerm or kitty pane when the environment identifies
one, an editor, or otherwise the nearest parent app bundle, found by walking up to 12 parent processes
([0025](../../decisions/0025-adopt-more-reference-behavior.md),
[0026](../../decisions/0026-any-agent-version-and-any-terminal.md)). Clicking a session jumps in this order:

1. The exact pane or window the hook reported.
2. An iTerm2 pane the user linked to that session by hand.
3. The app the agent reported running in.
4. The terminal app chosen in Settings.

For tmux, Bunlet selects the pane, then activates the app of the most recently active client showing that session.
iTerm2 panes are selected by session unique ID through AppleScript, WezTerm through `wezterm cli activate-pane`, kitty
through `kitten @ focus-window` (which needs kitty's remote control), and Otty through `otty-cli pane focus`. Apple
Terminal jumps need macOS Automation approval. Typed follow-ups work only for Otty and tmux panes at a finished turn.

## Requirements

- Monitoring, alerts, quota and pet reactions work without any terminal metadata or terminal app.
- Bunlet never launches an app or creates a pane as a fallback, and never reads terminal content or history.
- A user link is kept in memory under the exact session key and dropped when the session ends.
- A stale, conflicting or missing target fails closed. A timeout is reported as uncertain and is not retried.
- At most 128 links and one navigation worker with a 3-second deadline.

## Open work

- Check exact focus, duplicates, reused identities, denied Automation and timeouts in iTerm2, WezTerm and kitty. None
  is installed on the development Mac.
- Check app-only and manual return in other terminals with both agents.
- Run `otty-cli pane focus`, `send-text --from-file` and `send-keys key:Enter` against a real Otty.
- `scripts/check-event-contract.py` and `scripts/check-event-bridge.py` accept only Otty terminals. Update them.

## Decisions

[0012](../../decisions/0012-support-terminal-independent-operation.md),
[0025](../../decisions/0025-adopt-more-reference-behavior.md),
[0026](../../decisions/0026-any-agent-version-and-any-terminal.md).
