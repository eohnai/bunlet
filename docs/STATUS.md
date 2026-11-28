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
sessions leave the list. The branch passes its tests. It is not checked on screen or released yet.

Claude quota forwarding is not connected on the development Mac. `~/.claude/settings.json` has no `statusLine` and
Bunlet has no quota record, so the Claude badge reads "unavailable". A Claude reading has not been seen in the badge yet.

The user reports that session tracking works for Codex in ChatGPT and Claude Code in Claude Desktop.

## Next

1. Build `fix/no-unknown-status` with `bash scripts/run.sh` and check on screen: interrupt a turn with an open
   approval, send a new prompt, and confirm the row turns blue. Leave Claude quiet for over 5 minutes, and confirm the
   badge keeps its color with no "stale" word. Then merge it and release it as 0.1.7
   ([how](specs/settings/software-updates.md#release-a-version)).
2. Choose Settings → Agents → Claude Code → **Connect quota…**, send a Claude Code prompt in a terminal, and check
   that the Claude badge shows a reading. Claude sends limits only to Pro, Max and Ultra subscribers.
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
