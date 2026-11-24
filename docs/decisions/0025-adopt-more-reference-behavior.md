# 0025: Adopt more of the reference island's behavior

- Status: accepted
- Date: 2026-11-16
- Amends: [0010](0010-add-local-agent-actions.md), [0017](0017-match-reference-island-ui.md),
  [0019](0019-show-prompt-and-reply-previews.md), [0021](0021-settings-scope.md), [0022](0022-close-reference-settings-gaps.md)

## Context

On 2026-11-16 the user compared Bunlet with the installed reference island (0.1.25, unchanged archive hash) and approved
seven changes. This Mac has Claude Code 2.1.318, Codex 0.169.0, Cursor CLI, Cursor and Otty installed; iTerm2 is not installed.
The reference has no Otty adapter. Otty 1.6.2 exposes `OTTY_PANE_ID` to programs in a pane and an `otty-cli` with
`pane focus`, `pane send-text` and `pane send-keys`.

## Decision

1. **Open on session end** defaults to on, as in the reference. A session that ends (SessionEnd) never opens the panel.
   The reference's separate 4-second auto-collapse setting is not adopted: the reference never reads it, and its real
   timer is the completion popup duration, which Bunlet's reminder duration already matches.
2. **Jump to terminal** uses terminal identity forwarded by the observer hook: Otty pane (`otty-cli pane focus`),
   tmux pane (`tmux select-window`/`select-pane`), Apple Terminal tab (by tty), and the Cursor or VS Code window
   for the project folder. The manually linked iTerm2 pane and the chosen application remain fallbacks.
3. **Follow-ups typed into the terminal.** This reverses the "never type into a terminal" rule of 0010 and 0017.
   Bunlet sends text only to an exact pane it can address without focus (an Otty pane or a tmux pane), as one line
   followed by Return, only when the session's last observed state is a finished turn or a fresh session with no
   pending request, and only on an explicit Send. It never types into whichever window is in front, so Apple Terminal,
   editor terminals and iTerm2 (not installed on this Mac) get no follow-up.
   Claude's existing Stop-hook reply stays the first choice while it is available.
4. **Codex approvals in the island.** A per-agent "Approve in" setting (Terminal by default, or Bunlet) for Codex.
   Choosing Bunlet connects a Codex `PermissionRequest` action hook that waits for Allow once or Deny, using the reply
   format Codex shares with Claude. There is no Always allow for Codex. Terminal removes that hook.
5. **Subagents.** Claude's `SubagentStart` and `SubagentStop` hooks are observed and shown as a count under the parent
   session ("2 subagents running"). Subagents do not get their own rows. Codex has no subagent hooks.
6. **Token counts and statistics** from the Claude status line Bunlet already wraps (`context_window` totals per session).
   Transcripts stay unread (0019). Codex reports no token totals through hooks or Bunlet's App Server reads,
   so Codex shows none. Daily totals are kept in preferences for 90 days. The pill can show today's tokens;
   Settings gets a Statistics page. Skill update and upgrade buttons are not built.
7. **Cursor CLI** becomes a third supported agent with observation only: sessions, prompts, tools and stops through
   `~/.cursor/hooks.json`. It has no local actions, usage limits, subagents or reply previews. Like the other two,
   it starts on and is connected at launch (0023), and its documented binding is the installed build
   `2026.09.18-9a7762b`. Bunlet's helper prints nothing back, so Cursor's own permission prompts are unchanged.

## Consequences

The observation envelope gains a `terminal` object with more kinds and an optional `agent_id` for subagent events.
The lifecycle hook set changes for Claude (two more events) and Cursor (its own event names); existing owned Claude
hooks are upgraded in place by the launch repair from 0024. Typing into a pane can still reach the wrong program if the
user started something else in that pane after the agent stopped; Bunlet checks only its own last observation.
Nothing here was run against a real agent, terminal or editor.
