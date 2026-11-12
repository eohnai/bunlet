# Status

## Now

Flux UI match (2026-11-12, on `feat/island-ui`): decisions [0017](decisions/0017-match-flux-island-ui.md),
[0018](decisions/0018-restore-usage-hover-details.md) and [0019](decisions/0019-show-prompt-and-reply-previews.md) are accepted;
[the Flux UI reference](notes/flux-ui-reference.md) records the target. Island shape/pill/hover/notification-open, Flux session rows,
usage popup, request/completion cards, Settings sidebar and agent list, pet bubble and pet session panel are implemented.
Prompt/reply previews are forwarded on UserPromptSubmit/Stop only. Dragging the closed pill down 50 points pulls the pet out; it follows the pointer until release.
`swift test` passes 209 tests; `scripts/run.sh --build-only` packages.
Not verified: no app launch or visual comparison was made (the user does the visual check); hover inside the nonactivating
panels, the drag-out gesture on a real display, and live hook payloads in installed provider versions remain open.

The full local MVP is merged through PR #16. Bunlet is now the accepted name under decision 0016.
The visible app and bundle rename is complete, uncommitted on `feat/settings-product-name`, based on main `d0d4639`.
Build, package and focused native rename results are recorded in `docs/specs/settings/product-name.md`. Internal identities remain stable.
The isolated validation app is stopped. Broader native/provider acceptance and FM7 remain deferred.

## Next

1. Review and commit the Bunlet rename on `feat/settings-product-name`, then merge it into main when ready.
2. Select one future task from the merged feature handoffs. Get approval before resuming broader native/provider acceptance.
3. Keep separate telemetry/CI reconciliation and FM7 drafts outside the rename change.

## Blockers

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
