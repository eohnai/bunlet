# Codex MVP implementation

Status: implementation complete; tests, build, qualification and native acceptance not run.

## Goal block

```text
GOAL: Finish the native Codex MVP production implementation: optional Connect/Check/Remove hooks, session delivery to the notch and provider-reported limits. Completion means source implementation complete, not tested or live-qualified.

ENTRY: Read AGENTS.md, docs/{STATUS,SWIFT-PRACTICES}.md, the Codex setup spec/contract, notch/usage specs and this goal/log. Use the current checkout on feat/codex-mvp, based on c760308; no worktrees. Preserve existing drafts and paused goals. Keep all work on feat/codex-mvp; create no other branches. Activation approves these six items and defers prerequisite acceptance without bypassing production support/trust gates.

DONE WHEN all six hold, supported by line-numbered production-source excerpts printed in the conversation:
1. Selectively port 633b4d0's Usage/Integration, typed Agent/HookEvent and architecture corrections, plus useful scanner/planner code from 2925880. Preserve existing drafts and newer decisions; do not overwrite whole dirty files.
2. Complete bounded seven-hook planning, helper quoting, unchanged reinstall and exact ownership matching; preserve unrelated bytes/numbers/order and reject malformed, duplicate-key, unsupported and conflicting inputs.
3. Complete guarded install/remove and journal recovery: accepted lock/recheck/replace contract, 262144-byte bounds, safe paths/permissions and exact recovery states. No destructive adoption, rollback over edits or invented external-writer guarantees.
4. Wire Connect, read-only Check and Remove hooks to cancellable services with progress/error/recovery feedback. Keep exact-version/effective-enablement gates, timeout:3 and trust review. Separate configured/helper/receiver/delivery evidence. No placeholder handlers or fabricated qualification; report unqualified releases.
5. Complete the route: explicit optional Agents setup, helper/receiver/inbox/shared SessionStore, notch cards and app-owned Codex reads/UsageStore/strip. Offer explicit install/open recovery for absent Notch. Preserve pet independence, missing-terminal support, cancellation and nonactivating alerts. No paid turns or mock-only substitutes.
6. Record six-item implementation audit with file:line evidence and zero missing items. Update ownership/setup/MVP docs; preserve history. Record tests, live qualification and native acceptance as not run. Do not mark feature/spec accepted.

EVERY TURN: run `git status --short --branch`, `git diff --stat`, `git diff --check` (exit 0 at completion), and `rg -n 'HookSetup|Codex|Connect|Remove hooks|journal|ownership|account/rateLimits/read' Sources`. Inspect full paths using `nl -ba`; names alone are not proof. Print branch/base, criteria 1-6 implemented/incomplete with evidence; tests/build/runtime NOT RUN. Append a numbered timestamped row to docs/goals/codex-mvp-implementation-log.md; continue numbering.

CONSTRAINTS: Change Package.swift, scoped Sources, README, relevant docs and this goal/log. Existing Tests may receive only upstream refactor moves/import/type updates; no new cases or weakened assertions. Do not edit tests, check scripts or these criteria to manufacture completion. No tests, builds, probes, app/helper launches, captures, installed-config access/changes, credentials/transcripts, new dependencies, commits, pushes or PRs. No Claude expansion, actions/replies, terminal adapters, pet features, statistics, telemetry, CI overhaul or unrelated refactoring. Runtime data stays outside Git.

STOP AND REPORT: after 30 execution turns; the same failure blocks three consecutive turns with no new approach; or progress requires missing access or a new product/security decision. Do not weaken support gates to finish.

ON FINISH/STOP: set log status/result to implementation complete, stopped or blocked; run checkpoint without tests; summarize source evidence and unverified work, and provide scoped git add/commit commands for user review without executing them.
```

## Scope and authorization

On 2026-11-06, after the repository/branch/specification comparison, the user said:
"no need to test, can just finish the MVP. run $make-goal".
The MVP is the previously identified Codex setup → visible session → actual provider limits path,
not the entire Flux Island parity backlog. This goal prepares that first implementation delivery.
The user subsequently requested different branches where necessary, then clarified:
"wait don't need worktree, can just do in the current one". That correction replaces the original
separate-worktree plan. The user then required all work on codex-mvp and activated this goal. Use only feat/codex-mvp in the current checkout.

The user's no-testing instruction supersedes the selected tasks' verification-first and prerequisite
acceptance gates for implementation execution. It does not establish compiler correctness, qualify a
Codex release, complete a real session, or close native/feature acceptance. No new test cases,
check harnesses or verification-only production instrumentation are requested.

The goal uses a frozen six-item source-review checklist. Its expected final result is
**implementation complete; tests, build and live acceptance not run**. A blocked/incomplete item
cannot be counted as implemented merely because it has documentation or a disabled UI control.
Read-only source inspection and Git bookkeeping are permitted; neither substitutes for runtime proof.

## Execution base and branch reuse

- Current source checkout: `feat/codex-mvp`, branched from `c760308` without changing source bytes.
  Deferred FM7 changes and unrelated editor/CI/document drafts are still present. Do not stash,
  reset, stage, merge over, or remove them. `feat/modular-features` remains at its original commit.
- Work in `/Users/bytedance/projects/notch-pet`. No new worktrees. The temporary clean MVP worktree
  created during branch preparation was removed immediately after the user's correction.
- `origin/feat/sessions-codex-setup` at `633b4d0` contains `6d7b87e` (architecture correction),
  `4c27cae` (module split and locator), and `633b4d0` (typed agent/hook identities). Reuse their
  selected changes, adapting them around this checkout's drafts rather than replacing dirty files.
- `2925880` on `origin/feat/agent-session-workflow` contains scanner/planner candidates. Port selected
  production code into the accepted module boundaries; do not wholesale merge its older specs,
  string identities, obsolete slice limits or `try!` usage.
- Keep every MVP change on `feat/codex-mvp` in the current checkout. The user explicitly cancelled
  the optional topic-branch plan. Create no other branches or worktrees. No staging or commits.
- Keep remote history inspection read-only. No commit, push or PR is authorized.

## Existing task ownership

The goal refines existing obligations rather than creating a second feature backlog:

- Criteria 1–2: reuse R2a/R2b/R3/R4 from the newer branch, then Codex I3b2/I3b3.
- Criterion 3: Codex I3c1/I3c2 and I5a.
- Criterion 4: Codex I6a, integration-health evidence presentation and feature lifecycle.
- Criterion 5: existing observation-bridge/session-state/session-island and Codex allowance integration.
  Reuse the implemented cards, observed-turn timer, active-provider filtering and percent-left strip.
- Criterion 6: implementation handoff and current documentation only.

I6b real-agent acceptance, full session-island/integration-health acceptance, FM7, U6 and physical
desktop/resource checks remain deferred. Do not tick tasks whose acceptance includes checks not run.
Record implementation status beside those tasks without changing their historical evidence.

## Support and safety boundaries

The accepted setup contract currently has **no qualified Codex installer release**. `0.164.0` is a
candidate, not an established supported release; older branch metadata for other versions is not
qualification either. Implement the concrete support/effective-enablement policy seam and full
production path, retain conservative runtime gating, and state this deployment limitation prominently.
Skipping tests does not authorize making up a qualified version, returning fake policy evidence,
claiming a hook invocation succeeded, bypassing trust, or enabling unknown configuration shapes.

Source completion must include the entire valid-input install/remove/recovery path behind those gates.
An always-unavailable placeholder service is incomplete. If a product change is needed to enable
untested versions, identify that precise decision rather than silently introducing it.

The app's implemented Check action may perform bounded supported inspection when the person later
invokes it. Preparing or executing this implementation goal must not itself invoke installed CLIs,
read user agent configuration, modify hooks, launch providers or request new capture permissions.

Connect remains explicit. Pet requires neither Notch nor Agents. Starting Agents must not silently
install Notch; offer an explicit route if the person wants the session surface. Removing owned hooks
cannot resolve retained requests or claim a session ended. Quota reads remain read-only and cannot
start a conversation. Do not add terminal keystrokes, transcript parsing or lifecycle heuristics.

## Turn limit and completion reporting

Default limit: 30 execution turns, selected for this medium-sized source implementation goal.
Preparation is not execution turn 1. Stop earlier for the block conditions in the paste block.

All work stays on `feat/codex-mvp`, per the latest user instruction.

Each execution turn records six source statuses, relevant file/line evidence, current branch/base,
what changed and what remains. The frozen requirements are not editable to suit partial results.
At completion, report that no compile/test/live behavior evidence was obtained. If blocked or limited,
list the unimplemented criteria and leave them incomplete. Never close a previous paused goal.

## Preparation record

Read the invoked make-goal skill, anatomy/measurability/examples, log template, current STATUS,
relevant Codex/health/island specs and setup contract, and the branch records already reviewed in
this conversation. Created this goal/log and a scoped STATUS handoff. Prepared `feat/codex-mvp`
at the original checkout's `c760308`; preserved all existing edits and removed the unused clean
temporary worktree after the user's correction. No production source, test, build, runtime/configuration,
branch integration or goal activation occurred during preparation.

## Six-item source audit, 2026-11-06

All six criteria are implemented at source level. This audit used source reads and Git bookkeeping only;
it is not compilation, test execution, a real configured session or native acceptance. No criterion was
removed to obtain completion. No installer release was added to the empty qualification registry.

1. **Implemented — reuse and boundaries.** Package.swift:15 separates Integration/Usage from SessionState;
   EventBridge/Agent.swift:1 and HookEvent.swift:1 supply typed identities. AgentPathLocator.swift:4 retains
   the accepted distinct lookup policies. The 633b4d0 refactor was merged around existing edits, including
   EventBridgeClient.swift:30's endpoint argument and existing feature-check tags/instrumentation.
   Existing upstream test-file moves/import/type updates are retained; the added upstream test cases were not copied.
2. **Implemented — pure planning and removal.** HookConfigurationJSON.swift:13 retains source ranges and
   rejects duplicate keys. HookEnvelopeV1.swift's capture-only number grammar preserves arbitrary JSON numeric
   lexemes while the observer retains its finite-number boundary. HookGroupEdits.swift:99 plans seven separate
   hooks; :53 quotes the helper with timeout 3; :60 validates exact app-only ownership; :12 removes uniquely
   matching groups using source slices. :258 verifies all groups before removal, and :299 rejects unsupported
   handler shapes and helper lookalikes. Unchanged reinstall returns unchanged without writing or journaling.
3. **Implemented — guarded files and recovery.** CodexHookFiles.swift:114 bounds reads and validates identity,
   owner, links, modes and supported metadata. :161 prepares and synchronizes candidates; :220 rechecks before
   replacement; :263 serializes writers. CodexHookTransaction.swift:47 plans fresh under the lock; :124 stores
   digests and app-only ownership in a bounded journal; :142 publishes intent before replacing hooks.
   :209 handles exact previous/candidate states; :234 verifies operation-specific entries, synchronizes hooks
   and ownership, and clears intent last. Unknown states preserve evidence and require reconciliation.
   Cleanup verifies temporary-file identity; unproven crash orphans remain inert. No full configuration backup,
   ownership adoption or guarantee against the accepted independent-editor race was introduced.
4. **Implemented — actual controls and honest gates.** CodexSetupService.swift:39 performs explicit read-only
   Check, :60 dispatches Connect/Remove to the production transaction worker, and :81 enforces registered exact
   releases plus effective policy. :32 intentionally registers zero qualified releases. Removal skips CLI qualification.
   CodexSetupController.swift:33 owns progress, results and errors; :99 cancels observation without racing a second
   transaction. :107 skips executable lookup for removal. CodexSetupView.swift:13 provides native confirmation,
   controls and separate evidence; NotchPetApp.swift:246 exposes menu routes. PetAppController.swift:92 creates
   the controller only for installed Agents and cancels it on removal. Check opens its visible result page.
5. **Implemented — shared production route.** PetAppController.swift:19 owns shared stores; :92 enables
   monitoring only after successful explicit Connect. NotchPetHook/main.swift and EventBridgeClient.swift:30
   retain silent bounded observations. AgentServices in NotchPetApp.swift:151 delivers validated inbox batches
   through the current generation to SessionStore, with retained unknown/request semantics. NotchSessionView
   consumes shared snapshots. AgentUsageController.swift:23 observes active Codex sessions and :61 reads
   CodexUsageConnection into the shared UsageStore. CodexUsageProtocol.swift:40 permits initialization plus
   account/rateLimits/read, never turns. NotchAllowanceStrip.swift:13 renders provider snapshots. The setup
   view offers Features for absent Notch; no surface or terminal is silently made a prerequisite of Pet.
6. **Implemented — honest handoff.** README's MVP section, ARCHITECTURE's setup/data-flow sections, the Codex
   and health spec updates, usage ownership records, this audit, execution log and STATUS describe the source
   result and deployment limitation. Original feature checkboxes and historical test evidence remain distinct.
   Tests/build/runtime/qualification are NOT RUN, no feature is marked accepted, and no commit/push/PR occurred.

The automatic Connect gate is a deliberate deployment limitation, not a completed qualification result.
The complete valid-input implementation exists behind it; enabling a release still requires the separately
authorized version/policy/timeout/helper/trust qualification. This source-only goal does not promise a usable
automatic installer for today's unqualified versions or complete the broader Flux Island port.
