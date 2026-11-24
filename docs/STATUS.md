# Status

## Now

Uncommitted: **Package Bunlet release** gains a **Run workflow** button with a version field. A manual run builds `main`
and creates the release tag through the API after the build and signature checks pass. Tag pushes still work. The YAML
parses, each step passes `bash -n`, and the version and tag checks were simulated locally. actionlint was not run locally,
and a manual run has not happened on GitHub yet.

Released Bunlet 0.1.2 traps at launch on any Mac but the build runner. SwiftPM's `Bundle.module` looks beside the
`.app` and at the runner's absolute build path, but packaging puts resource bundles in `Contents/Resources`. PR #37 (merged):
`AppResourceDirectory` resolves the pet artwork and provider logos from the app's own `Contents/Resources` (missing
artwork returns nil instead of trapping), and `package-update.py` refuses an app without both bundles. Fixture-app tests
cover the release layout. A fixed release (0.1.3) still needs a tag, and 0.1.2 users must download it manually because
0.1.2 cannot launch to check for updates. The fixed app was not launched from a packaged build.

Decision 0030, uncommitted, adopts four behaviors from the 2026-11-24 reference sweep: a completion no longer opens the
island while another session waits for the user; focus-aware suppression checks the session's own app; Claude's
`StopFailure` hook ends a failed turn with a **Failed** label and a new Task fails sound (on by default, existing users
included); and rows can be removed one at a time or all at once until they report new activity. All 279 Swift tests passed.
`StopFailure`'s payload follows the reference's packaged code, not a real Claude failure, and the new controls were not checked on screen.

Decision 0028 adds **Settings → About → Check for Updates** to Sparkle-enabled packages. Bunlet 0.1.1 (build 2)
is published on GitHub Releases with the signed appcast. Both public downloads matched the original signed artifacts.
The release script builds
an ad-hoc-signed, relocatable Apple silicon ZIP and signed appcast. A loopback test used Bunlet's check action and Sparkle's
standard installation controls to update build 9001 to 9002. The new process read the saved preferences at the same app
path and all three fixture hook files stayed byte-identical. The 266 Swift tests passed with and without Sparkle.

Decision 0029 makes the agent switches start setup directly. Bunlet also waits for a missing enabled desktop runtime
and connects when it appears. Approval preferences, repair, and removal are under Advanced. The rabbit menu contains Settings and Quit Bunlet. Display settings own
pet and notch recovery. The Codex version, policy and quota probes can run an npm launcher with its sibling Node
when started from Finder. All 266 Swift tests passed. A separate minimal-PATH run installed fixture hooks for the
actual Codex, Claude Code and Cursor CLI executables without using their active configuration.

Decision 0027 adds local ChatGPT and Claude desktop coding sessions. Bunlet locates their coding runtimes,
installs the same owned lifecycle hooks as for terminal sessions, and can request an exact Codex thread or
activate Claude. The release app installed both sets of hooks without standalone CLI tools in a disposable profile,
kept existing fixture hooks and Claude status-line output, and repeated launch without changing the settings.
An ad-hoc-signed arm64 package was built and verified after extraction.
The user subsequently reported that both desktop apps now work with Bunlet.

The notch and session rows use a blue working hare, orange input-needed hare, and green completed hare. The
collapsed notch aligns the hare artwork with the session count's side inset. The Swift suite passed. On-screen
alignment remains unverified.

`feat/reference-gaps-settings` closes the Claude Code and Codex settings gaps found by comparing with the reference island, and
reorganizes Settings (decision 0022): always allow, rebindable shortcuts, visibility options, idle-session clean-up,
percent used or left, and a launch sound. Claude Code and Codex now start on and connect at launch without a prompt, repair drifted hooks, and connect Claude quota forwarding (decisions 0023, 0024). Local responses stay manual. Settings is now one file per page.

Uncommitted on the same branch, decision 0025 adopts seven more reference behaviors: open on session end by default;
jump to the reported Otty pane, tmux pane, Terminal tab or Cursor/VS Code window; one-line follow-ups typed into an
Otty or tmux pane; Codex "Approve in Terminal/Bunlet"; Claude subagent counts; Claude token counts with a Statistics
page; and Cursor CLI as a third, observation-only agent. Owned Claude hooks from the seven-event set upgrade in place.
Decision 0026, also uncommitted, drops the exact-version setup bindings (any well-formed version; Codex needs 0.129.0
or newer; untested versions are labelled) and makes jumping work in any terminal: exact panes for iTerm2, WezTerm and kitty
too, the app the agent runs in otherwise (found by walking parent processes), and the terminal showing a tmux session.
Historical source work remains uncommitted on this branch. Live provider turns and visible notification behavior remain unverified.

## Next

1. Verify desktop alerts and return navigation as described in the [desktop spec](specs/sessions/desktop-coding-sessions.md).
2. Install the update-enabled release on the personal MacBook and check the [hosted feed](specs/settings/software-updates.md) from About.
3. Review decisions 0025–0030 and the branch before committing or opening a review.
4. When separately authorized, check the deferred Settings, fullscreen and shortcut interactions on screen.
5. Decide whether to update the superseded pet and feature-management specs.

## Blockers

- Decision 0030 unverified: Claude Code's `StopFailure` payload (its `prompt_id` in particular) was not checked against a
  real failed turn. Without a turn identity the failure is ignored and the session keeps working until it expires.
- Decision 0026 unverified: the parent-process walk, the tmux `list-clients` lookup and the iTerm2, WezTerm and kitty
  pane commands were checked only with fictional data; none of those three terminals is installed here. Codex 0.169.0
  and Claude Code 2.1.318 now connect as untested versions; their hook payloads were not checked against a real run.
- Stale: `scripts/check-event-contract.py` and `scripts/check-event-bridge.py` still accept only `kind: "otty"` terminals.
- Decision 0025 unverified: Claude's `SubagentStart`/`SubagentStop` and status-line `context_window` totals, Codex's
  `PermissionRequest` reply and Cursor CLI's hook payload fields (`conversation_id`, `generation_id`) follow the reference
  island's packaged code, not a run against the installed agents. `otty-cli pane focus`/`send-text --from-file`/`send-keys key:Enter`
  match Otty 1.6.2's help text but were not run. Apple Terminal jumps need macOS Automation approval.

- Desktop transaction regression checks initially failed with `.unsafePath` and then `.unsafeMetadata`. The guard now checks path components without Foundation rewriting system aliases and permits the macOS-managed provenance marker. The full connect/reconnect/remove regression passes for both desktop agents in disposable files and retains the symlink and unknown metadata restrictions.
- The default Command Line Tools test run (`swift test --scratch-path /private/tmp/bunlet-notch-hooks-build --filter 'ProviderSetupServiceTests|NotchPresentationTests'`)
  failed with `no such module 'Testing'`. Select Xcode using the explicit `DEVELOPER_DIR` command above.

- Runtime-qualified provider registry remains empty. Documented setup accepts any well-formed version above the decision 0026 floors without bypassing normal trust/policy; real install/reinstall/recovery/removal and stream-preservation acceptance remain unverified.
- Claude actions provide explicit permission decisions, structured answers and a ≤60-second existing Stop-hook feedback window. Codex actions and arbitrary-time follow-ups remain unsupported. Hosted compilation/tests do not establish provider action acceptance.
- Terminal-independent monitoring is implemented. Exact-pane navigation uses hook-reported terminal identity (decisions 0025, 0026), with user-linked iTerm2 and the chosen app as fallbacks. Native Automation/focus/display/Space/sleep/drag/import acceptance remains deferred.
- Earlier hosted runs recorded compiler failures and process/socket timeouts. Final PR-head CI passed, but intermittent cases are not proven eliminated. Preserve the failures and fixes in `docs/goals/full-mvp-implementation-log.md`; no new reliability claim is made.
- Feature task lists retain original verification-bearing checkboxes. Missing retrospective specs and future roadmap entries do not mean the merged code is absent; the handoff distinguishes source coverage from release acceptance. No dates/owners are assigned.
- Telemetry/statistics, launch-at-login/language preferences, automatic attention/haptics, SSH/cloud and additional agents remain outside the delivered nine-area MVP.
- CI foundation F8b deliberate hosted drills and separate historical CI-branch integration are not completed by the passing MVP PR. Do not resume them automatically.
- Telemetry planning conflict: `origin/docs/local-telemetry` records a history-first decision superseding collector-first D2, but this checkout retains the old order. Its D3 identifier collides with this branch's view-model D3. Reconcile decisions and links without dropping later statistics scope or marking withdrawn tasks complete.
- FM7 is deferred by the user. The last native command was `python3 scripts/check-feature-management.py --app '/private/tmp/notch-pet-features/notch-pet-dev/Notch Pet.app' --artifacts /private/tmp/np-features-native-final`: all eight startup sets and fresh setup passed; recovery/interaction failed `explicit Settings focus`, and reopen failed `launch choices` after interaction stopped. Its process exited 1 and is stopped. Full pending-removal, keyboard and relaunch acceptance remains unproven. Do not restart it automatically.
- Capture reproduction command: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/check-standalone-pet.py --app "/private/var/folders/t3/6n_zw1rn5nn6vv7ccx9r6s240000gn/T/notch-pet-dev/Notch Pet.app" --artifacts /private/tmp/notch-pet-completion/evidence/standalone` failed with `could not create image from window` / screencapture exit 1. The native preflight returned screenCaptureAuthorized=false; the user explicitly prohibited further captures and later all further testing. Do not request that permission or retry the failing capture.
- Stale: `scripts/check-event-contract.py` permits a previously conflicting turn ID to restore working state; SessionStore enforces the accepted unseen-turn rule.
- Unverified on screen: the redesigned island, Settings and pet panel were built and unit-tested only. SwiftUI hover in the nonactivating panels and the pill drag-out need a real-display check.
- Stale: `docs/specs/settings/feature-management.md` (FM1–FM7) and `docs/specs/pets/*.md` describe installable features and pet-only use; decision 0020 removed both.
- Unverified: launch at login (`SMAppService`) may be refused for the dev build in TMPDIR; Settings shows the reason if so.
