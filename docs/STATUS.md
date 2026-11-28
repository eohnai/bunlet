# Status

## Now

Bunlet 0.1.6 (build 7) is the Latest release, and the development Mac installed it through Sparkle on 2026-11-28.

Branch `fix/no-unknown-status` removes the Unknown session state
([0035](decisions/0035-remove-the-unknown-session-state.md)). The latest event decides a session's state, so a listed
session is working (blue hare), waiting for the user (orange), response ready (green) or failed (red). In 0.1.6, a
Claude Code session and a Codex session stayed Unknown through every later prompt. An interrupted turn left a request
open, and a new prompt was refused while a request was open.

The same branch removes the "stale" quota word ([0036](decisions/0036-keep-the-last-quota-reading.md)). A badge shows
its last reading in color, a failed read keeps it, a passed reset shows 100% left, and the badge stays after its
sessions leave the list. The branch is pull request #45. It passes its tests and is not checked on screen or released
yet.

Branch `fix/close-island-on-outside-click`, made from `fix/no-unknown-status`, closes the open island on any click
outside it and removes the **Done** button. Leaving the island now closes it after **Open Sessions** too. Before, any
keyboard focus counted as typing, so the island stayed open after the pointer left. It also reads Codex limits once
when Bunlet starts, so the Codex badge shows while a Codex session is open but quiet. It passes its tests and is not
checked on screen.

A Claude reading reached the quota badge on the development Mac on 2026-11-28 (`5h 62%`).

The user reports that session tracking works for Codex in ChatGPT and Claude Code in Claude Desktop.

## Next

1. Build `fix/close-island-on-outside-click` with `bash scripts/run.sh`. It includes `fix/no-unknown-status`. Check on
   screen: interrupt a turn with an open approval, send a new prompt, and confirm the row turns blue. Leave Claude
   quiet for over 5 minutes, and confirm the badge keeps its color with no "stale" word. With hover-to-open off, open
   the island, click outside it, and confirm it closes. Restart Bunlet with a quiet Codex session open, and confirm
   the Codex badge shows.
2. Merge #45, then the island branch, and release them as 0.1.7
   ([how](specs/settings/software-updates.md#release-a-version)).
3. Decide how to count Claude tokens without transcripts, then fix the undercount ([statistics](specs/telemetry/statistics.md)).
4. Check on screen: the token chip, short badge labels, the new session listing rules, and desktop alerts and return
   navigation.

## Known problems

- Claude token totals undercount ([statistics](specs/telemetry/statistics.md)). Codex has no token totals.
- Two tests fail intermittently when the full suite runs in parallel ([CI](specs/automation/ci.md#open-work)).
- `swift test` needs the Xcode toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. The Command Line
  Tools fail with `no such module 'Testing'`.
- Hook payloads for Claude `StopFailure` and subagents, Codex `PermissionRequest` replies and Cursor CLI follow the
  reference app's code and have not been checked against real runs.
- Many features have not been checked on screen. Each spec's **Open work** lists what remains.
