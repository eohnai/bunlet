# 0030: Keep requests visible, quiet only for the session's app, report failed turns, and let users remove rows

- Status: accepted
- Date: 2026-11-24
- Amends: [0021](0021-settings-scope.md), [0022](0022-close-reference-settings-gaps.md),
  [0025](0025-adopt-more-reference-behavior.md)

## Context

A feature sweep of the installed reference island (0.1.25, unchanged archive hash) on 2026-11-24 found behaviors with no
Bunlet counterpart. The [reference note](../notes/reference-adoption.md#feature-sweep-for-undocumented-behavior-2026-11-24)
records them. The user approved four of them on the same day.

## Decision

1. **A completion does not cover a waiting request.** A completion opens the island only when no other listed session
   is waiting for an approval or an answer. Its sound still plays and its row still updates. Requests still open the island.
2. **Focus-aware suppression is per session.** It hides a notification only when the frontmost app is the app that
   session runs in, taken from its terminal hint: the terminal kind's app, tmux's outer terminal, or the editor or app
   bundle identifier. When that app is unknown, the previous rule applies: any known terminal or editor in front.
   Matching the exact window or tab is not included, because most terminals need macOS Automation approval for it.
3. **Claude Code failed turns.** Bunlet installs Claude's `StopFailure` hook with its other Claude lifecycle hooks;
   owned installations gain it through the existing launch repair (0024). A failure ends the turn like `Stop`, and the
   session shows a **Failed** label until its next turn. A new **Task fails** sound (macOS "Basso", on by default) plays
   instead of the completion sound, and the notification follows the completion rules. Error text is not forwarded.
   Codex reports no failure hook. Cursor's stop status would need a new envelope field, so neither is included.
4. **Remove sessions from the island.** Hovering a row shows a remove button; the panel's top row has **Clear all**.
   Both are keyboard accessible. Removal hides the row in Bunlet only. Session tracking is unchanged, and a removed
   session returns when it reports new activity.

## Consequences

`StopFailure`'s payload follows the reference's packaged code, not a run against the installed Claude Code, as with
the subagent hooks in 0025. Removal does not stop an agent or answer its request: a hidden session waiting for a reply
still holds that request until it reappears. On-screen behavior of the new controls remains unverified.
