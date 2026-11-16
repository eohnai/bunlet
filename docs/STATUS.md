# Status

## Now

`feat/reference-gaps-settings` closes the Claude Code and Codex settings gaps found by comparing with the reference island, and
reorganizes Settings (decision 0022): always allow, rebindable shortcuts, visibility options, idle-session clean-up,
percent used or left, and a launch sound. Claude Code and Codex now start on and connect at launch without a prompt (decision 0023). Settings is now one file per page. The build and all tests pass
(`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`). Nothing has run on screen.

## Next

1. Review and merge this branch.
2. When native checks are authorized, launch with a Claude Code and Codex install and confirm the hooks are added once and not re-added after Disconnect; run `bash scripts/run.sh` and check each Settings page, hide-in-fullscreen on a fullscreen app,
   and the shortcuts, including Always allow on a Claude permission request that offers it.
3. Check Settings → Agents setup stages and timing, then start a new session to confirm tracking.
4. Decide whether to update the superseded pet and feature-management specs (see Blockers).

## Blockers

- Synthetic full-transaction checks with `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/bunlet-notch-hooks-xcode --filter ProviderSetupServiceTests`
  initially failed with `.unsafePath` for temporary-path aliases and `.unsafeMetadata` for extended file metadata.
  The final regression test isolates post-save inspection and passes. It does not establish transaction acceptance.
  The existing strict path/metadata guards remain unchanged. No installed-provider files were inspected or changed.
- The default Command Line Tools test run (`swift test --scratch-path /private/tmp/bunlet-notch-hooks-build --filter 'ProviderSetupServiceTests|NotchPresentationTests'`)
  failed with `no such module 'Testing'`. Select Xcode using the explicit `DEVELOPER_DIR` command above.

- Runtime-qualified provider registry remains empty. Documented setup supports Codex 0.164.0 and Claude Code 2.1.306 without bypassing normal trust/policy; real install/reinstall/recovery/removal and stream-preservation acceptance remain unverified.
- Claude actions provide explicit permission decisions, structured answers and a ≤60-second existing Stop-hook feedback window. Codex actions and arbitrary-time follow-ups remain unsupported. Hosted compilation/tests do not establish provider action acceptance.
- Terminal-independent monitoring is implemented. Exact-pane navigation currently requires explicit user-linked iTerm2; application/manual return works without a pane adapter. Native Automation/focus/display/Space/sleep/drag/import acceptance remains deferred.
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
