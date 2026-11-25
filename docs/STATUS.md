# Status

## Now

Bunlet 0.1.4 (build 5) is the Latest GitHub release, tagged on `9bae7f6`, the same commit as `main`. The public
update feed serves it, and it is installed on this Mac. The user reports that desktop session tracking worked for both
local Codex in ChatGPT and local Claude Code in Claude Desktop. Decisions 0025–0030 are on `main`; their remaining live
acceptance is listed in Blockers.

The quota badges can run under the camera notch: one screenshot showed about 527 px of content for 483 px of space.
The approved fix is on branch `fix/usage-badges-beside-notch`, uncommitted. Each side of the notch gets a fixed width,
and the badges switch to shorter labels when the full ones do not fit; hover keeps the full details. It compiles, and
the full suite passed (283 tests, including a new layout test). On 2026-11-25 the user ran a development build on this
MacBook and confirmed that the full labels (`5h unavailable | 7d 87% 3h37m`) now sit beside the notch. The short-label
form was not seen on screen. Running that build left the Claude, Codex and Cursor hooks pointing at the installed app.

A comparison with the reference island on 2026-11-25 is recorded in
[reference adoption](notes/reference-adoption.md#usage-visibility-and-sweep-follow-up-2026-11-25), on the same branch.

## Next

1. Review and merge the quota-badge PR.
2. Diagnose Claude quota delivery: **Settings → Agents → Advanced → Setup → Claude Code → Usage forwarding → Check quota**.
   It should report a conflict or missing forwarding (see Blockers). Decide how Bunlet should treat another app's
   status-line wrapper.
3. Decide: whether old Unknown rows leave the list (keeping any outstanding request), and how to count Claude tokens
   without transcripts (needs a decision record against 0019). The user approved moving the token chip to the
   right-hand buttons on 2026-11-25; it is part of the quota-badge PR.
4. Verify desktop alerts and return navigation as described in the [desktop spec](specs/sessions/desktop-coding-sessions.md).
5. When separately authorized, check the deferred Settings, fullscreen and shortcut interactions on screen.
6. Decide whether to update the superseded pet and feature-management specs.

## Blockers

- Claude quota does not arrive. Claude Code CLI shows `5h unavailable`, and after a completed reply **Last quota receipt**
  still says **Not observed**. On 2026-11-25, `statusLine` in `~/.claude/settings.json` was another app's wrapper, and
  Bunlet's `NotchPetStatusLine` appeared nowhere in Claude's settings, so the forwarder never runs. Why Bunlet did not
  wrap it is unconfirmed: the planner leaves the status line alone when its ownership record no longer matches the file,
  which happens if another app rewrites it after Bunlet. The forwarder sends a reading even when Claude omits
  `rate_limits`, which Claude sends only to Pro, Max and Ultra subscribers, after the first response.
- Claude token totals undercount. `TokenLedger` subtracts successive status-line `context_window` totals, but Claude
  documents them as counts from the most recent response, not session totals. Codex token totals are not implemented.
- Unknown sessions stay listed. `NotchPresentation.withoutStale` hides only Idle and Ended sessions, and a provider's
  quota badge disappears when its only sessions are Unknown or Ended.
- Bunlet 0.1.2 crashes at launch, so its users cannot reach **Check for Updates**. They must download 0.1.3 by hand.
- The full suite fails intermittently. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path <fresh directory>`
  failed 2 of 282: `versionProbeBoundsItsProcessAndOutput(agent: .codex)` got `.timedOut` instead of `.nonzeroExit`
  (`IntegrationHealthTests.swift:119`), and `waitsForDesktopRuntimeAndHonorsPause(.claude, pauseBeforeInstall: true)` failed `ready()`
  (`AgentDefaultsTests.swift:98`). Both passed twice in a filtered run, so they are timing-sensitive under parallel load.
- The repository's `.build` folder is stale from the `notch-pet` rename. `swift build` fails with `PCH was compiled with module cache path
  '/Users/ianhoe/Projects/notch-pet/.build/...'`. Delete `.build` or pass a fresh `--scratch-path`.
- The default Command Line Tools toolchain fails `swift test` with `no such module 'Testing'`. Set
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Decision 0030 unverified: Claude Code's `StopFailure` payload (its `prompt_id` in particular) was not checked against a
  real failed turn. Without a turn identity the failure is ignored and the session keeps working until it expires.
- Decision 0026 unverified: the parent-process walk, the tmux `list-clients` lookup and the iTerm2, WezTerm and kitty
  pane commands were checked only with fictional data; none of those three terminals is installed here. Codex 0.169.0
  and Claude Code 2.1.318 now connect as untested versions; their hook payloads were not checked against a real run.
- Decision 0025 unverified: Claude's `SubagentStart`/`SubagentStop` and status-line `context_window` totals, Codex's
  `PermissionRequest` reply and Cursor CLI's hook payload fields (`conversation_id`, `generation_id`) follow the reference
  island's packaged code, not a run against the installed agents. `otty-cli pane focus`/`send-text --from-file`/`send-keys key:Enter`
  match Otty 1.6.2's help text but were not run. Apple Terminal jumps need macOS Automation approval.
- Stale: `scripts/check-event-contract.py` and `scripts/check-event-bridge.py` still accept only `kind: "otty"` terminals.
- Stale: `scripts/check-event-contract.py` permits a previously conflicting turn ID to restore working state; SessionStore enforces the accepted unseen-turn rule.
- Stale: `docs/specs/settings/feature-management.md` (FM1–FM7) and `docs/specs/pets/*.md` describe installable features and pet-only use; decision 0020 removed both.
- Runtime-qualified provider registry remains empty. Documented setup accepts any well-formed version above the decision 0026 floors without bypassing normal trust/policy; real install/reinstall/recovery/removal and stream-preservation acceptance remain unverified.
- Claude actions provide explicit permission decisions, structured answers and a ≤60-second existing Stop-hook feedback window. Codex actions and arbitrary-time follow-ups remain unsupported. Hosted compilation/tests do not establish provider action acceptance.
- Terminal-independent monitoring is implemented. Exact-pane navigation uses hook-reported terminal identity (decisions 0025, 0026), with user-linked iTerm2 and the chosen app as fallbacks. Native Automation/focus/display/Space/sleep/drag/import acceptance remains deferred.
- Earlier hosted runs recorded compiler failures and process/socket timeouts. Intermittent cases are not proven eliminated. Preserve the failures and fixes in `docs/goals/full-mvp-implementation-log.md`.
- Feature task lists retain original verification-bearing checkboxes. Missing retrospective specs and future roadmap entries do not mean the merged code is absent. No dates/owners are assigned.
- Telemetry/statistics, launch-at-login/language preferences, automatic attention/haptics, SSH/cloud and additional agents remain outside the delivered nine-area MVP.
- CI foundation F8b deliberate hosted drills and separate historical CI-branch integration are not completed. Do not resume them automatically.
- Telemetry planning conflict: `origin/docs/local-telemetry` records a history-first decision superseding collector-first D2, but this checkout retains the old order. Its D3 identifier collides with this branch's view-model D3. Reconcile decisions and links without dropping later statistics scope or marking withdrawn tasks complete.
- FM7 is deferred by the user. The last native command was `python3 scripts/check-feature-management.py --app '/private/tmp/notch-pet-features/notch-pet-dev/Notch Pet.app' --artifacts /private/tmp/np-features-native-final`: all eight startup sets and fresh setup passed; recovery/interaction failed `explicit Settings focus`, and reopen failed `launch choices` after interaction stopped. Do not restart it automatically.
- Capture reproduction command: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/check-standalone-pet.py --app "/private/var/folders/t3/6n_zw1rn5nn6vv7ccx9r6s240000gn/T/notch-pet-dev/Notch Pet.app" --artifacts /private/tmp/notch-pet-completion/evidence/standalone` failed with `could not create image from window` / screencapture exit 1. The user prohibited further captures and testing. Do not request that permission or retry the failing capture.
- Unverified on screen: the closed island now extends up to 1 pt below the notch safe area toward the menu bar
  (32 to 33 pt on the 13-inch MacBook Air) to hide a step where the cutout meets the wings. The step was seen only in a
  photo. The M4 16-inch MacBook Pro's notch and menu bar heights were not measured. With an auto-hidden menu bar the
  height stays at the safe area, and the step may return.
- Unverified on screen: the redesigned island, Settings and pet panel were built and unit-tested only. SwiftUI hover in the nonactivating panels and the pill drag-out need a real-display check.
- Unverified: launch at login (`SMAppService`) may be refused for the dev build in TMPDIR; Settings shows the reason if so.
