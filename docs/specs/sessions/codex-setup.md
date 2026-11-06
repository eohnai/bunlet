# Connect Codex through owned lifecycle hooks

Status: implementation merged in PR #16; feature acceptance remains deferred.


Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

## Current source implementation, 2026-11-06

The full MVP goal authorizes documented integration with tests/builds/runtime qualification left
unverified. [Provider setup](../../contracts/provider-setup.md) supersedes the earlier qualification
gate only; trust, permission policy and the guarded ownership/recovery design are preserved.
`ProviderHookPolicy` binds Codex 0.164.0, with a bounded initialized app-server policy inspector.
Known disabled/managed-only policy blocks installation; unknown policy is labelled unverified.
`ProviderSetupService`/`ProviderHookTransaction` and the generic setup controller/view now implement
Connect, Check, Repair, Remove, Pause/Resume and Disconnect. The runtime-qualified registry stays empty.
Reinstall is idempotent; edited/missing owned entries conflict. A moved helper needs Remove then Connect.
Both providers now share these mechanics; see [Claude setup](claude-setup.md) and
[monitoring controls](monitoring-controls.md). Earlier source-state descriptions below are historical;
the original verification-bearing task checkboxes are unchanged because no acceptance checks ran.

Needs: integration-health, notch/session-island

## Goal

Let users connect Codex, check integration health, and remove app-owned hooks from the menu.
A real Codex session must reach the visible notch through the bundled helper.
This starts the approved Sessions → Notch → Usage path. See the [sessions area](area.md) for shared context.

The user confirmed this scope and menu-first controls on 2026-10-30.
The user approved the eight-task list and accepted I3b1's design choices on 2026-10-30.
The [accepted I3b1 review](../../contracts/codex-hook-setup.md#i3b1-review-2026-10-30) records prerequisite evidence and fictional-case results.
Design acceptance does not close prerequisites, qualify a release, or resume runtime verification.

### Implementation-only MVP, 2026-11-06

This subsection records the historical initial Codex slice; the full-MVP contract and merged evidence above supersede its old deployment gate.

The user activated `docs/goals/codex-mvp-implementation.md` and explicitly requested implementation without testing.
This authorizes source work despite deferred prerequisite acceptance; it does not complete verification requirements.
That initial slice used `feat/codex-mvp` in the original checkout before the user subsequently authorized milestone commits, push and PR #16 merge. It created no additional worktree.

The existing `633b4d0` module/identity/architecture changes were selectively reused around the checkout's FM7 drafts.
Existing upstream test-file relocations and caller/import/type changes were retained solely for refactor coherence;
no new test cases were added, no assertions weakened to manufacture completion, and no tests were run.
The `2925880` scanner/planner was adapted to `Integration`, typed identities and the accepted contract.

Production source now includes:

- Lossless hook JSON scanning, seven-group planning, unchanged reinstall, exact ownership validation and targeted removal.
- Guarded install/remove with private ownership records, descriptor-relative safe-path/metadata checks, candidate synchronization,
  journal publication, fresh-state checks, replacement, ownership finalization and known-state recovery.
- Cancellable Connect/Check/Remove action state and native menu/Agents settings controls. Check is read-only and never grants trust.
- Explicit successful-Connect monitoring activation and the existing helper/inbox/shared-store/notch/Codex quota route.
  Missing Notch offers Features recovery; Pet remains independent.

At this initial slice, the exact-release registry was empty and Connect remained gated. The later full MVP permits explicitly unverified documented setup under the contract above; runtime qualification remains empty. The full valid-input transaction path is implemented behind that gate; release qualification
is still required before a normal user can connect automatically. Removal uses content ownership and needs no working CLI.

Source implementation is not compiler correctness, a real installed session, successful provider timeout enforcement,
or native acceptance. I3b2/I3b3/I3c1/I3c2/I5a/I6a and the older R2/R3/R4 checkboxes remain unchecked here where
their acceptance requires checks not run on the changed source. I6b and prerequisite/feature acceptance remain open.
See the goal's six-item source audit for implementation evidence and the log for its NOT RUN verification status.

## Done when

- Pet-only startup needs no agent setup. Connect is explicit and optional; Check and Remove hooks are available for Codex.
- Connect installs only the seven supported lifecycle hooks using the bundled helper and an accepted version/configuration shape.
  Unsupported versions, disabled hooks, missing helpers, unsafe paths, and invalid configuration produce bounded, useful messages without configuration changes.
- Repeating Connect with unchanged owned entries leaves hook bytes unchanged and creates no duplicate entries.
- Setup and removal preserve unrelated handlers, their order, unrelated JSON values, and later user edits.
  Detectable edited, missing, copied, or ambiguous managed entries produce a conflict without destructive cleanup.
  These guarantees follow the accepted independent-writer and identical-replacement limits below.
- The accepted ownership file records only app-created data. Interrupted updates recover under a reviewed protocol or stop with recovery instructions.
  The approved design states its concurrent-writer guarantees and limitations before implementation.
- Normal Codex hook trust review remains intact. Installation, trust, receiver availability, and actual delivery remain distinct outcomes.
  Check is read-only and does not submit agent work. An empty session list does not imply broken setup.
- After explicit setup, the existing optional services receive real Codex observations and show the correct session in the notch.
  No manual mode switch is required for each session. Missing terminal metadata does not block observation.
- Disposable real-agent acceptance proves Connect, repeated Connect, Check, visible session delivery, and targeted removal.
  Unrelated configuration remains intact after cleanup. An isolated conflict case leaves edited configuration untouched.

## Out of scope

- Claude setup, its status line, and Claude acceptance.
- Pause/resume/disconnect monitoring semantics, including service-wide controls and notice-retention policy.
- The Settings window and its later Agents page. This feature owns reusable Codex setup actions.
- Usage changes, allowance acceptance, approvals, answers, follow-up replies, pet reactions, and terminal navigation.
- Completing the deferred R6–R7 interactive matrix, N8 terminal matrix, or final R8 first-use workflow.
- Automatic hook installation at startup, trust bypasses, and edits to `config.toml` to enable hooks.

## Constraints

- Keep SwiftUI/AppKit, shared session state, the version-1 event contract, and the silent helper's existing deadline.
- Follow the preservation requirements in the [setup contract](../../contracts/codex-hook-setup.md).
  I3b1 accepts the version gate, timeout, ownership schema, journal recovery, and writer/identity limits.
  Concrete implementation plans and runtime qualification remain separate gates.
- Keep the pure planner separate from file operations. Bound hook input, candidate output, ownership records, and recovery data to 262144 bytes each.
  Reject duplicate JSON keys and preserve unrelated numeric values without floating-point conversion.
- Use the effective bounded absolute `CODEX_HOME` path. Reject invalid overrides without falling back to another configuration directory.
  Read no credentials, authentication files, or transcripts. Diagnostics must omit raw configuration and command contents.
- Validate helper quoting, supported timeout syntax, path safety, permissions, and concurrent updates before writing configuration.
  A process-shared app lock does not coordinate independent editors. Atomic replacement alone does not resolve that race.
- Keep preferences separate from evidence. A saved opt-in or successful installation does not prove hook delivery or a current session.
  Removing hooks must not resolve requests or claim session completion. Broader runtime controls remain separately owned.
- Keep runtime files, isolated configuration, ownership records, and captures outside the repository.
  Do not change installed Codex, Claude Code, or Otty configuration during planning or disposable verification.
- Keep tests, builds, probes, app launches, helper injections, captures, and test-only instrumentation paused until explicitly requested.
  Prerequisite evidence and closure must be reviewed before dependent implementation.

## Verify

- Seam: menu actions → setup service → isolated Codex hooks → bundled helper → production receiver → visible notch.
- Documentation: `git diff --check` exits 0. The progress board resolves both `Needs:` entries and lists the eight approved tasks.
- Swift checks, after renewed authorization: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`.
  Passing means exit 0 with no failing tests. Fixture checks cover preservation, ownership conflicts, bounds, stale plans, and each durable interruption boundary.
- Build, after renewed authorization: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only`.
  Passing means exit 0 and a packaged app plus helper outside the repository.
- Real app, after renewed authorization: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh` is the existing launch command.
  I6b must first freeze the isolated app/CLI launch recipe, explicit configuration and ownership paths, preference suite, and cleanup commands.
  The ordinary launch command alone does not isolate setup and must not be used to write the normal configuration.
- In disposable configuration, use the menu to Connect, repeat Connect, and Check. Complete normal Codex trust review.
  Start a real Codex session and verify its identity and observed state in the notch. A silent helper exit alone is insufficient.
  Remove hooks after adding unrelated data, then verify that only unchanged owned entries were removed.
  Repeat with a managed-entry edit and verify a conflict with no configuration changes.
- Preserve original Otty acceptance from I6 and the terminal-independent requirement. Record the exact tested terminal and version.
  These checks do not complete the broader R6–R7 or N8 matrix. Do not request screenshots or retry the prohibited capture path.

These are future verification requirements. No runtime verification ran while writing this specification.

## Decisions

- **Use menu controls first.** The user accepted this on 2026-10-30 to avoid waiting for the planned Settings window.
  Waiting for Settings was considered and deferred. The later Settings feature can reuse these actions.
- **Use a separate ownership file.** Accepted on 2026-10-28. Entry markers alone were rejected because they lack verified compatibility and edit detection.
  See the [existing decision and proposed recovery contract](../../contracts/codex-hook-setup.md#ownership-alternatives-requiring-a-decision).
- [0004: Receive lifecycle hooks](../../decisions/0004-receive-agent-hook-events.md).
- [0005: Use the local observer helper](../../decisions/0005-use-a-local-unix-socket.md).
- [0011: Preserve feature ownership and historical evidence](../../decisions/0011-organize-records-by-feature.md).
- [0012: Support terminal-independent observation](../../decisions/0012-support-terminal-independent-operation.md).
- [0013: Keep agent setup optional](../../decisions/0013-separate-standalone-pet-scope.md).
- **Use schema version 1 and an install/remove journal, accepted 2026-10-30.** Store only exact app-created groups and bounded identity/digest metadata.
  Ownership-first and unjournaled writes were rejected because they can leave false or missing ownership. Recover only exact known states.
- **Use app-lock/recheck/replace with an explicit independent-writer limit, accepted 2026-10-30.** The user selected option A after the lost-edit example.
  This retains the Connect path. Deferring automatic writes, option B, was not selected. Preservation does not cover arbitrary concurrent editors.
- **Qualify exact Codex releases, accepted 2026-10-30.** Start with 0.164.0 as a candidate. No installer release is qualified yet.
  Reject a minimum-version range because version-specific evidence is incomplete. Missing effective enablement/policy evidence prevents installation.
- **Use a three-second synchronous hook timeout, accepted 2026-10-30.** Allow process-launch overhead beyond the unchanged 250 ms helper deadline.
  The helper deadline alone does not bound the whole invocation. Agent enforcement still requires qualification for the chosen release.
- **Accept content-based ownership limits, accepted 2026-10-30.** Exact descriptions detect visible edits and duplicates, but cannot detect identical replacement history.
  Marker-only identity was rejected because copying and deleting the original defeats it too. See the [review and alternatives](../../contracts/codex-hook-setup.md#i3b1-review-2026-10-30).
- [D4: Target macOS 14 so stores and controllers can use `@Observable`](../../DECISIONS.md#d4-target-macos-14-so-stores-and-controllers-can-use-observable), accepted 2026-10-31 for R7 and R8.
- [D5: Observe stores from controllers with `withObservationTracking`](../../DECISIONS.md#d5-observe-stores-from-controllers-with-withobservationtracking), accepted 2026-10-31 for R8.

## My calls

- Use `feat/sessions-codex-setup` for eventual implementation. This planning session creates no branch.
- Reuse `IntegrationHealthController`, `AgentServiceOwner`, and `AgentServices`; concrete interfaces receive task-level review.
  The current menu exposes Show Pet, Pet Settings, and Quit. The health controller is private and has no menu action.
- Label removal as Remove hooks so it does not define the separately planned Disconnect behavior.
  Exact wording and health presentation receive interface review in I6a.
- Use session-sized tasks. Each task must be finished and verified in one session.
  Review exact files, interfaces, and checks per task. Split any oversized task with user approval before coding.
  The user removed the earlier three-file, three-function, and five-test limits on 2026-10-31. They duplicated this size check.
- R1–R6 come from the [2026-10-30 review](../../reports/2026-10-30-session-state-and-architecture-review.md), which the user accepted in full on 2026-10-30.
  R1–R3 come before I3b2, because the scanner and planner need the new `Integration` module and typed hook names. R4–R6 can run in any order.
- The user added R7 and R8 on 2026-10-31, after the R1 review of two external Swift skills. Both skills assume `@Observable`, which needs macOS 14.
  No record explains the original macOS 13 target. R8 follows R7. The user authorized builds and tests for R7 and R8.
- Preserve the source checklist until shared Codex/Claude checks have complete destinations. This spec's tasks refine that work; they are not extra source requirements.
  Do not add source and refinement counts as independent work estimates.

## Tasks

- [x] I3b1: Review prerequisite evidence and settle the Codex version/enablement gate, timeout, ownership schema, recovery states, and concurrent-writer guarantees using the contract's fictional cases; record accepted choices before coding.
- [x] R1: Write `docs/SWIFT-PRACTICES.md` from the conventions and accepted findings in the 2026-10-30 review, and link it from `AGENTS.md`.
- [x] R7: Raise the deployment target to macOS 14 in `Package.swift`, `Info.plist`, `README.md`, and `ARCHITECTURE.md`; replace the two deprecated `onChange(of:perform:)` calls; record the decision; build passes with no new warnings.
- [x] R8: Move the five `ObservableObject` classes and their views to `@Observable`; no behavior change, full suite passes.
- [ ] R2: Split `SessionState` into `SessionState`, `Usage`, and `Integration` targets, and move the executable and configuration-directory locator out of the app target; no behavior change, full suite passes.
- [ ] R3: Add typed `Agent` and `HookEvent` enums at the bridge boundary; remove the duplicated hook-name sets, the `default: .sessionEnded` branch, and the force unwraps they make unnecessary; wire format unchanged.
- [ ] R4: Update `ARCHITECTURE.md` to describe stores, pure presentation functions, AppKit controllers, and D3's view-model rule.
- [ ] R5: Collect `ServiceStartLedger`, pet evidence writing, and the preferences-suite override into one verification type with one entry point.
- [ ] R6: Review the 128-session contract limit and its silent refusal; record a decision before any store or contract change.
- [ ] I3b2: Add bounded lossless hook-JSON scanning with duplicate-key, malformed-input, numeric-value, and size-limit fixture checks.
- [ ] I3b3: Add the pure setup planner with seven separately owned groups, safe helper invocation, unchanged reinstall, and ownership/conflict fixture checks.
- [ ] I3c1: Add guarded configuration and ownership writes with the approved durable-update order, path/permission checks, and stale-state fault checks; keep the service unavailable to menu callers until recovery passes.
- [ ] I3c2: Add interrupted-update recovery covering every approved durable boundary, uncertain state, and retry without duplicate adoption or later-edit overwrite.
- [ ] I5a: Add Codex-only targeted removal with exact ownership checks, preserved unrelated edits, and unchanged output on malformed, missing, or conflicting ownership.
- [ ] I6a: Add menu Connect, Check, and Remove hooks actions with bounded health/recovery messages and explicit optional-service activation; verify action routing without installed configuration changes.
- [ ] I6b: Freeze the disposable verification recipe and verify real Codex setup, repeat setup, trust review, visible-notch delivery, removal, and conflict cleanup; run the approved suite/build and record evidence.

## Source task coverage and historical evidence

R2/R3/R4 and the installer/control source paths are merged; hosted CI compiled and exercised the
existing suite. R5 verification-instrumentation consolidation and R6's separate capacity review are
not completed by the nine-area MVP. Planner/transaction fault coverage and I6b real-provider
acceptance still need their specified evidence. Do not treat the open checklist as an instruction
to create another module split, planner or installer.

The [source specification](../notch-companion.md#i-see-sessions-and-manage-agent-setup) remains unchanged.
Its original task IDs, wording, checkboxes, and shared acceptance obligations remain authoritative during migration.

| Source task | Existing state | Coverage here |
|---|---|---|
| I3a | Checked, documentation only | Existing setup contract and fictional review cases; no new implementation or verification claim. |
| I3b | Open | I3b1–I3b3 settle design and implement the pure planner. |
| I3c | Open | I3c1–I3c2 implement guarded installation and recovery. |
| I5 | Open, shared | I5a covers Codex only. Claude removal remains with Claude setup. |
| I6 | Open, shared | I6a–I6b cover Codex controls and live acceptance. Claude and original Otty obligations remain preserved. |

The contract records I3a's documentation review and the separate ownership-file choice.
No Codex installer, planner, removal service, or connection menu is present in the inspected source.
The app already has an opt-in service owner and receiver/delivery health wiring; their existing acceptance remains open in the prerequisite specs.
Earlier helper-to-menu screenshots established partial fictional delivery only. See [session-island historical evidence](../notch/session-island.md#historical-evidence).
They do not establish real-provider setup or complete I6b.

## I3b1 review evidence, 2026-10-30

The review compared prerequisite specs, recorded suite/app evidence, current service ownership, and fetched official documentation.
It maps all eight fictional cases and the install/remove durable boundaries in the [contract](../../contracts/codex-hook-setup.md#i3b1-review-2026-10-30).
Current health evidence does not establish effective hook enablement. No qualified installer version can be claimed from this review.
Integration-health, session-state closure, and actual-notch acceptance remain separate gates before dependent implementation.
The health menu-environment description is stale. I6a still owns exposing the private health controller through actions.

The user accepted all I3b1 choices on 2026-10-30. Only documentation checks are authorized for this task.
`git diff --check` exited 0. The progress script resolved both dependency names and retained all eight tasks.
I3b1 is complete on design acceptance and documentation evidence only. No installer release was qualified.
Keep I3b2–I6b open. This review does not resume any older goal or runtime acceptance.
