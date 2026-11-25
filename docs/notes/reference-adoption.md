# Reference island: behavior and what Bunlet adopted

This note describes the reference island well enough to plan work without the reference app. It records how the
reference behaves and how Bunlet compares. It is not a license review, and Bunlet copies no reference code, artwork or
text. [Reference UI](reference-ui.md) holds exact layout values, and [companion UI direction](companion-ui-direction.md)
holds the visual direction.

## Source

The inspected build is version `0.1.25`. Its `Contents/Resources/app.asar` has SHA-256
`25bf9e27fb025668d193f8323b5151bfbc37d62b2bd87bae8101cabf41f8e758`. Selected files were extracted with REA into a
scratch folder outside the repository and read as packaged source: `out/main/index.js`,
`out/renderer/assets/IslandPanel-DSRHjja3.js`, its stylesheet `IslandPanel-CgVhWn8Q.css`, and
`out/preload/chunks/ipc-EeO4Po2v.js`. Nothing was launched, and no configuration or credentials were read. Line numbers
below refer to that build and may change in later versions.

## How the reference works

**Agents and setup.** A coordinator registers one setup manager per agent: 14 built-in ones (including Claude, Codex,
Cursor, OpenCode, Kimi, Gemini, Copilot CLI and Hermes), plus plugin and custom agents (`hookManagers`,
`index.js:58935`). Each manager installs, checks and removes its own hooks. A generic adapter accepts hook-shaped events
from registered custom agents, but registration alone gives no replies, quota or navigation. Settings lists one row per
agent with a status dot and a switch. The reference reinstalls its hooks on every launch.

**Session list.** `isVisibleInIsland` (`IslandPanel-DSRHjja3.js:6`) always shows a session waiting for approval or an
answer. It hides child sessions, hides a hook-tracked session once it ends, and shows a hook-tracked Claude or Codex
session only after it has a user prompt. There is no unknown state. A sweep (`index.js:60900`) deletes sessions that
fail that filter, then any session not updated within `idleAutoCollapseMsecs`, 7 days by default, whatever its phase.
Rows show a phase icon, agent badge, title, terminal app, an elapsed timer from session creation, the latest prompt,
and current activity or the last reply. Hovering a row shows a delete button, and the top row has a clear-all button.

**Requests.** An approval card shows the tool name, details and, where supplied, a diff. Bridge-handled requests offer
deny and allow once. A persistent "allow always" appears only with permission suggestions. Terminal-native and cloud
modes send the user back to the owning interface. The question card supports several questions, single or multiple
choice, and custom text for some agents. Follow-up text works only for completed Claude or Codex sessions with a tmux,
iTerm or Apple Terminal target.

**Quota and tokens.** Codex quota comes from an App Server connection with retries and update notifications
(`QuotaService`, `index.js:47476`). Claude quota comes from a bash wrapper around the user's status line
(`buildStatusLineScript`, `index.js:41429`). The wrapper saves `.rate_limits` to a cache file with `jq`, then runs the
original command. `loadClaudeQuota` (`index.js:47104`) reads that file and accepts `used_percentage` or `utilization`.
Token statistics come from reading transcripts: `collectTokenUsage` (`index.js:30443`) sums per-message usage for
Claude, Codex, Cursor and OpenCode, and `applyBaselineDiff` (`index.js:30908`) records only the growth per session.

**Quota badges.** `AgentQuotaCell` (`IslandPanel-DSRHjja3.js:245`) shows the logo and one window, 5-hour if valid,
else 7-day, with percent used colored red from 80, yellow from 50 and green below. A badge with no valid window shows
only the logo. The badge row can grow under the notch, because nothing measures the cutout. Today's token count sits on
the right with the panel buttons, and clicking it opens Statistics.

**Other behavior.** A completion does not open the panel while another session waits on a request
(`hasBlockingSession`, `index.js:60815`), and interrupts, session ends and loop iterations never open it. Focus
suppression applies per session, matching its host app and, when known, its tab. A status hint in the panel's top row
opens the matching Settings tab when a connection breaks. Sounds play from a user folder seeded with defaults. There is
a first-launch welcome window, a hidden debug window that plays scenarios, and an interface language switch.

**Pet.** The pet has its own window. Entering pet mode hides the island, and dropping the pet over the island's
location restores it. Artwork is a PNG with seven rows (idle, play, sleep, running, attention, complete, drag) of
square cells. A user PNG overrides the bundled one.

**Not for Bunlet.** Sign-in services, cloud agents, Feishu notifications, telemetry upload, forced updates, remote SSH
hosts, completion guessed from transcripts or process checks after 120 to 180 seconds of silence, and restoring old
sessions at startup.

## How Bunlet compares

| Behavior | Bunlet | Notes |
| --- | --- | --- |
| One switch per agent, automatic setup and repair | Adopted | [0023](../decisions/0023-connect-agents-automatically.md), [0024](../decisions/0024-repair-hooks-and-connect-quota-at-launch.md). Codex hook review is kept. |
| Session listing rules and 7-day sweep | Adopted, except that waiting requests are never removed | [0032](../decisions/0032-list-sessions-like-the-reference.md). Bunlet keeps an unknown state. |
| Delete one row, clear all | Adopted | [0030](../decisions/0030-keep-requests-visible-and-report-failures.md) |
| Completion waits behind requests, per-session focus check | Adopted, app-level only | 0030 |
| Claude failed-turn sound | Adopted | 0030 |
| Allow once, deny, allow always, answers, follow-ups | Adopted through verified channels | [Local responses](../specs/actions/local-responses.md). Typed follow-ups only for Otty and tmux. |
| Status-line wrapper for Claude quota | Adopted, as a native helper | Bunlet reads only `used_percentage` and recovers when another app replaces the wrapper ([0031](../decisions/0031-recover-a-replaced-claude-status-line.md)). |
| Quota badges | Adopted with differences | Bunlet shows percent left by default, a stale marker and "unavailable", fits each side of the notch, and moved today's tokens to the right. |
| Token counts from transcripts | Not adopted | Bunlet reads the status line instead ([0019](../decisions/0019-show-prompt-and-reply-previews.md)), which currently undercounts. |
| Pet mode, seven-row sprite sheets | Adopted | [0020](../decisions/0020-one-app-with-pet-mode.md), [custom artwork](../specs/pets/custom-artwork.md) |
| Elapsed timer | Different | Bunlet times the current prompt, not the whole session. |
| Status hint, replaceable sounds, welcome window, debug scenarios, language switch | Not decided | Candidates. The debug window would make on-screen checks easier. |
| Skipping auto-open for interrupts | Not checked | Unknown whether an interrupt reaches Bunlet as a completion. |
