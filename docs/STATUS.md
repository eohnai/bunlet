# Status

## Now

Bunlet 0.1.4 (build 5) is the Latest release. A local 0.1.5 build of `main` is installed on the development Mac.
`main` has later changes that are not released yet:

- Quota badges stay beside the notch, and today's tokens moved to the right of the top row (PR 40).
- A Claude status line replaced by another app no longer blocks quota forwarding (PR 41).
- The island lists sessions by the reference island's rules (PR 42).
- Sessions keep their last state instead of turning Unknown after 2 minutes without events
  ([0034](decisions/0034-keep-the-last-session-state.md)). Waking the Mac still makes open sessions Unknown.
- The pet panel, the pet's mood and the switch-session shortcut use the island's session list. The panel buttons
  stay at the right edge when no quota badge shows. The user checked both on screen on 2026-11-28.

Claude quota forwarding is not connected on the development Mac. `~/.claude/settings.json` has no `statusLine` and
Bunlet has no quota record, so the Claude badge reads "unavailable". A Claude reading has not been seen in the badge yet.

The user reports that session tracking works for Codex in ChatGPT and Claude Code in Claude Desktop.

## Next

1. Choose Settings → Agents → Claude Code → **Connect quota…**, send a Claude Code prompt in a terminal, and check
   that the Claude badge shows a reading. Claude sends limits only to Pro, Max and Ultra subscribers.
2. Release the changes on `main` as 0.1.5 ([how](specs/settings/software-updates.md#release-a-version)).
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
