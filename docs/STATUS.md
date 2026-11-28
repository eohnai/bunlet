# Status

## Now

Bunlet 0.1.7 is the Latest release (2026-11-28). It includes #45 (no Unknown session state
[0035](decisions/0035-remove-the-unknown-session-state.md), no "stale" quota word
[0036](decisions/0036-keep-the-last-quota-reading.md)) and #46 (the island closes on an outside click, and Codex limits
are read once at start).

Branch `fix/island-width-for-countdown` makes the open island 10 points wider on each side (700 to 724 points, window
760) and halves the gap between the quota badges. Two full badges with countdowns now fit beside the notch on the
development MacBook Air ([session island](specs/notch/session-island.md#decisions)). Before, the countdowns were dropped.
The user checked the countdowns on screen. The branch is not committed.

The user reports that session tracking works for Codex in ChatGPT and Claude Code in Claude Desktop.

## Next

1. Commit `fix/island-width-for-countdown`, open its pull request, and check on screen that clicks just outside the
   open island's edges reach the app underneath.
2. Decide how to count Claude tokens without transcripts, then fix the undercount ([statistics](specs/telemetry/statistics.md)).
3. Check 0.1.7 on screen: interrupt a turn with an open approval and send a new prompt (the row turns blue), leave
   Claude quiet for over 5 minutes (the badge keeps its color), click outside the island with hover-to-open off (it
   closes), and restart Bunlet with a quiet Codex session open (the Codex badge shows).
4. Check on screen: the token chip, short badge labels, the new session listing rules, and desktop alerts and return
   navigation.

## Known problems

- Claude token totals undercount ([statistics](specs/telemetry/statistics.md)). Codex has no token totals.
- Three tests fail intermittently when the full suite runs in parallel on a busy machine
  ([CI](specs/automation/ci.md#open-work)).
- `swift test` and `bash scripts/run.sh` need the Xcode toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
  The Command Line Tools fail with `no such module 'Testing'`. Both toolchains share the `notch-pet-dev` build folder,
  so a Command Line Tools build after an Xcode build fails with `module compiled with Swift 6.3.2 cannot be imported
  by the Swift 6.2.3 compiler`.
- Tests leave `bunlet-agent-defaults-<UUID>` preference domains on the development Mac. They are not removed after the
  run.
- Stale: `specs/sessions/session-state.md:10` is a wrapped prose line that starts with `status:`, so the progress board
  reads it as the spec's status.
- Hook payloads for Claude `StopFailure` and subagents, Codex `PermissionRequest` replies and Cursor CLI follow the
  reference app's code and have not been checked against real runs.
- Many features have not been checked on screen. Each spec's **Open work** lists what remains.
